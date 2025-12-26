import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'data_classes.dart';

class EdgeTTSUtil {
  static String connectId() {
    return const Uuid().v4().replaceAll('-', '');
  }

  static String dateToString() {
    // Return Javascript-style date string.
    // Python: "%a %b %d %Y %H:%M:%S GMT+0000 (Coordinated Universal Time)"
    // Dart doesn't have a direct formatter for this specific string in standard lib easily without intl.
    // But we can build it.

    final now = DateTime.now().toUtc();
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];

    // final weekday = days[now.weekday == 7 ? 0 : now.weekday]; // Unused
    // Wait, DateTime.weekday 1 is Monday.
    // We need to map 7 to 0 if our array starts with Sun, or just index correctly.
    // Let's stick to 1-based indexing for array if we change array order,
    // but let's just write logic:
    // If we use days[now.weekday % 7] -> 1%7=1(Mon), 7%7=0(Sun).
    // Since days[0] is Sun, this works.

    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    final year = now.year;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return "$dayName $monthName $day $year $hour:$minute:$second GMT+0000 (Coordinated Universal Time)";
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

  static Iterable<String> splitTextByByteLength(
      String text, int byteLength) sync* {
    if (byteLength <= 0) {
      throw ArgumentError("byte_length must be greater than 0");
    }

    // Convert to bytes to check length, but we mostly operate on string indices and verify byte lengths
    // Or we operate on bytes directly. Python operates on bytes.
    // In Dart, strings are UTF-16. Converting to UTF-8 bytes is easy.
    List<int> bytes = utf8.encode(text);

    while (bytes.length > byteLength) {
      int splitAt = _findLastNewlineOrSpace(bytes, byteLength);

      if (splitAt < 0) {
        splitAt = _findSafeUtf8SplitPoint(bytes, byteLength);
      }

      // This helper would need to operate on bytes or we map back to string.
      // Operating on bytes for performance and correctness with Python port.
      splitAt = _adjustSplitPointForXmlEntity(bytes, splitAt);

      if (splitAt <= 0) {
        throw Exception(
            "Maximum byte length is too small or invalid text structure.");
      }

      final chunk = bytes.sublist(0, splitAt);
      yield utf8.decode(chunk).trim();

      bytes = bytes.sublist(splitAt);
      // Avoid infinite loop if we didn't move
      if (splitAt == 0) bytes = bytes.sublist(1);
    }

    if (bytes.isNotEmpty) {
      yield utf8.decode(bytes).trim();
    }
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
    // Allow taking up to 'limit' bytes
    int splitAt = limit;
    // If we are cutting in the middle of a UTF-8 sequence, back off.
    // UTF-8 continuation bytes start with 10xxxxxx (0x80 to 0xBF).
    // Initial bytes are 0xxxxxxx (00-7F), 110xxxxx (C0-DF), 1110xxxx (E0-EF), 11110xxx (F0-F7).
    // We just need to ensure bytes[:splitAt] is valid.
    // Easiest is to try verify.

    while (splitAt > 0) {
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
    // Logic: if we split after '&' but before ';', we might be breaking an entity.
    // Search for last '&' before splitAt.

    final sub = bytes.sublist(0, splitAt);
    int ampersandIndex = sub.lastIndexOf(38); // '&' is 38

    if (ampersandIndex == -1) return splitAt;

    // Check if there is a ';' after ampersand within the range
    int semiColonIndex = -1;
    for (int i = ampersandIndex; i < splitAt; i++) {
      if (bytes[i] == 59) {
        // ';' is 59
        semiColonIndex = i;
        break;
      }
    }

    if (semiColonIndex != -1) {
      // Found terminated entity, safe.
      return splitAt;
    }

    // Unterminated, move split to ampersand
    return ampersandIndex;
  }
}
