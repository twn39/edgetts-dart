import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'constants.dart';
import 'data_classes.dart';
import 'drm.dart';
import 'exceptions.dart';
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
    final client = http.Client();
    try {
      final uri = Uri.parse(Constants.voiceList);
      final headers = DRM.headersWithMuid(Constants.wssHeaders);
      final response = await client.get(uri, headers: headers);
      DRM.handleClientResponseError(response.statusCode, response.headers);
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

    // Send Command Request with boundary parameter from ttsConfig
    final wordBoundary = ttsConfig.boundary == 'WordBoundary';
    final wd = wordBoundary ? 'true' : 'false';
    final sq = wordBoundary ? 'false' : 'true';
    channel.sink.add(
      'X-Timestamp:${EdgeTTSUtil.dateToString()}\r\n'
      'Content-Type:application/json; charset=utf-8\r\n'
      'Path:speech.config\r\n\r\n'
      '{"context":{"synthesis":{"audio":{"metadataoptions":{'
      '"sentenceBoundaryEnabled":"$sq","wordBoundaryEnabled":"$wd"'
      '},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n',
    );

    // Send SSML Request
    final ssml = EdgeTTSUtil.mkssml(ttsConfig, _state.partialText);
    channel.sink.add(
      'X-RequestId:$connId\r\n'
      'Content-Type:application/ssml+xml\r\n'
      'X-Timestamp:${EdgeTTSUtil.dateToString()}Z\r\n'
      'Path:ssml\r\n\r\n'
      '$ssml',
    );

    // Listen for responses
    await for (final message in channel.stream) {
      if (message is String) {
        final separatorIdx = message.indexOf('\r\n\r\n');
        if (separatorIdx < 0) continue;

        final headerPart = message.substring(0, separatorIdx);
        final dataPart = message.substring(separatorIdx + 4);

        final headersMap = _parseHeaders(headerPart);
        final path = headersMap['Path'];

        if (path == 'audio.metadata') {
          final metadata = _parseMetadata(dataPart);
          yield TTSChunk(type: metadata.type, metadata: metadata);
          _state.lastDurationOffset = metadata.offset + metadata.duration;
        } else if (path == 'turn.end') {
          _compensateOffset();
          break;
        } else if (path != 'response' && path != 'turn.start') {
          throw UnknownResponse('Unknown path received: $path');
        }
      } else if (message is List<int>) {
        if (message.length < 2) {
          throw UnexpectedResponse('Binary message too short');
        }

        final headerLength = (message[0] << 8) | message[1];
        if (message.length < headerLength + 2) {
          throw UnexpectedResponse('Header length > data length');
        }

        final headerStr = utf8.decode(message.sublist(2, 2 + headerLength));
        final dataBytes = message.sublist(2 + headerLength);
        final headersMap = _parseHeaders(headerStr);

        if (headersMap['Path'] != 'audio') {
          throw UnexpectedResponse('Binary path is not audio');
        }

        final contentType = headersMap['Content-Type'];
        if (contentType != null && contentType != 'audio/mpeg') {
          throw UnexpectedResponse('Unexpected Content-Type: $contentType');
        }

        // No Content-Type with empty data is normal at stream end
        if (contentType == null) {
          if (dataBytes.isEmpty) continue;
          throw UnexpectedResponse(
              'Binary message with no Content-Type but has data');
        }

        if (dataBytes.isEmpty) {
          throw UnexpectedResponse('Binary message missing audio data');
        }

        audioWasReceived = true;
        _state.chunkAudioBytes += dataBytes.length;
        yield TTSChunk(type: 'audio', audioData: dataBytes);
      }
    }

    channel.sink.close();

    if (!audioWasReceived) {
      throw NoAudioReceived('No audio received');
    }
  }

  /// Parse header string into key-value map.
  static Map<String, String> _parseHeaders(String headerStr) {
    final map = <String, String>{};
    for (final line in headerStr.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx != -1) {
        map[line.substring(0, idx)] = line.substring(idx + 1);
      }
    }
    return map;
  }

  Metadata _parseMetadata(String data) {
    final json = jsonDecode(data);
    if (json['Metadata'] is List) {
      for (final meta in json['Metadata']) {
        final type = meta['Type'];
        if (type == 'WordBoundary' || type == 'SentenceBoundary') {
          final innerData = meta['Data'];
          return Metadata(
            type: type,
            offset: (innerData['Offset'] as num).toDouble() +
                _state.offsetCompensation,
            duration: (innerData['Duration'] as num).toDouble(),
            text: xmlUnescape(innerData['text']['Text']),
          );
        }
        if (type == 'SessionEnd') continue;
        throw UnknownResponse('Unknown metadata type: $type');
      }
    }
    throw UnexpectedResponse('No boundary metadata found');
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
