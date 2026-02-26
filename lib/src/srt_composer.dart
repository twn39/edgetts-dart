/// A library for composing SRT files.
///
/// Based on the Python srt_composer module from edge-tts.
/// Original Python version based on https://github.com/cdown/srt.


const int _secondsInHour = 3600;
const int _secondsInMinute = 60;
const int _hoursInDay = 24;
const int _microsecondsInMillisecond = 1000;

final RegExp _multiWsRegex = RegExp(r'\n\n+');

/// Represents a single subtitle entry with timing and content.
class Subtitle implements Comparable<Subtitle> {
  int? index;
  Duration start;
  Duration end;
  String content;

  Subtitle({
    this.index,
    required this.start,
    required this.end,
    required this.content,
  });

  @override
  int get hashCode => Object.hash(index, start, end, content);

  @override
  bool operator ==(Object other) {
    if (other is! Subtitle) return false;
    return index == other.index &&
        start == other.start &&
        end == other.end &&
        content == other.content;
  }

  @override
  int compareTo(Subtitle other) {
    final startCmp = start.compareTo(other.start);
    if (startCmp != 0) return startCmp;
    final endCmp = end.compareTo(other.end);
    if (endCmp != 0) return endCmp;
    return (index ?? 0).compareTo(other.index ?? 0);
  }

  /// Convert this subtitle to an SRT block string.
  String toSrt({String? eol}) {
    eol ??= '\n';
    var outputContent = makeLegalContent(content);

    if (eol != '\n') {
      outputContent = outputContent.replaceAll('\n', eol);
    }

    return '${index ?? 0}$eol'
        '${timedeltaToSrtTimestamp(start)} --> ${timedeltaToSrtTimestamp(end)}$eol'
        '$outputContent$eol'
        '$eol';
  }

  @override
  String toString() => toSrt();
}

/// Remove illegal content from a subtitle content block.
///
/// Removes blank lines and leading/trailing blank lines.
String makeLegalContent(String content) {
  if (content.isNotEmpty && content[0] != '\n' && !content.contains('\n\n')) {
    return content;
  }

  // Strip leading/trailing newlines, then collapse multiple newlines
  String stripped = content;
  while (stripped.startsWith('\n')) {
    stripped = stripped.substring(1);
  }
  while (stripped.endsWith('\n')) {
    stripped = stripped.substring(0, stripped.length - 1);
  }

  return _multiWsRegex.hasMatch(stripped)
      ? stripped.replaceAll(_multiWsRegex, '\n')
      : stripped;
}

/// Convert a [Duration] to an SRT timestamp string.
///
/// Format: `HH:MM:SS,mmm`
String timedeltaToSrtTimestamp(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hrs = totalSeconds ~/ _secondsInHour;
  final secsRemainder = totalSeconds % _secondsInHour;
  final mins = secsRemainder ~/ _secondsInMinute;
  final secs = secsRemainder % _secondsInMinute;
  final msecs = duration.inMilliseconds % 1000;

  return '${hrs.toString().padLeft(2, '0')}:'
      '${mins.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')},'
      '${msecs.toString().padLeft(3, '0')}';
}

/// Check if a subtitle should be skipped.
///
/// Returns a reason string if it should be skipped, null otherwise.
String? _shouldSkipSub(Subtitle subtitle) {
  if (subtitle.content.trim().isEmpty) return 'No content';
  if (subtitle.start < Duration.zero) return 'Start time < 0 seconds';
  if (subtitle.start >= subtitle.end) {
    return 'Subtitle start time >= end time';
  }
  return null;
}

/// Sort subtitles by start time and reindex them.
Iterable<Subtitle> sortAndReindex(
  List<Subtitle> subtitles, {
  int startIndex = 1,
  bool inPlace = false,
  bool skip = true,
}) sync* {
  final sorted = List<Subtitle>.from(subtitles)..sort();

  int skippedSubs = 0;
  int subNum = startIndex;

  for (final subtitle in sorted) {
    final sub = inPlace
        ? subtitle
        : Subtitle(
            index: subtitle.index,
            start: subtitle.start,
            end: subtitle.end,
            content: subtitle.content,
          );

    if (skip) {
      final skipReason = _shouldSkipSub(sub);
      if (skipReason != null) {
        skippedSubs++;
        subNum++;
        continue;
      }
    }

    sub.index = subNum - skippedSubs;
    yield sub;
    subNum++;
  }
}

/// Convert a list of [Subtitle] objects to an SRT formatted string.
String compose(
  List<Subtitle> subtitles, {
  bool reindex = true,
  int startIndex = 1,
  String? eol,
  bool inPlace = false,
}) {
  final subs = reindex
      ? sortAndReindex(subtitles, startIndex: startIndex, inPlace: inPlace)
      : subtitles;

  return subs.map((s) => s.toSrt(eol: eol)).join();
}
