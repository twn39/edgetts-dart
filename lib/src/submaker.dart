/// SubMaker module to generate subtitles from WordBoundary and SentenceBoundary events.

import 'srt_composer.dart';
import 'data_classes.dart';

/// SubMaker generates subtitles from WordBoundary/SentenceBoundary messages.
///
/// Usage:
/// ```dart
/// final subMaker = SubMaker();
/// await for (final chunk in communicate.stream()) {
///   if (chunk.type == 'audio') {
///     // write audio data ...
///   } else {
///     subMaker.feed(chunk);
///   }
/// }
/// final srt = subMaker.getSrt();
/// ```
class SubMaker {
  final List<Subtitle> cues = [];
  String? _type;

  /// Feed a WordBoundary or SentenceBoundary chunk to the SubMaker.
  ///
  /// Throws [ArgumentError] if the chunk type is not a boundary type,
  /// or if mixed types are fed (e.g. WordBoundary after SentenceBoundary).
  void feed(TTSChunk chunk) {
    if (chunk.type != 'WordBoundary' && chunk.type != 'SentenceBoundary') {
      throw ArgumentError(
        "Invalid message type '${chunk.type}', "
        "expected 'WordBoundary' or 'SentenceBoundary'.",
      );
    }

    if (_type == null) {
      _type = chunk.type;
    } else if (_type != chunk.type) {
      throw ArgumentError(
        "Expected message type '$_type', but got '${chunk.type}'.",
      );
    }

    final meta = chunk.metadata!;

    // meta.offset and meta.duration are in 100-nanosecond intervals (ticks).
    // Convert to microseconds: offset_ticks / 10 = microseconds.
    cues.add(Subtitle(
      index: cues.length + 1,
      start: Duration(microseconds: (meta.offset / 10).round()),
      end: Duration(microseconds: ((meta.offset + meta.duration) / 10).round()),
      content: meta.text,
    ));
  }

  /// Get the SRT formatted subtitles.
  String getSrt() {
    return compose(cues);
  }

  @override
  String toString() => getSrt();
}
