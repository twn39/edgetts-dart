import 'package:test/test.dart';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() {
  group('Real API Voice List', () {
    test('listVoices retrieves real voice data', () async {
      print("Fetching voices from API...");
      final voices = await listVoices();
      
      print("Fetched ${voices.length} voices.");
      expect(voices, isNotEmpty, reason: "Voice list should not be empty");
      
      // Check for structural validity
      for (final voice in voices) {
        expect(voice.name, isNotEmpty, reason: "Name should not be empty");
        expect(voice.shortName, isNotEmpty, reason: "ShortName should not be empty");
        expect(voice.locale, isNotEmpty, reason: "Locale should not be empty");
        expect(voice.gender, isNotEmpty, reason: "Gender should not be empty");
        expect(voice.suggestedCodec, isNotEmpty, reason: "SuggestedCodec should not be empty");
        expect(voice.friendlyName, isNotEmpty, reason: "FriendlyName should not be empty");
        expect(voice.status, isNotEmpty, reason: "Status should not be empty");
        
        expect(voice.voiceTag, isNotNull, reason: "VoiceTag should not be null");
        // Verify common VoiceTag keys if they exist
        if (voice.voiceTag.containsKey('ContentCategories')) {
          expect(voice.voiceTag['ContentCategories'], isA<List>(), reason: "ContentCategories should be a List");
        }
        if (voice.voiceTag.containsKey('VoicePersonalities')) {
          expect(voice.voiceTag['VoicePersonalities'], isA<List>(), reason: "VoicePersonalities should be a List");
        }
      }

      // Check for specific known voices to prove real data
      final aria = voices.where((v) => v.shortName == "en-US-AriaNeural");
      expect(aria, isNotEmpty, reason: "Should contain en-US-AriaNeural");
      
      final xiaoxiao = voices.where((v) => v.shortName == "zh-CN-XiaoxiaoNeural");
      expect(xiaoxiao, isNotEmpty, reason: "Should contain zh-CN-XiaoxiaoNeural");
      
      // Check details of one voice
      final v = aria.first;
      expect(v.locale, equals("en-US"));
      expect(v.gender, equals("Female"));
      expect(v.status, equals("GA")); // Assuming it's GA
    });
  });
}
