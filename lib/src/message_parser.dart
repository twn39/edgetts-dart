import 'dart:convert';
import 'data_classes.dart';
import 'exceptions.dart';
import 'util.dart';

/// Parsed result from a WebSocket text message.
class TextMessageResult {
  final String path;
  final TTSChunk? chunk;
  final bool isTurnEnd;

  const TextMessageResult({
    required this.path,
    this.chunk,
    this.isTurnEnd = false,
  });
}

/// Utility class for decoding WebSocket text and binary messages from Bing TTS.
class MessageParser {
  /// Parse raw header string into a key-value Map.
  static Map<String, String> parseHeaders(String headerStr) {
    final map = <String, String>{};
    for (final line in headerStr.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx != -1) {
        map[line.substring(0, idx)] = line.substring(idx + 1);
      }
    }
    return map;
  }

  /// Parse text frame from WebSocket stream.
  static TextMessageResult parseTextMessage(
      String message, double offsetCompensation) {
    final separatorIdx = message.indexOf('\r\n\r\n');
    if (separatorIdx < 0) {
      return const TextMessageResult(path: '');
    }

    final headerPart = message.substring(0, separatorIdx);
    final dataPart = message.substring(separatorIdx + 4);

    final headersMap = parseHeaders(headerPart);
    final path = headersMap['Path'] ?? '';

    if (path == 'audio.metadata') {
      final metadata = parseMetadata(dataPart, offsetCompensation);
      return TextMessageResult(
        path: path,
        chunk: TTSChunk(type: metadata.type, metadata: metadata),
      );
    } else if (path == 'turn.end') {
      return TextMessageResult(path: path, isTurnEnd: true);
    } else if (path == 'response' || path == 'turn.start') {
      return TextMessageResult(path: path);
    } else {
      throw UnknownResponse('Unknown path received: $path');
    }
  }

  /// Parse metadata JSON string into a [Metadata] object.
  static Metadata parseMetadata(String data, double offsetCompensation) {
    final json = jsonDecode(data);
    if (json['Metadata'] is List) {
      for (final meta in json['Metadata']) {
        final type = meta['Type'];
        if (type == 'WordBoundary' || type == 'SentenceBoundary') {
          final innerData = meta['Data'];
          return Metadata(
            type: type,
            offset:
                (innerData['Offset'] as num).toDouble() + offsetCompensation,
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

  /// Parse binary frame from WebSocket stream into audio bytes.
  ///
  /// Returns `null` for stream end binary frames with no Content-Type and empty data.
  static List<int>? parseBinaryMessage(List<int> message) {
    if (message.length < 2) {
      throw UnexpectedResponse('Binary message too short');
    }

    final headerLength = (message[0] << 8) | message[1];
    if (message.length < headerLength + 2) {
      throw UnexpectedResponse('Header length > data length');
    }

    final headerStr = utf8.decode(message.sublist(2, 2 + headerLength));
    final dataBytes = message.sublist(2 + headerLength);
    final headersMap = parseHeaders(headerStr);

    if (headersMap['Path'] != 'audio') {
      throw UnexpectedResponse('Binary path is not audio');
    }

    final contentType = headersMap['Content-Type'];
    if (contentType != null && contentType != 'audio/mpeg') {
      throw UnexpectedResponse('Unexpected Content-Type: $contentType');
    }

    // No Content-Type with empty data is normal at stream end
    if (contentType == null) {
      if (dataBytes.isEmpty) return null;
      throw UnexpectedResponse(
          'Binary message with no Content-Type but has data');
    }

    if (dataBytes.isEmpty) {
      throw UnexpectedResponse('Binary message missing audio data');
    }

    return dataBytes;
  }
}
