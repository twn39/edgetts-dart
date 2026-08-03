import 'dart:convert';
import 'package:test/test.dart';
import 'package:edge_tts_dart/src/exceptions.dart';
import 'package:edge_tts_dart/src/message_parser.dart';

void main() {
  group('MessageParser', () {
    test('parseHeaders extracts header key-value map', () {
      final headerStr =
          'Path:speech.config\r\nContent-Type:application/json\r\nX-Timestamp:Wed Aug 03 2026';
      final headers = MessageParser.parseHeaders(headerStr);

      expect(headers['Path'], equals('speech.config'));
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['X-Timestamp'], equals('Wed Aug 03 2026'));
    });

    test('parseTextMessage handles turn.end path', () {
      final msg = 'Path:turn.end\r\n\r\n';
      final result = MessageParser.parseTextMessage(msg, 0.0);

      expect(result.isTurnEnd, isTrue);
      expect(result.path, equals('turn.end'));
    });

    test('parseTextMessage handles response and turn.start path', () {
      final msgStart = 'Path:turn.start\r\n\r\n';
      final resultStart = MessageParser.parseTextMessage(msgStart, 0.0);
      expect(resultStart.path, equals('turn.start'));
      expect(resultStart.isTurnEnd, isFalse);

      final msgResp = 'Path:response\r\n\r\n';
      final resultResp = MessageParser.parseTextMessage(msgResp, 0.0);
      expect(resultResp.path, equals('response'));
    });

    test('parseTextMessage throws UnknownResponse for unknown path', () {
      final msg = 'Path:unknown.path\r\n\r\n';
      expect(
        () => MessageParser.parseTextMessage(msg, 0.0),
        throwsA(isA<UnknownResponse>()),
      );
    });

    test(
        'parseMetadata throws UnexpectedResponse when no WordBoundary/SentenceBoundary found',
        () {
      final jsonStr = '{"Metadata":[]}';
      expect(
        () => MessageParser.parseMetadata(jsonStr, 0.0),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('parseMetadata throws UnknownResponse for unknown metadata type', () {
      final jsonStr = '{"Metadata":[{"Type":"UnknownType"}]}';
      expect(
        () => MessageParser.parseMetadata(jsonStr, 0.0),
        throwsA(isA<UnknownResponse>()),
      );
    });

    test('parseMetadata parses WordBoundary correctly with compensation', () {
      final jsonStr = jsonEncode({
        'Metadata': [
          {
            'Type': 'WordBoundary',
            'Data': {
              'Offset': 1000,
              'Duration': 500,
              'text': {'Text': 'Hello'},
            }
          }
        ]
      });

      final meta = MessageParser.parseMetadata(jsonStr, 200.0);
      expect(meta.type, equals('WordBoundary'));
      expect(meta.offset, equals(1200.0));
      expect(meta.duration, equals(500.0));
      expect(meta.text, equals('Hello'));
    });

    test('parseBinaryMessage extracts valid audio bytes', () {
      final headerStr = 'Path:audio\r\nContent-Type:audio/mpeg\r\n';
      final headerBytes = utf8.encode(headerStr);
      final headerLength = headerBytes.length;

      final dataBytes = [1, 2, 3, 4, 5];
      final message = [
        (headerLength >> 8) & 0xFF,
        headerLength & 0xFF,
        ...headerBytes,
        ...dataBytes
      ];

      final result = MessageParser.parseBinaryMessage(message);
      expect(result, equals(dataBytes));
    });

    test('parseBinaryMessage returns null for empty stream end binary frame',
        () {
      final headerStr = 'Path:audio\r\n';
      final headerBytes = utf8.encode(headerStr);
      final headerLength = headerBytes.length;

      final message = [
        (headerLength >> 8) & 0xFF,
        headerLength & 0xFF,
        ...headerBytes
      ];

      final result = MessageParser.parseBinaryMessage(message);
      expect(result, isNull);
    });

    test('parseBinaryMessage throws UnexpectedResponse for invalid frames', () {
      // Too short
      expect(() => MessageParser.parseBinaryMessage([1]),
          throwsA(isA<UnexpectedResponse>()));

      // Header length > data length
      expect(() => MessageParser.parseBinaryMessage([0, 100, 1, 2]),
          throwsA(isA<UnexpectedResponse>()));
    });
  });
}
