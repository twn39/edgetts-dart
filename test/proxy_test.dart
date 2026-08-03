import 'package:test/test.dart';
import 'package:edge_tts_dart/edge_tts_dart.dart';
import 'package:edge_tts_dart/src/util.dart';

void main() {
  group('Proxy Helper & Wiring', () {
    test('formatProxy formats http URL to PAC string', () {
      expect(EdgeTTSUtil.formatProxy('http://127.0.0.1:7890'),
          equals('PROXY 127.0.0.1:7890'));
      expect(EdgeTTSUtil.formatProxy('https://127.0.0.1:7890'),
          equals('PROXY 127.0.0.1:7890'));
    });

    test('formatProxy formats host:port to PAC string', () {
      expect(EdgeTTSUtil.formatProxy('127.0.0.1:7890'),
          equals('PROXY 127.0.0.1:7890'));
    });

    test('formatProxy preserves existing PROXY / SOCKS prefix', () {
      expect(EdgeTTSUtil.formatProxy('PROXY 127.0.0.1:7890'),
          equals('PROXY 127.0.0.1:7890'));
      expect(EdgeTTSUtil.formatProxy('SOCKS5 127.0.0.1:1080'),
          equals('SOCKS5 127.0.0.1:1080'));
    });

    test('Communicate stores proxy parameter', () {
      final communicate = Communicate(
        text: 'Test',
        proxy: '127.0.0.1:7890',
      );
      expect(communicate.proxy, equals('127.0.0.1:7890'));
    });

    test('VoicesManager accepts proxy parameter', () async {
      final mockVoice = Voice(
        name: 'Test',
        shortName: 'test',
        gender: 'Male',
        locale: 'en-US',
        suggestedCodec: 'mp3',
        friendlyName: 'Test',
        status: 'GA',
        voiceTag: {},
      );
      final manager = await VoicesManager.create(
        customVoices: [mockVoice],
        proxy: '127.0.0.1:7890',
      );
      expect(manager.voices, hasLength(1));
    });
  });
}
