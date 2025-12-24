import 'dart:io';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  print("Listing voices...");
  try {
    final voices = await listVoices();
    print("Found ${voices.length} voices.");
    if (voices.isNotEmpty) {
        print("First voice: ${voices.first.shortName} (${voices.first.locale})");
    }
  } catch (e) {
      print("Error listing voices: $e");
  }

  print("\nGenerating audio...");
  final text = "Hello, this is a test from Dart implementation of Edge TTS.";
  final communicate = Communicate(text: text);
  
  final file = File("test_audio.mp3");
  final sink = file.openWrite();
  
  try {
      await for (final chunk in communicate.stream()) {
          if (chunk.type == "audio" && chunk.audioData != null) {
              sink.add(chunk.audioData!);
          } else if (chunk.type == "WordBoundary") {
              print("Word boundary: ${chunk.metadata?.text} at ${chunk.metadata?.offset}ms");
          }
      }
      print("Audio saved to test_audio.mp3");
  } catch (e) {
      print("Error generating audio: $e");
  } finally {
      await sink.close();
  }
}
