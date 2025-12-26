import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart'; // Unused

import 'constants.dart';
import 'data_classes.dart';
import 'drm.dart';
import 'exceptions.dart';
import 'util.dart';

class Communicate {
  final String text;
  final String voice;
  final String rate;
  final String volume;
  final String pitch;
  final String proxy;
  final TTSConfig ttsConfig;

  // State
  Map<String, dynamic> state = {
    "partial_text": "",
    "offset_compensation": 0.0,
    "last_duration_offset": 0.0,
    "stream_was_called": false,
  };

  Communicate({
    required this.text,
    String? voice,
    this.rate = "+0%",
    this.volume = "+0%",
    this.pitch = "+0Hz",
    this.proxy = "",
  })  : voice = voice ?? Constants.defaultVoice,
        ttsConfig = TTSConfig(
          voice: voice ?? Constants.defaultVoice,
          rate: rate,
          volume: volume,
          pitch: pitch,
        );

  Stream<TTSChunk> stream() async* {
    if (state["stream_was_called"]) {
      throw Exception("stream can only be called once.");
    }
    state["stream_was_called"] = true;

    final texts = EdgeTTSUtil.splitTextByByteLength(
        EdgeTTSUtil.removeIncompatibleCharacters(text), 4096);

    for (final partialText in texts) {
      state["partial_text"] = partialText;

      try {
        await for (final message in _stream()) {
          yield message;
        }
      } catch (e) {
        // Handle specific errors or retries if needed
        // Python: if e.status != 403: raise ... DRM.handle...
        // Here we catch generic exceptions from WebSocket or processing
        // If we had a mechanism to check 403 from connect, we'd do it.
        // IOWebSocketChannel might throw WebSocketChannelException.
        // Retrying with clock skew adjustment is tricky here without explicit status code
        // unless the exception contains it.
        // For now, simple rethrow.
        rethrow;
      }
    }
  }

  Stream<TTSChunk> _stream() async* {
    final connectId = EdgeTTSUtil.connectId();
    final secMsGec = DRM.generateSecMsGec();
    final wssUrl =
        "${Constants.wssUrl}&ConnectionId=$connectId&Sec-MS-GEC=$secMsGec&Sec-MS-GEC-Version=${Constants.secMsGecVersion}";

    final headers = DRM.headersWithMuid(Constants.wssHeaders);

    // Connect
    // Note: IOWebSocketChannel.connect supports headers.
    final channel =
        IOWebSocketChannel.connect(Uri.parse(wssUrl), headers: headers);

    bool audioWasReceived = false;

    // final controller = StreamController<TTSChunk>(); // Unused

    // Send Command Request
    final cmd = "X-Timestamp:${EdgeTTSUtil.dateToString()}\r\n"
        "Content-Type:application/json; charset=utf-8\r\n"
        "Path:speech.config\r\n\r\n"
        '{"context":{"synthesis":{"audio":{"metadataoptions":{'
        '"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"'
        '},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}'; // Using defaults

    channel.sink.add(cmd);

    // Send SSML Request
    final ssml = EdgeTTSUtil.mkssml(ttsConfig, state["partial_text"]);
    final ssmlRequest = "X-RequestId:$connectId\r\n"
        "Content-Type:application/ssml+xml\r\n"
        "X-Timestamp:${EdgeTTSUtil.dateToString()}Z\r\n"
        "Path:ssml\r\n\r\n"
        "$ssml";

    channel.sink.add(ssmlRequest);

    // Listen
    await for (final message in channel.stream) {
      if (message is String) {
        // Text message
        // final parameters = _getHeadersAndData(message); // Unused
        /*
            final headers = parameters.keys.fold<Map<String,String>>({}, (map, key) {
               final k = key.trim();
               if(k.isNotEmpty) {
                 final parts = k.split(':');
                 if(parts.length > 1) map[parts[0]] = parts.sublist(1).join(':');
               }
               return map;
            });
            */
        // Unused
        // This parsing above is rough. Let's do it properly based on protocol.
        // Protocol: Headers\r\n\r\nData

        final parts = message.split("\r\n\r\n");
        if (parts.length < 2) continue; // Should not happen

        final headerPart = parts[0];
        final dataPart = parts.sublist(1).join("\r\n\r\n");

        final headersMap = <String, String>{};
        for (final line in headerPart.split("\r\n")) {
          final idx = line.indexOf(":");
          if (idx != -1) {
            headersMap[line.substring(0, idx)] = line.substring(idx + 1);
          }
        }

        final path = headersMap["Path"];

        if (path == "audio.metadata") {
          final metadata = _parseMetadata(dataPart);
          yield TTSChunk(type: metadata.type, metadata: metadata);

          state["last_duration_offset"] = metadata.offset + metadata.duration;
        } else if (path == "turn.end") {
          state["offset_compensation"] = state["last_duration_offset"];
          state["offset_compensation"] += 8750000; // 8.75s padding
          break; // End of this chunk
        }
      } else if (message is List<int>) {
        // Binary message
        if (message.length < 2) {
          throw UnexpectedResponse("Binary message too short");
        }

        final headerLength = (message[0] << 8) | message[1];
        if (message.length < headerLength + 2) {
          throw UnexpectedResponse("Header length > data length");
        }

        final headerBytes = message.sublist(2, 2 + headerLength);
        final dataBytes = message.sublist(2 + headerLength);

        final headerStr = utf8.decode(headerBytes);
        final headersMap = <String, String>{};
        for (final line in headerStr.split("\r\n")) {
          final idx = line.indexOf(":");
          if (idx != -1) {
            headersMap[line.substring(0, idx)] = line.substring(idx + 1);
          }
        }

        if (headersMap["Path"] != "audio") {
          throw UnexpectedResponse("Binary path is not audio");
        }

        if (dataBytes.isEmpty && (headersMap["Content-Type"] == null)) {
          // Should contain Content-Type if audio
          // Python: if content_type is None and len(data) == 0: continue
          continue;
        }

        // Yield audio
        audioWasReceived = true;
        yield TTSChunk(type: "audio", audioData: dataBytes);
      }
    }

    channel.sink.close();

    if (!audioWasReceived) {
      throw NoAudioReceived("No audio received");
    }
  }

  /*
  Map<String, dynamic> _getHeadersAndData(String data) {
      // Not actually used if I handle inline, but useful helper.
      return {};
  }
  */

  Metadata _parseMetadata(String data) {
    final json = jsonDecode(data);
    if (json["Metadata"] is List) {
      for (final meta in json["Metadata"]) {
        final type = meta["Type"];
        if (type == "WordBoundary" || type == "SentenceBoundary") {
          final innerData = meta["Data"];
          return Metadata(
            type: type,
            offset: (innerData["Offset"] as num).toDouble() +
                (state["offset_compensation"] as num).toDouble(),
            duration: (innerData["Duration"] as num).toDouble(),
            text: innerData["text"][
                "Text"], // Needs unescape? json decode usually handles basic escapes
          );
        }
      }
    }
    throw UnexpectedResponse("No boundary metadata found");
  }
}
