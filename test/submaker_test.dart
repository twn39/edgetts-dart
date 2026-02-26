import 'package:test/test.dart';
import 'package:edge_tts_dart/src/submaker.dart';
import 'package:edge_tts_dart/src/data_classes.dart';

void main() {
  group('SubMaker', () {
    test('feed and getSrt generates valid SRT', () {
      final subMaker = SubMaker();

      // Simulate WordBoundary events with offsets in 100-nanosecond ticks
      // 1 second = 10,000,000 ticks
      subMaker.feed(TTSChunk(
        type: 'WordBoundary',
        metadata: Metadata(
          type: 'WordBoundary',
          offset: 0, // 0 seconds
          duration: 5000000, // 0.5 seconds
          text: 'Hello',
        ),
      ));

      subMaker.feed(TTSChunk(
        type: 'WordBoundary',
        metadata: Metadata(
          type: 'WordBoundary',
          offset: 6000000, // 0.6 seconds
          duration: 4000000, // 0.4 seconds
          text: 'World',
        ),
      ));

      final srt = subMaker.getSrt();
      expect(srt, contains('Hello'));
      expect(srt, contains('World'));
      expect(srt, contains('-->'));
      expect(srt, contains('1\n'));
      expect(srt, contains('2\n'));
    });

    test('feed rejects audio chunks', () {
      final subMaker = SubMaker();
      expect(
        () => subMaker.feed(TTSChunk(type: 'audio', audioData: [1, 2, 3])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('feed rejects mixed boundary types', () {
      final subMaker = SubMaker();

      subMaker.feed(TTSChunk(
        type: 'WordBoundary',
        metadata: Metadata(
          type: 'WordBoundary',
          offset: 0,
          duration: 5000000,
          text: 'Hello',
        ),
      ));

      expect(
        () => subMaker.feed(TTSChunk(
          type: 'SentenceBoundary',
          metadata: Metadata(
            type: 'SentenceBoundary',
            offset: 6000000,
            duration: 4000000,
            text: 'World',
          ),
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getSrt with no cues returns empty string', () {
      final subMaker = SubMaker();
      expect(subMaker.getSrt(), equals(''));
    });

    test('toString returns same as getSrt', () {
      final subMaker = SubMaker();
      subMaker.feed(TTSChunk(
        type: 'SentenceBoundary',
        metadata: Metadata(
          type: 'SentenceBoundary',
          offset: 0,
          duration: 10000000,
          text: 'Test sentence.',
        ),
      ));

      expect(subMaker.toString(), equals(subMaker.getSrt()));
    });
  });
}
