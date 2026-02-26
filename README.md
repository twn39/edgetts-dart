<div align="center">

# Edge TTS Dart

[![Tests](https://github.com/twn39/edgetts-dart/actions/workflows/test.yml/badge.svg)](https://github.com/twn39/edgetts-dart/actions/workflows/test.yml) [![codecov](https://codecov.io/gh/twn39/edgetts-dart/graph/badge.svg?token=N8E25TJS9F)](https://codecov.io/gh/twn39/edgetts-dart) [![Dart SDK](https://img.shields.io/badge/Dart-3.0%2B-blue.svg)](https://dart.dev) [![Platform](https://img.shields.io/badge/Platform-Flutter%20%7C%20Dart%20Native-blue.svg)](https://flutter.dev) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A pure Dart implementation of the excellent [edge-tts](https://github.com/rany2/edge-tts) library.
Access Microsoft Edge's online text-to-speech service from Dart and Flutter applications without needing a Microsoft Azure subscription or API key.

</div>

## Features

- 🚀 **Zero Dependencies**: Does not require an API key or Azure subscription.
- 📱 **Cross-Platform**: Works purely with Dart (`dart:io` compatible), perfect for Flutter mobile and desktop apps.
- 🗣️ **All Voices**: Access to all Microsoft Edge voices (300+ voices across many languages & locales).
- 🌊 **Streaming Audio**: Supports real-time audio streaming via WebSocket.
- 📝 **Metadata Support**: Receive `WordBoundary` and `SentenceBoundary` events for text highlighting synchronization.
- 🎛️ **SSML Support**: Full control over pitch, rate, and volume.
- 💾 **Save to File**: Built-in `save()` method for quick audio file generation.
- 📋 **Subtitle Generation**: `SubMaker` and SRT composer for generating synchronized subtitles.
- 🔍 **Voice Manager**: `VoicesManager` class for filtering voices by gender, locale, or language.
- ⏱️ **Timeout Control**: Configurable `connectTimeout` and `receiveTimeout` for network operations.

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
  final voices = await listVoices();
  print("Found ${voices.length} voices!");

  // Filter for English voices
  final englishVoices = voices.where((v) => v.locale.startsWith("en-"));
  for (final voice in englishVoices) {
    print("${voice.shortName} - ${voice.gender}");
  }
}
```

### Finding Voices with VoicesManager

```dart
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  final manager = await VoicesManager.create();

  // Find all female English (US) voices
  final voices = manager.find(gender: 'Female', locale: 'en-US');
  for (final voice in voices) {
    print("${voice.shortName} (${voice.language})");
  }

  // Find all Chinese voices
  final zhVoices = manager.find(language: 'zh');
  print("Found ${zhVoices.length} Chinese voices.");
}
```

### Generating Audio (Streaming)

```dart
import 'dart:io';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  final communicate = Communicate(
    text: "Hello, world! This is a test of Edge TTS in Dart.",
    voice: "en-US-AriaNeural",
    rate: "+0%",
    volume: "+0%",
    pitch: "+0Hz",
  );

  final sink = File("output.mp3").openWrite();

  try {
    await for (final chunk in communicate.stream()) {
      if (chunk.type == "audio") {
        sink.add(chunk.audioData!);
      } else if (chunk.type == "WordBoundary") {
        print("Word: ${chunk.metadata!.text} at ${chunk.metadata!.offset}");
      }
    }
  } finally {
    await sink.close();
  }
}
```

### Save to File (Quick Method)

```dart
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  final communicate = Communicate(
    text: "Hello, this is a quick save example.",
    voice: "en-US-GuyNeural",
  );

  // Save audio and metadata in one call
  await communicate.save("output.mp3", metadataPath: "output.json");
}
```

### Generating Subtitles (SRT)

```dart
import 'dart:io';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() async {
  final communicate = Communicate(
    text: "Hello, this is a subtitle test.",
    voice: "en-US-AriaNeural",
    boundary: "SentenceBoundary", // or "WordBoundary"
  );

  final subMaker = SubMaker();
  final sink = File("output.mp3").openWrite();

  await for (final chunk in communicate.stream()) {
    if (chunk.type == "audio") {
      sink.add(chunk.audioData!);
    } else {
      subMaker.feed(chunk);
    }
  }
  await sink.close();

  // Generate and save SRT subtitles
  final srt = subMaker.getSrt();
  await File("output.srt").writeAsString(srt);
  print(srt);
}
```

## API Reference

### Communicate

| Parameter | Type | Default | Description |
|---|---|---|---|
| `text` | `String` | required | The text to synthesize |
| `voice` | `String?` | `en-US-AriaNeural` | Voice short name |
| `rate` | `String` | `+0%` | Speech rate adjustment |
| `volume` | `String` | `+0%` | Volume adjustment |
| `pitch` | `String` | `+0Hz` | Pitch adjustment |
| `boundary` | `String` | `SentenceBoundary` | Metadata granularity (`WordBoundary` or `SentenceBoundary`) |
| `connectTimeout` | `int` | `10` | WebSocket connection timeout in seconds |
| `receiveTimeout` | `int` | `60` | Response receive timeout in seconds |

### VoicesManager

| Method | Description |
|---|---|
| `VoicesManager.create()` | Fetch all voices and create a manager instance |
| `find({gender, locale, language})` | Filter voices by attributes |

### SubMaker

| Method | Description |
|---|---|
| `feed(TTSChunk chunk)` | Feed a boundary event from `stream()` |
| `getSrt()` | Generate SRT formatted subtitle string |

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
