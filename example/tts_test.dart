import 'dart:io';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  final text = '你好，这是一个语音合成测试。Hello, this is a text to speech test.';
  print('Generating audio...');

  final communicate = Communicate(
    text: text,
    voice: 'zh-CN-XiaoxiaoNeural',
  );

  final subMaker = SubMaker();
  final sink = File('tts_output.mp3').openWrite();

  await for (final chunk in communicate.stream()) {
    if (chunk.type == 'audio') {
      sink.add(chunk.audioData!);
    } else if (chunk.type == 'WordBoundary' || chunk.type == 'SentenceBoundary') {
      subMaker.feed(chunk);
    }
  }
  await sink.close();

  final srt = subMaker.getSrt();
  await File('tts_output.srt').writeAsString(srt);

  final size = await File('tts_output.mp3').length();
  print('Audio: tts_output.mp3 ($size bytes)');
  print('SRT: tts_output.srt');
  print(srt);
}
