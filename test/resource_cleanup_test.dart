import 'dart:async';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() {
  group('Resource Cleanup & Timeout Tests', () {
    test('listVoices respects timeout duration and throws TimeoutException',
        () async {
      final slowClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return http.Response('[]', 200);
      });

      expect(
        () => listVoices(
          client: slowClient,
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('Communicate supports close() and cancel() lifecycle control',
        () async {
      final comm = Communicate(
        text: 'Test cancellation lifecycle',
        connectTimeout: 1,
        receiveTimeout: 1,
      );

      expect(comm.isClosed, isFalse);
      expect(comm.receiveTimeout, equals(1));
      expect(comm.connectTimeout, equals(1));

      await comm.close();
      expect(comm.isClosed, isTrue);

      // Verify idempotency
      await comm.cancel();
      expect(comm.isClosed, isTrue);
    });
  });
}
