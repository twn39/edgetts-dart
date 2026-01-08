import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'constants.dart';
import 'exceptions.dart';

class DRM {
  static double clockSkewSeconds = 0.0;
  static const int winEpoch = 11644473600;
  static const double sToNs = 1e9;

  static void adjClockSkewSeconds(double skewSeconds) {
    clockSkewSeconds += skewSeconds;
  }

  static double getUnixTimestamp() {
    return (DateTime.now().toUtc().millisecondsSinceEpoch / 1000) +
        clockSkewSeconds;
  }

  static double? parseRfc2616Date(String date) {
    try {
      // Example: "Wed, 21 Oct 2015 07:28:00 GMT"

      final parts = date.split(' ');
      if (parts.length < 5) return null;

      // parts could be: ["Wed,", "21", "Oct", "2015", "07:28:00", "GMT"]
      // or similar. Some servers might omit day of week.

      int dayIdx = 1;
      int monthIdx = 2;
      int yearIdx = 3;
      int timeIdx = 4;

      if (!parts[0].endsWith(',')) {
        // Maybe no day of week? Or different format.
        // Let's be more flexible.
        if (parts[0].length == 3 && int.tryParse(parts[0]) == null) {
          // Likely day of week without comma
          dayIdx = 1;
        } else if (int.tryParse(parts[0]) != null) {
          // Likely starts with day
          dayIdx = 0;
          monthIdx = 1;
          yearIdx = 2;
          timeIdx = 3;
        }
      }

      final day = int.parse(parts[dayIdx]);
      final monthStr = parts[monthIdx];
      final year = int.parse(parts[yearIdx]);
      final timeParts = parts[timeIdx].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);

      final months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      final month = months.indexOf(monthStr) + 1;
      if (month == 0) return null;

      final dt = DateTime.utc(year, month, day, hour, minute, second);
      return dt.millisecondsSinceEpoch / 1000;
    } catch (e) {
      return null;
    }
  }

  static void handleClientResponseError(int status, Map<String, String> headers) {
    final serverDate = headers['date'] ?? headers['Date'];
    if (serverDate == null) {
      throw SkewAdjustmentError("No server date in headers.");
    }

    final serverDateParsed = parseRfc2616Date(serverDate);
    if (serverDateParsed == null) {
      throw SkewAdjustmentError("Failed to parse server date: $serverDate");
    }

    final clientDate = getUnixTimestamp();
    adjClockSkewSeconds(serverDateParsed - clientDate);
  }

  static String generateSecMsGec() {
    double ticks = getUnixTimestamp();
    ticks += winEpoch;
    
    // Round down to the nearest 5 minutes (300 seconds)
    ticks -= ticks % 300;
    
    // Convert to 100-nanosecond intervals
    // We use double arithmetic to precisely match the Python internal calculation
    // which is required for the service to accept the Sec-MS-GEC token.
    ticks *= 10000000;

    final strToHash = "${ticks.toStringAsFixed(0)}${Constants.trustedClientToken}";

    final bytes = utf8.encode(strToHash);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  static String generateMuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static Map<String, String> headersWithMuid(Map<String, String> headers) {
    final combinedHeaders = Map<String, String>.from(headers);
    if (!combinedHeaders.containsKey("Cookie")) {
      combinedHeaders["Cookie"] = "muid=${generateMuid()};";
    }
    return combinedHeaders;
  }
}
