import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:web_socket_channel/io.dart';
import 'client.dart';
import 'constants.dart';
import 'data_classes.dart';
import 'drm.dart';
import 'exceptions.dart';
import 'message_parser.dart';
import 'ssml_composer.dart';
import 'util.dart';

/// Internal state for TTS streaming across multiple SSML requests.
class _CommunicateState {
  String partialText = '';
  double offsetCompensation = 0.0;
  double lastDurationOffset = 0.0;
  bool streamWasCalled = false;
  int chunkAudioBytes = 0;
  int cumulativeAudioBytes = 0;
}

class Communicate {
  final String text;
  final String voice;
  final String rate;
  final String volume;
  final String pitch;
  final String boundary;
  final String proxy;
  final int connectTimeout;
  final int receiveTimeout;
  final TTSConfig ttsConfig;
  final _CommunicateState _state = _CommunicateState();

  Communicate({
    required this.text,
    String? voice,
    String rate = '+0%',
    String volume = '+0%',
    String pitch = '+0Hz',
    String boundary = 'SentenceBoundary',
    this.proxy = '',
    this.connectTimeout = 10,
    this.receiveTimeout = 60,
  })  : voice = voice ?? Constants.defaultVoice,
        rate = rate,
        volume = volume,
        pitch = pitch,
        boundary = boundary,
        ttsConfig = TTSConfig(
          voice: voice ?? Constants.defaultVoice,
          rate: rate,
          volume: volume,
          pitch: pitch,
          boundary: boundary,
        );

  /// Stream audio chunks and metadata from the TTS service.
  ///
  /// Can only be called once per [Communicate] instance.
  ///
  /// Yields [TTSChunk] objects with type "audio", "WordBoundary", or
  /// "SentenceBoundary".
  Stream<TTSChunk> stream() async* {
    if (_state.streamWasCalled) {
      throw StateError('stream can only be called once.');
    }
    _state.streamWasCalled = true;

    // XML-escape the text before splitting, matching Python's escape() call
    final escapedText =
        xmlEscape(EdgeTTSUtil.removeIncompatibleCharacters(text));
    final texts = EdgeTTSUtil.splitTextByByteLength(escapedText, 4096);

    for (final partialText in texts) {
      _state.partialText = partialText;

      bool retried = false;
      while (true) {
        _state.chunkAudioBytes = 0;
        try {
          await for (final message in _stream()) {
            yield message;
          }
          break;
        } catch (e) {
          if (retried) rethrow;

          if (e.toString().contains('403')) {
            retried = true;
            try {
              await _syncClock();
              continue;
            } catch (_) {
              rethrow;
            }
          }
          rethrow;
        }
      }
    }
  }

  Future<void> _syncClock() async {
    final client = EdgeHttpClient.createClient(proxy: proxy);
    try {
      await EdgeHttpClient.syncClock(client);
    } finally {
      client.close();
    }
  }

  void _compensateOffset() {
    _state.cumulativeAudioBytes += _state.chunkAudioBytes;
    _state.offsetCompensation = (_state.cumulativeAudioBytes *
            8 *
            Constants.ticksPerSecond ~/
            Constants.mp3BitrateBps)
        .toDouble();
    _state.chunkAudioBytes = 0;
  }

  Stream<TTSChunk> _stream() async* {
    final connId = EdgeTTSUtil.connectId();
    final secMsGec = DRM.generateSecMsGec();

    final uri = Uri(
      scheme: 'wss',
      host: 'speech.platform.bing.com',
      port: 443,
      path: '/consumer/speech/synthesize/readaloud/edge/v1',
      queryParameters: {
        'TrustedClientToken': Constants.trustedClientToken,
        'ConnectionId': connId,
        'Sec-MS-GEC': secMsGec,
        'Sec-MS-GEC-Version': Constants.secMsGecVersion,
      },
    );
    final headers = DRM.headersWithMuid(Constants.wssHeaders);
    headers.remove('Sec-WebSocket-Version');

    WebSocket socket;
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: connectTimeout);
    if (proxy.isNotEmpty) {
      final formattedProxy = EdgeTTSUtil.formatProxy(proxy);
      client.findProxy = (uri) => formattedProxy;
    }

    try {
      final request = await client.getUrl(uri.replace(scheme: 'https'));
      headers.forEach((name, value) {
        request.headers.set(name, value);
      });

      request.headers.set('Connection', 'Upgrade');
      request.headers.set('Upgrade', 'websocket');
      request.headers.set('Sec-WebSocket-Version', '13');

      // Use cryptographic random for WebSocket handshake key
      final rng = Random.secure();
      final keyBytes = List<int>.generate(16, (_) => rng.nextInt(256));
      request.headers.set('Sec-WebSocket-Key', base64.encode(keyBytes));

      final response = await request.close();
      if (response.statusCode != 101) {
        final body = await response.transform(utf8.decoder).join();
        throw WebSocketException(
            'Handshake failed with status ${response.statusCode}: $body');
      }

      final detachedSocket = await response.detachSocket();
      socket = WebSocket.fromUpgradedSocket(detachedSocket, serverSide: false);
    } catch (e) {
      client.close();
      rethrow;
    }

    final channel = IOWebSocketChannel(socket);

    bool audioWasReceived = false;

    // Send Command Request using SSMLComposer
    channel.sink.add(SSMLComposer.buildCommandConfig(ttsConfig));

    // Send SSML Request using SSMLComposer
    channel.sink.add(
        SSMLComposer.buildSsmlRequest(connId, ttsConfig, _state.partialText));

    // Listen for responses
    await for (final message in channel.stream) {
      if (message is String) {
        final result =
            MessageParser.parseTextMessage(message, _state.offsetCompensation);
        if (result.chunk != null) {
          yield result.chunk!;
          _state.lastDurationOffset =
              result.chunk!.metadata!.offset + result.chunk!.metadata!.duration;
        } else if (result.isTurnEnd) {
          _compensateOffset();
          break;
        }
      } else if (message is List<int>) {
        final audioData = MessageParser.parseBinaryMessage(message);
        if (audioData != null) {
          audioWasReceived = true;
          _state.chunkAudioBytes += audioData.length;
          yield TTSChunk(type: 'audio', audioData: audioData);
        }
      }
    }

    channel.sink.close();

    if (!audioWasReceived) {
      throw NoAudioReceived('No audio received');
    }
  }

  /// Save audio to a file, optionally saving metadata to another file.
  ///
  /// This calls [stream] internally, so it can only be called once.
  Future<void> save(String audioPath, {String? metadataPath}) async {
    final audioFile = File(audioPath).openWrite();
    IOSink? metadataFile;
    if (metadataPath != null) {
      metadataFile = File(metadataPath).openWrite();
    }

    try {
      await for (final chunk in stream()) {
        if (chunk.type == 'audio') {
          audioFile.add(chunk.audioData!);
        } else if (metadataFile != null &&
            (chunk.type == 'WordBoundary' ||
                chunk.type == 'SentenceBoundary')) {
          final meta = chunk.metadata!;
          metadataFile.writeln(jsonEncode({
            'type': meta.type,
            'offset': meta.offset,
            'duration': meta.duration,
            'text': meta.text,
          }));
        }
      }
    } finally {
      await audioFile.close();
      await metadataFile?.close();
    }
  }
}
