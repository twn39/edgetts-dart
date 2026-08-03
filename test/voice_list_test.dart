@Tags(['network'])
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() {
  group('Real API Voice List', () {
    test('listVoices retrieves real voice data', () async {
      print("Fetching voices from API...");
      final voices = await listVoices(timeout: const Duration(seconds: 30));

      print("Fetched ${voices.length} voices.");
      expect(voices, isNotEmpty, reason: "Voice list should not be empty");

      // Check for structural validity
      for (final voice in voices) {
        expect(voice.name, isNotEmpty, reason: "Name should not be empty");
        expect(voice.shortName, isNotEmpty,
            reason: "ShortName should not be empty");
        expect(voice.locale, isNotEmpty, reason: "Locale should not be empty");
        expect(voice.gender, isNotEmpty, reason: "Gender should not be empty");
        expect(voice.suggestedCodec, isNotEmpty,
            reason: "SuggestedCodec should not be empty");
        expect(voice.friendlyName, isNotEmpty,
            reason: "FriendlyName should not be empty");
        expect(voice.status, isNotEmpty, reason: "Status should not be empty");

        expect(voice.voiceTag, isNotNull,
            reason: "VoiceTag should not be null");
        // Verify common VoiceTag keys if they exist
        if (voice.voiceTag.containsKey('ContentCategories')) {
          expect(voice.voiceTag['ContentCategories'], isA<List>(),
              reason: "ContentCategories should be a List");
        }
        if (voice.voiceTag.containsKey('VoicePersonalities')) {
          expect(voice.voiceTag['VoicePersonalities'], isA<List>(),
              reason: "VoicePersonalities should be a List");
        }
      }

      // Check for specific known voices to prove real data
      final aria = voices.where((v) => v.shortName == "en-US-AriaNeural");
      expect(aria, isNotEmpty, reason: "Should contain en-US-AriaNeural");

      final xiaoxiao =
          voices.where((v) => v.shortName == "zh-CN-XiaoxiaoNeural");
      expect(xiaoxiao, isNotEmpty,
          reason: "Should contain zh-CN-XiaoxiaoNeural");

      // Check details of one voice
      final v = aria.first;
      expect(v.locale, equals("en-US"));
      expect(v.gender, equals("Female"));
      expect(v.status, equals("GA")); // Assuming it's GA
    });
  });

  group('Mock Client Voice List Errors', () {
    test('throws ClientException on HTTP non-200 status code', () async {
      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      expect(
        () => listVoices(client: client),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('handles HTTP 403 retry with date header clock skew', () async {
      int requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            'Forbidden',
            403,
            headers: {'date': 'Wed, 21 Oct 2026 07:28:00 GMT'},
          );
        } else if (requestCount == 2) {
          // Sync clock request
          return http.Response('OK', 200,
              headers: {'date': 'Wed, 21 Oct 2026 07:28:00 GMT'});
        } else {
          // Retry request after sync
          return http.Response(
            '[{"Name": "TestVoice", "ShortName": "test-voice", "Gender": "Female", "Locale": "en-US", "SuggestedCodec": "mp3", "FriendlyName": "Test", "Status": "GA"}]',
            200,
          );
        }
      });

      final voices = await listVoices(client: client);
      expect(voices, hasLength(1));
      expect(voices.first.shortName, equals('test-voice'));
    });
  });
}
