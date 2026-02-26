import 'package:test/test.dart';
import 'package:edge_tts_dart/src/voices.dart';
import 'package:edge_tts_dart/src/data_classes.dart';

void main() {
  group('VoicesManager', () {
    final mockVoices = [
      Voice(
        name:
            'Microsoft Server Speech Text to Speech Voice (en-US, AriaNeural)',
        shortName: 'en-US-AriaNeural',
        gender: 'Female',
        locale: 'en-US',
        suggestedCodec: 'audio-24khz-48kbitrate-mono-mp3',
        friendlyName: 'Microsoft Aria Online (Natural) - English (US)',
        status: 'GA',
        voiceTag: {
          'ContentCategories': ['General'],
          'VoicePersonalities': ['Friendly', 'Positive'],
        },
      ),
      Voice(
        name: 'Microsoft Server Speech Text to Speech Voice (en-US, GuyNeural)',
        shortName: 'en-US-GuyNeural',
        gender: 'Male',
        locale: 'en-US',
        suggestedCodec: 'audio-24khz-48kbitrate-mono-mp3',
        friendlyName: 'Microsoft Guy Online (Natural) - English (US)',
        status: 'GA',
        voiceTag: {
          'ContentCategories': ['General'],
          'VoicePersonalities': ['Friendly'],
        },
      ),
      Voice(
        name:
            'Microsoft Server Speech Text to Speech Voice (zh-CN, XiaoxiaoNeural)',
        shortName: 'zh-CN-XiaoxiaoNeural',
        gender: 'Female',
        locale: 'zh-CN',
        suggestedCodec: 'audio-24khz-48kbitrate-mono-mp3',
        friendlyName: 'Microsoft Xiaoxiao Online (Natural) - Chinese',
        status: 'GA',
        voiceTag: {
          'ContentCategories': ['General'],
          'VoicePersonalities': ['Warm'],
        },
      ),
    ];

    test('create with custom voices', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      expect(manager.voices, hasLength(3));
    });

    test('find by gender', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      final females = manager.find(gender: 'Female');
      expect(females, hasLength(2));
      expect(females.every((v) => v.gender == 'Female'), isTrue);
    });

    test('find by locale', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      final enUs = manager.find(locale: 'en-US');
      expect(enUs, hasLength(2));
      expect(enUs.every((v) => v.locale == 'en-US'), isTrue);
    });

    test('find by language', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      final zh = manager.find(language: 'zh');
      expect(zh, hasLength(1));
      expect(zh.first.shortName, equals('zh-CN-XiaoxiaoNeural'));
    });

    test('find by multiple criteria', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      final result = manager.find(gender: 'Female', locale: 'en-US');
      expect(result, hasLength(1));
      expect(result.first.shortName, equals('en-US-AriaNeural'));
    });

    test('find returns empty list for no matches', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      final result = manager.find(locale: 'fr-FR');
      expect(result, isEmpty);
    });

    test('VoicesManagerVoice has language field', () async {
      final manager = await VoicesManager.create(customVoices: mockVoices);
      final voice = manager.voices.first;
      expect(voice.language, equals('en'));
    });
  });
}
