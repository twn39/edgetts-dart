@Tags(['network'])
import 'dart:io';
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
          metadataReceived = true;
        }
      }

      expect(audioReceived, isTrue);
      expect(metadataReceived, isTrue);
    });

    test('Communicate save writes audio and metadata to files', () async {
      final tempDir = await Directory.systemTemp.createTemp('edge_tts_test_');
      final audioPath = '${tempDir.path}/test.mp3';
      final metadataPath = '${tempDir.path}/test.jsonl';

      final communicate = Communicate(
        text: 'Hello world',
        voice: 'en-US-AriaNeural',
        boundary: 'WordBoundary',
      );

      await communicate.save(audioPath, metadataPath: metadataPath);

      final audioFile = File(audioPath);
      final metadataFile = File(metadataPath);

      expect(await audioFile.exists(), isTrue);
      expect(await audioFile.length(), greaterThan(0));

      expect(await metadataFile.exists(), isTrue);
      expect(await metadataFile.length(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });
  });
}
