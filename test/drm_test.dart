import 'package:test/test.dart';
import 'package:edge_tts_dart/src/drm.dart';
import 'package:edge_tts_dart/src/exceptions.dart';

void main() {
  // Reset clock skew before each test to avoid state leaking
  setUp(() {
    DRM.clockSkewSeconds = 0.0;
  });

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

    test('adjClockSkewSeconds accumulates skew', () {
      expect(DRM.clockSkewSeconds, equals(0.0));
      DRM.adjClockSkewSeconds(5.0);
      expect(DRM.clockSkewSeconds, equals(5.0));
      DRM.adjClockSkewSeconds(-2.0);
      expect(DRM.clockSkewSeconds, equals(3.0));
    });

    test('getUnixTimestamp includes clock skew', () {
      final beforeSkew = DRM.getUnixTimestamp();
      DRM.adjClockSkewSeconds(100.0);
      final afterSkew = DRM.getUnixTimestamp();
      // Should be ~100 seconds apart (allow small tolerance for execution time)
      expect(afterSkew - beforeSkew, closeTo(100.0, 1.0));
    });

    test('handleClientResponseError adjusts skew from date header', () {
      final serverDate = "Wed, 21 Oct 2015 07:28:00 GMT";
      // This will set a large negative skew since server date is in the past
      DRM.handleClientResponseError(403, {'date': serverDate});
      expect(DRM.clockSkewSeconds, isNot(equals(0.0)));
    });

    test('handleClientResponseError throws on missing date header', () {
      expect(
        () => DRM.handleClientResponseError(403, {}),
        throwsA(isA<SkewAdjustmentError>()),
      );
    });

    test('handleClientResponseError throws on invalid date', () {
      expect(
        () => DRM.handleClientResponseError(403, {'date': 'not-a-date'}),
        throwsA(isA<SkewAdjustmentError>()),
      );
    });

    test('handleClientResponseError uses Date key (capital)', () {
      final serverDate = "Wed, 21 Oct 2015 07:28:00 GMT";
      DRM.handleClientResponseError(403, {'Date': serverDate});
      expect(DRM.clockSkewSeconds, isNot(equals(0.0)));
    });

    test('parseRfc2616Date returns null for too few parts', () {
      expect(DRM.parseRfc2616Date("short"), isNull);
    });

    test('parseRfc2616Date handles day-of-week without comma', () {
      // Some servers might send: "Wed 21 Oct 2015 07:28:00 GMT"
      final ts = DRM.parseRfc2616Date("Wed 21 Oct 2015 07:28:00 GMT");
      expect(ts, isNotNull);
    });

    test('parseRfc2616Date handles numeric start format', () {
      // Some formats: "21 Oct 2015 07:28:00 GMT"
      final ts = DRM.parseRfc2616Date("21 Oct 2015 07:28:00 GMT");
      expect(ts, isNotNull);
    });

    test('parseRfc2616Date returns null for invalid month', () {
      final ts = DRM.parseRfc2616Date("Wed, 21 Xxx 2015 07:28:00 GMT");
      expect(ts, isNull);
    });

    test('generateSecMsGec is deterministic within same 5-min window', () {
      final hash1 = DRM.generateSecMsGec();
      final hash2 = DRM.generateSecMsGec();
      expect(hash1, equals(hash2));
    });
  });
}
