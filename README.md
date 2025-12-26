# Edge TTS Dart

[![Dart SDK](https://img.shields.io/badge/Dart-3.0%2B-blue.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Flutter%20%7C%20Dart%20Native-blue.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Pub Package](https://img.shields.io/pub/v/edge_tts_dart.svg)](https://pub.dev/packages/edge_tts_dart)

A pure Dart implementation of the excellent [edge-tts](https://github.com/rany2/edge-tts) library. 
Access Microsoft Edge's online text-to-speech service from Dart and Flutter applications without needing a Microsoft Azure subscription or API key.

## Features

- 🚀 **Zero Dependencies**: Does not require an API key or Azure subscription.
- 📱 **Cross-Platform**: Works purely with Dart (`dart:io` compatible), perfect for Flutter mobile and desktop apps.
- 🗣️ **All Voices**: Access to all Microsoft Edge voices (300+ voices across many languages & locales).
- 🌊 **Streaming Audio**: Supports real-time audio streaming via WebSocket.
- 📝 **Metadata Support**: Receive strict `WordBoundary` and `SentenceBoundary` events for text highlighting synchronization.
- 🎛️ **SSML Support**: Full control over pitch, rate, and volume.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  edge_tts_dart:
    git:
      url: https://github.com/twn39/edgetts-dart.git
```

## Usage

### Listing Available Voices

```dart
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  try {
    final voices = await listVoices();
    print("Found ${voices.length} voices!");
    
    // Filter for English voices
    final englishVoices = voices.where((v) => v.locale.startsWith("en-"));
    for (final voice in englishVoices) {
      print("${voice.shortName} - ${voice.gender}");
    }
  } catch (e) {
    print("Error: $e");
  }
}
```

### Generating Audio (Streaming)

```dart
import 'dart:io';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  final text = "Hello, world! This is a test of Edge TTS in Dart.";
  
  // Create the communicator
  final communicate = Communicate(
    text: text,
    voice: "en-US-AriaNeural", 
    rate: "+0%",
    volume: "+0%",
    pitch: "+0Hz",
  );

  final file = File("output.mp3");
  final sink = file.openWrite();

  try {
    // Stream the data
    await for (final chunk in communicate.stream()) {
      if (chunk.type == "audio") {
        // Write binary audio data
        sink.add(chunk.audioData!);
      } else if (chunk.type == "WordBoundary") {
        // Handle metadata for highlighting
        print("Word: ${chunk.metadata!.text} at ${chunk.metadata!.offset}ms");
      }
    }
  } finally {
    await sink.close();
  }
}
```

## Architecture

This library ports the logic from the Python `edge-tts` project:

*   **Communication**: Uses standard `wss://` WebSockets to talk to Edge's speech service.
*   **DRM**: Implements the required `Sec-MS-GEC` token generation for authentication.
*   **Protocol**: Handles the proprietary headers and binary payload splitting of the service.

## Testing & Coverage

To run tests:
```bash
dart test
```

To run tests with coverage validation (requires `lcov` for HTML reports):
```bash
./test_with_coverage.sh
```

## Acknowledgements

This project is a Dart port of the [edge-tts](https://github.com/rany2/edge-tts) Python library by [rany2](https://github.com/rany2).

## License

MIT
