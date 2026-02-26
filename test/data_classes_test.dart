import 'package:test/test.dart';
import 'package:edge_tts_dart/src/data_classes.dart';

void main() {
  group('TTSConfig validation', () {
    test('invalid rate throws ArgumentError', () {
      expect(
        () => TTSConfig(rate: 'bad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid volume throws ArgumentError', () {
      expect(
        () => TTSConfig(volume: 'bad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid pitch throws ArgumentError', () {
      expect(
        () => TTSConfig(pitch: 'bad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid boundary throws ArgumentError', () {
      expect(
        () => TTSConfig(boundary: 'InvalidBoundary'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid voice format throws ArgumentError', () {
      expect(
        () => TTSConfig(voice: 'totally-invalid-voice'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('valid short voice name is converted to long format', () {
      final config = TTSConfig(voice: 'en-US-AriaNeural');
      expect(config.voice, startsWith('Microsoft Server Speech Text to Speech Voice'));
      expect(config.voice, contains('en-US'));
      expect(config.voice, contains('AriaNeural'));
    });

    test('voice with region sub-code is handled', () {
      // e.g. zh-CN-XiaoxiaoNeural (no dash in name) vs fil-PH-AngeloNeural
      final config = TTSConfig(voice: 'zh-CN-XiaoxiaoNeural');
      expect(config.voice, contains('zh-CN'));
    });

    test('voice with dash in name is handled', () {
      // Some voices have names like "en-IE-ConnorNeural" which is fine,
      // but edge cases like sub-regions: "zh-CN-liaoning-XiaobeiNeural"
      final config = TTSConfig(voice: 'zh-CN-XiaobeiNeural');
      expect(config.voice, startsWith('Microsoft Server Speech Text to Speech Voice'));
    });
  });

  group('Voice.fromJson', () {
    test('handles missing VoiceTag', () {
      final voice = Voice.fromJson({
        'Name': 'Test',
        'ShortName': 'test',
        'Gender': 'Female',
        'Locale': 'en-US',
        'SuggestedCodec': 'audio-24khz',
        'FriendlyName': 'Test Voice',
        'Status': 'GA',
      });
      expect(voice.voiceTag, isNotEmpty);
      expect(voice.voiceTag['ContentCategories'], isA<List>());
      expect(voice.voiceTag['VoicePersonalities'], isA<List>());
    });

    test('handles null fields with defaults', () {
      final voice = Voice.fromJson({});
      expect(voice.name, equals(''));
      expect(voice.shortName, equals(''));
      expect(voice.gender, equals(''));
      expect(voice.locale, equals(''));
    });

    test('preserves existing VoiceTag fields', () {
      final voice = Voice.fromJson({
        'Name': 'Test',
        'ShortName': 'test',
        'Gender': 'Male',
        'Locale': 'en-US',
        'SuggestedCodec': 'audio-24khz',
        'FriendlyName': 'Test',
        'Status': 'GA',
        'VoiceTag': {
          'ContentCategories': ['General'],
          'VoicePersonalities': ['Friendly'],
        },
      });
      expect(voice.voiceTag['ContentCategories'], equals(['General']));
      expect(voice.voiceTag['VoicePersonalities'], equals(['Friendly']));
    });
  });

  group('Metadata', () {
    test('toJson produces correct map', () {
      final meta = Metadata(
        type: 'WordBoundary',
        offset: 1000.0,
        duration: 500.0,
        text: 'Hello',
      );
      final json = meta.toJson();
      expect(json['type'], equals('WordBoundary'));
      expect(json['offset'], equals(1000.0));
      expect(json['duration'], equals(500.0));
      expect(json['text'], equals('Hello'));
    });
  });

  group('TTSChunk', () {
    test('const constructor works', () {
      const chunk = TTSChunk(type: 'audio');
      expect(chunk.type, equals('audio'));
      expect(chunk.audioData, isNull);
      expect(chunk.metadata, isNull);
    });
  });
}
