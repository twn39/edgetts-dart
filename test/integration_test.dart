import 'package:test/test.dart';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() {
  group('Integration Tests', () {
    test('listVoices returns voices from API', () async {
      final voices = await listVoices();
      expect(voices, isNotEmpty);
      expect(voices.first.name, isNotEmpty);
      expect(voices.first.locale, isNotEmpty);
    });

    test('Communicate streams audio', () async {
      final communicate =
          Communicate(text: "Hello, world", voice: "en-US-AriaNeural");

      bool audioReceived = false;
      bool metadataReceived = false;

      await for (final chunk in communicate.stream()) {
        expect(chunk.type, anyOf("audio", "WordBoundary", "SentenceBoundary"),
            reason: "Unknown chunk type");

        if (chunk.type == "audio") {
          expect(chunk.audioData, isNotNull,
              reason: "Audio data should not be null for audio type");
          expect(chunk.audioData, isA<List<int>>(),
              reason: "Audio data should be List<int>");
          expect(chunk.audioData, isNotEmpty,
              reason: "Audio data should not be empty");
          audioReceived = true;
        } else if (chunk.type == "WordBoundary" ||
            chunk.type == "SentenceBoundary") {
          expect(chunk.metadata, isNotNull,
              reason: "Metadata should not be null for boundary type");
          final meta = chunk.metadata!;

          expect(meta.type, equals(chunk.type),
              reason: "Metadata type should match chunk type");
          expect(meta.offset, isA<double>(), reason: "Offset should be double");
          expect(meta.offset, greaterThanOrEqualTo(0),
              reason: "Offset should be non-negative");

          expect(meta.duration, isA<double>(),
              reason: "Duration should be double");
          expect(meta.duration, greaterThanOrEqualTo(0),
              reason: "Duration should be non-negative");

          expect(meta.text, isA<String>(), reason: "Text should be String");
          // For "Hello, world", text might be "Hello" or "," or "world"

          metadataReceived = true;
        }
      }

      expect(audioReceived, isTrue);
      // Metadata might not always be received for short text or depending on service,
      // but usually yes for "Hello, world".
      expect(metadataReceived, isTrue);
    });
  });
}
