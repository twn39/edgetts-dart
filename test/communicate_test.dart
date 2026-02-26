import 'dart:convert';
import 'package:test/test.dart';
import 'package:edge_tts_dart/src/util.dart';
import 'package:edge_tts_dart/src/data_classes.dart';

void main() {
  group('XML escape/unescape', () {
    test('xmlEscape escapes special characters', () {
      expect(xmlEscape('Hello & World'), equals('Hello &amp; World'));
      expect(xmlEscape('<tag>'), equals('&lt;tag&gt;'));
      expect(xmlEscape('a & b < c > d'), equals('a &amp; b &lt; c &gt; d'));
    });

    test('xmlEscape handles no special characters', () {
      expect(xmlEscape('Hello World'), equals('Hello World'));
    });

    test('xmlUnescape reverses xmlEscape', () {
      final original = 'Hello & World < > test';
      expect(xmlUnescape(xmlEscape(original)), equals(original));
    });

    test('xmlUnescape handles entities', () {
      expect(xmlUnescape('&lt;tag&gt;'), equals('<tag>'));
      expect(xmlUnescape('a &amp; b'), equals('a & b'));
    });
  });

  group('Communicate boundary wiring', () {
    test('TTSConfig boundary defaults to SentenceBoundary', () {
      final config = TTSConfig(
        voice: 'en-US-AriaNeural',
        rate: '+0%',
        volume: '+0%',
        pitch: '+0Hz',
      );
      expect(config.boundary, equals('SentenceBoundary'));
    });

    test('TTSConfig boundary can be set to WordBoundary', () {
      final config = TTSConfig(
        voice: 'en-US-AriaNeural',
        rate: '+0%',
        volume: '+0%',
        pitch: '+0Hz',
        boundary: 'WordBoundary',
      );
      expect(config.boundary, equals('WordBoundary'));
    });
  });

  group('adjustSplitPointForXmlEntity loop', () {
    test('handles multiple unterminated entities', () {
      // Text like "text &amp; more &lt" where the last entity is unterminated
      final text = 'text &amp; more &lt';
      final bytes = utf8.encode(text);

      // Split at end of text should move to before the unterminated '&lt'
      final chunks =
          EdgeTTSUtil.splitTextByByteLength(text, bytes.length).toList();
      // Should not crash and produce valid output
      expect(chunks.join(''), equals(text));
    });

    test('does not break terminated entities', () {
      final text = 'a &amp; b &lt; c';
      final bytes = utf8.encode(text);

      final chunks =
          EdgeTTSUtil.splitTextByByteLength(text, bytes.length).toList();
      expect(chunks.length, equals(1));
      expect(chunks[0], equals(text));
    });
  });
}
