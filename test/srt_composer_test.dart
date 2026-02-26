import 'package:test/test.dart';
import 'package:edge_tts_dart/src/srt_composer.dart';

void main() {
  group('SRT Composer', () {
    test('timedeltaToSrtTimestamp formats correctly', () {
      expect(
        timedeltaToSrtTimestamp(
            Duration(hours: 1, minutes: 23, seconds: 4)),
        equals('01:23:04,000'),
      );

      expect(
        timedeltaToSrtTimestamp(
            Duration(hours: 0, minutes: 0, seconds: 0, milliseconds: 500)),
        equals('00:00:00,500'),
      );

      expect(
        timedeltaToSrtTimestamp(Duration(
            hours: 12, minutes: 59, seconds: 59, milliseconds: 999)),
        equals('12:59:59,999'),
      );
    });

    test('makeLegalContent removes blank lines', () {
      expect(makeLegalContent('\nfoo\n\nbar\n'), equals('foo\nbar'));
      expect(makeLegalContent('foo'), equals('foo'));
      expect(makeLegalContent('foo\nbar'), equals('foo\nbar'));
    });

    test('Subtitle.toSrt generates correct format', () {
      final sub = Subtitle(
        index: 1,
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        content: 'Hello World',
      );

      final srt = sub.toSrt();
      expect(srt, contains('1\n'));
      expect(srt, contains('00:00:01,000 --> 00:00:02,000'));
      expect(srt, contains('Hello World'));
    });

    test('Subtitle comparison works correctly', () {
      final sub1 = Subtitle(
          index: 1,
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          content: 'first');
      final sub2 = Subtitle(
          index: 2,
          start: Duration(seconds: 2),
          end: Duration(seconds: 3),
          content: 'second');

      expect(sub1.compareTo(sub2), lessThan(0));
      expect(sub2.compareTo(sub1), greaterThan(0));
    });

    test('compose generates valid SRT output', () {
      final subs = [
        Subtitle(
            index: 1,
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
            content: 'Hello'),
        Subtitle(
            index: 2,
            start: Duration(seconds: 3),
            end: Duration(seconds: 4),
            content: 'World'),
      ];

      final srt = compose(subs);
      expect(srt, contains('1\n00:00:01,000 --> 00:00:02,000\nHello'));
      expect(srt, contains('2\n00:00:03,000 --> 00:00:04,000\nWorld'));
    });

    test('sortAndReindex reorders and reindexes', () {
      final subs = [
        Subtitle(
            index: 99,
            start: Duration(seconds: 2),
            end: Duration(seconds: 3),
            content: 'second'),
        Subtitle(
            index: 1,
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
            content: 'first'),
      ];

      final reindexed = sortAndReindex(subs).toList();
      expect(reindexed[0].index, equals(1));
      expect(reindexed[0].content, equals('first'));
      expect(reindexed[1].index, equals(2));
      expect(reindexed[1].content, equals('second'));
    });

    test('sortAndReindex skips invalid subtitles', () {
      final subs = [
        Subtitle(
            index: 1,
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
            content: 'valid'),
        Subtitle(
            index: 2,
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
            content: ''),
        Subtitle(
            index: 3,
            start: Duration(seconds: -1),
            end: Duration(seconds: 2),
            content: 'negative start'),
        Subtitle(
            index: 4,
            start: Duration(seconds: 3),
            end: Duration(seconds: 2),
            content: 'start >= end'),
      ];

      final reindexed = sortAndReindex(subs).toList();
      expect(reindexed.length, equals(1));
      expect(reindexed[0].content, equals('valid'));
    });

    test('Subtitle equality', () {
      final sub1 = Subtitle(
          index: 1,
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          content: 'test');
      final sub2 = Subtitle(
          index: 1,
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          content: 'test');
      final sub3 = Subtitle(
          index: 2,
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          content: 'test');

      expect(sub1, equals(sub2));
      expect(sub1, isNot(equals(sub3)));
    });

    test('Subtitle.toSrt with custom eol', () {
      final sub = Subtitle(
        index: 1,
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        content: 'Hello\nWorld',
      );
      final srt = sub.toSrt(eol: '\r\n');
      expect(srt, contains('\r\n'));
      expect(srt, contains('Hello\r\nWorld'));
    });

    test('Subtitle.toString returns SRT format', () {
      final sub = Subtitle(
        index: 1,
        start: Duration(seconds: 0),
        end: Duration(seconds: 1),
        content: 'test',
      );
      expect(sub.toString(), contains('00:00:00,000 --> 00:00:01,000'));
    });

    test('Subtitle with null index uses 0', () {
      final sub = Subtitle(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        content: 'test',
      );
      expect(sub.toSrt(), startsWith('0\n'));
    });

    test('timedeltaToSrtTimestamp handles days', () {
      // 25 hours = 1 day + 1 hour
      final ts = timedeltaToSrtTimestamp(Duration(hours: 25));
      expect(ts, equals('25:00:00,000'));
    });

    test('makeLegalContent handles leading newlines', () {
      expect(makeLegalContent('\nfoo'), equals('foo'));
      expect(makeLegalContent('\n\nfoo'), equals('foo'));
    });

    test('compose without reindex preserves original order', () {
      final subs = [
        Subtitle(
            index: 2,
            start: Duration(seconds: 3),
            end: Duration(seconds: 4),
            content: 'second'),
        Subtitle(
            index: 1,
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
            content: 'first'),
      ];

      final srt = compose(subs, reindex: false);
      // Without reindex, order should match input (second first)
      final idx2 = srt.indexOf('second');
      final idx1 = srt.indexOf('first');
      expect(idx2, lessThan(idx1));
    });
  });
}
