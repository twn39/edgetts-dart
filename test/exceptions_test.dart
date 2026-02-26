import 'package:test/test.dart';
import 'package:edge_tts_dart/src/exceptions.dart';

void main() {
  group('Exceptions', () {
    test('EdgeTTSException toString', () {
      final e = EdgeTTSException('test error');
      expect(e.toString(), equals('EdgeTTSException: test error'));
      expect(e.message, equals('test error'));
    });

    test('NoAudioReceived', () {
      final e = NoAudioReceived('no audio');
      expect(e, isA<EdgeTTSException>());
      expect(e.toString(), contains('no audio'));
    });

    test('UnexpectedResponse', () {
      final e = UnexpectedResponse('unexpected');
      expect(e, isA<EdgeTTSException>());
      expect(e.toString(), contains('unexpected'));
    });

    test('UnknownResponse', () {
      final e = UnknownResponse('unknown');
      expect(e, isA<EdgeTTSException>());
      expect(e.toString(), contains('unknown'));
    });

    test('WebSocketError', () {
      final e = WebSocketError('ws error');
      expect(e, isA<EdgeTTSException>());
      expect(e.toString(), contains('ws error'));
    });

    test('SkewAdjustmentError', () {
      final e = SkewAdjustmentError('skew error');
      expect(e, isA<EdgeTTSException>());
      expect(e.toString(), contains('skew error'));
    });
  });
}
