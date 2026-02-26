import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'data_classes.dart';

/// Escape XML special characters in text for use in SSML.
///
/// Matches Python's `xml.sax.saxutils.escape()`.
String xmlEscape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Unescape XML entities back to their original characters.
///
/// Matches Python's `xml.sax.saxutils.unescape()`.
String xmlUnescape(String text) {
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

class EdgeTTSUtil {
  static String connectId() {
    return const Uuid().v4().replaceAll('-', '');
  }

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Return a JavaScript-style date string in UTC.
  static String dateToString() {
    final now = DateTime.now().toUtc();
    // DateTime.weekday: 1=Mon..7=Sun; _days[0]=Sun, so weekday%7 maps correctly
    final dayName = _days[now.weekday % 7];
    final monthName = _months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return '$dayName $monthName $day ${now.year} $hour:$minute:$second GMT+0000 (Coordinated Universal Time)';
  }

  static String removeIncompatibleCharacters(String string) {
    final buffer = StringBuffer();
    for (var i = 0; i < string.length; i++) {
      final code = string.codeUnitAt(i);
      if ((0 <= code && code <= 8) ||
          (11 <= code && code <= 12) ||
          (14 <= code && code <= 31)) {
        buffer.write(' ');
      } else {
        buffer.write(string[i]);
      }
    }
    return buffer.toString();
  }

  static String mkssml(TTSConfig tc, String escapedText) {
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>"
        "<voice name='${tc.voice}'>"
        "<prosody pitch='${tc.pitch}' rate='${tc.rate}' volume='${tc.volume}'>"
        "$escapedText"
        "</prosody>"
        "</voice>"
        "</speak>";
  }

  /// Split text into chunks of at most [byteLength] UTF-8 bytes.
  ///
  /// Splits at natural boundaries (newlines, spaces) and avoids breaking
  /// UTF-8 multi-byte characters or XML entities.
  static Iterable<String> splitTextByByteLength(
      String text, int byteLength) sync* {
    if (byteLength <= 0) {
      throw ArgumentError('byte_length must be greater than 0');
    }

    var bytes = utf8.encode(text);

    while (bytes.length > byteLength) {
      var splitAt = _findLastNewlineOrSpace(bytes, byteLength);

      if (splitAt < 0) {
        splitAt = _findSafeUtf8SplitPoint(bytes, byteLength);
      }

      splitAt = _adjustSplitPointForXmlEntity(bytes, splitAt);

      if (splitAt <= 0) {
        throw ArgumentError(
            'Maximum byte length is too small or invalid text structure.');
      }

      final chunk = utf8.decode(bytes.sublist(0, splitAt)).trim();
      if (chunk.isNotEmpty) yield chunk;

      bytes = bytes.sublist(splitAt);
    }

    final remaining = utf8.decode(bytes).trim();
    if (remaining.isNotEmpty) yield remaining;
  }

  static int _findLastNewlineOrSpace(List<int> bytes, int limit) {
    // 10 is \n, 32 is space
    for (int i = limit - 1; i >= 0; i--) {
      if (bytes[i] == 10) return i;
    }
    for (int i = limit - 1; i >= 0; i--) {
      if (bytes[i] == 32) return i;
    }
    return -1;
  }

  static int _findSafeUtf8SplitPoint(List<int> bytes, int limit) {
    // Back off from limit to find a valid UTF-8 boundary.
    // UTF-8 multi-byte chars are at most 4 bytes, so we only need
    // to check at most 3 bytes back from limit.
    var splitAt = limit.clamp(0, bytes.length);
    final minCheck = (splitAt - 4).clamp(0, splitAt);
    while (splitAt > minCheck) {
      try {
        utf8.decode(bytes.sublist(0, splitAt));
        return splitAt;
      } catch (_) {
        splitAt--;
      }
    }
    return splitAt;
  }

  static int _adjustSplitPointForXmlEntity(List<int> bytes, int splitAt) {
    // Loop to handle multiple '&' entities, matching Python's behavior.
    // If we split after '&' but before ';', we might be breaking an entity.
    while (splitAt > 0) {
      final sub = bytes.sublist(0, splitAt);
      int ampersandIndex = sub.lastIndexOf(38); // '&' is 38

      if (ampersandIndex == -1) break; // No '&' found, safe

      // Check if there is a ';' between the ampersand and the split point
      bool foundSemicolon = false;
      for (int i = ampersandIndex; i < splitAt; i++) {
        if (bytes[i] == 59) {
          // ';' is 59
          foundSemicolon = true;
          break;
        }
      }

      if (foundSemicolon) {
        // Found a terminated entity (like &amp;), safe to break
        break;
      }

      // Ampersand is not terminated before splitAt, move splitAt to it
      splitAt = ampersandIndex;
    }

    return splitAt;
  }
}
