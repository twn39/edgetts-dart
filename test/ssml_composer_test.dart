import 'package:test/test.dart';
import 'package:edge_tts_dart/src/data_classes.dart';
import 'package:edge_tts_dart/src/ssml_composer.dart';

void main() {
  group('SSMLComposer', () {
    test('buildCommandConfig generates valid speech.config headers and json',
        () {
      final config = TTSConfig(
        voice: 'en-US-AriaNeural',
        boundary: 'SentenceBoundary',
      );

      final payload = SSMLComposer.buildCommandConfig(config);
      expect(payload, contains('Path:speech.config'));
      expect(payload, contains('"sentenceBoundaryEnabled":"true"'));
      expect(payload, contains('"wordBoundaryEnabled":"false"'));
      expect(payload,
          contains('"outputFormat":"audio-24khz-48kbitrate-mono-mp3"'));
    });

    test(
        'buildCommandConfig sets wordBoundaryEnabled when boundary is WordBoundary',
        () {
      final config = TTSConfig(
        voice: 'en-US-AriaNeural',
        boundary: 'WordBoundary',
      );

      final payload = SSMLComposer.buildCommandConfig(config);
      expect(payload, contains('"sentenceBoundaryEnabled":"false"'));
      expect(payload, contains('"wordBoundaryEnabled":"true"'));
    });

    test('buildSsmlRequest generates valid SSML headers and body', () {
      final config = TTSConfig(voice: 'en-US-AriaNeural');
      final payload =
          SSMLComposer.buildSsmlRequest('test-conn-id', config, 'Hello World');

      expect(payload, contains('X-RequestId:test-conn-id'));
      expect(payload, contains('Path:ssml'));
      expect(
          payload,
          contains(
              '<voice name=\'Microsoft Server Speech Text to Speech Voice (en-US, AriaNeural)\'>'));
      expect(payload, contains('Hello World'));
    });
  });
}
