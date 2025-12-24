import 'package:test/test.dart';
import 'package:edge_tts_dart/src/drm.dart';

void main() {
  group('DRM', () {
    test('generateSecMsGec returns valid hash', () {
      final hash = DRM.generateSecMsGec();
      expect(hash, hasLength(64));
      expect(RegExp(r'^[0-9A-F]+$').hasMatch(hash), isTrue);
    });

    test('generateMuid returns valid hex string', () {
      final muid = DRM.generateMuid();
      expect(muid, hasLength(32));
      expect(RegExp(r'^[0-9A-F]+$').hasMatch(muid), isTrue);
    });

    test('headersWithMuid adds Cookie header', () {
        final headers = {"User-Agent": "Test"};
        final newHeaders = DRM.headersWithMuid(headers);
        
        expect(newHeaders.containsKey("Cookie"), isTrue);
        expect(newHeaders["Cookie"], startsWith("muid="));
        expect(newHeaders["User-Agent"], equals("Test"));
    });
    
    test('parseRfc2616Date parses correctly', () {
        // "Wed, 21 Oct 2015 07:28:00 GMT" -> 1445412480.0
        final timestamp = DRM.parseRfc2616Date("Wed, 21 Oct 2015 07:28:00 GMT");
        expect(timestamp, equals(1445412480.0));
    });
  });
}
