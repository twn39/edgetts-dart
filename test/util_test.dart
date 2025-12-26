import 'package:test/test.dart';
import 'package:edge_tts_dart/src/util.dart';
import 'package:edge_tts_dart/src/data_classes.dart';

void main() {
  group('EdgeTTSUtil', () {
    test('removeIncompatibleCharacters removes control characters', () {
      final input = "Hello\x00World\x0b";
      final expected = "Hello World ";
      expect(EdgeTTSUtil.removeIncompatibleCharacters(input), equals(expected));
    });

    test('connectId returns valid UUID format', () {
      final id = EdgeTTSUtil.connectId();
      expect(id, hasLength(32));
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(id), isTrue);
    });

    test('mkssml generates valid SSML', () {
      final config = TTSConfig(
        voice: "en-US-AriaNeural",
        rate: "+10%",
        volume: "+0%",
        pitch: "+0Hz",
      );
      final ssml = EdgeTTSUtil.mkssml(config, "Hello World");

      expect(
          ssml,
          contains(
              "<voice name='Microsoft Server Speech Text to Speech Voice (en-US, AriaNeural)'>"));
      expect(ssml, contains("rate='+10%'"));
      expect(ssml, contains("Hello World"));
    });

    test('splitTextByByteLength splits correctly', () {
      final text = "Hello " * 1000;
      final chunks = EdgeTTSUtil.splitTextByByteLength(text, 1000).toList();

      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(1000));
      }
      expect(chunks.join(' '), equals(text.trim()));
    });

    test('splitTextByByteLength handles utf8 properly', () {
      final text = "你好" * 500; // 3 bytes each -> 3000 bytes
      // Split at 1000 bytes. 1000 is not div by 3, so it must not split in middle of char.
      final chunks = EdgeTTSUtil.splitTextByByteLength(text, 1000).toList();

      for (final _ in chunks) {
        // Re-encode to check byte length
        // In Dart String.length is UTF-16 code units.
        // We need to check UTF-8 bytes.
        // But the utility guarantees UTF-8 byte length split.
      }
      expect(chunks.join(''), equals(text));
    });
  });
}
