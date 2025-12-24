import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
// import 'package:uuid/uuid.dart'; // Unused
import 'constants.dart';
// import 'exceptions.dart'; // Unused

class DRM {
  static double clockSkewSeconds = 0.0;
  static const int winEpoch = 11644473600;
  static const double sToNs = 1e9;

  static void adjClockSkewSeconds(double skewSeconds) {
    clockSkewSeconds += skewSeconds;
  }

  static double getUnixTimestamp() {
    return (DateTime.now().toUtc().millisecondsSinceEpoch / 1000) + clockSkewSeconds;
  }

  static double? parseRfc2616Date(String date) {
    try {
      // Dart's HttpDate.parse handles RFC 1123 which is essentially RFC 2616
      // But we might need to be careful about format.
      // Python: "%a, %d %b %Y %H:%M:%S %Z"
      // Example: "Wed, 21 Oct 2015 07:28:00 GMT"
      // HttpDate.parse("Wed, 21 Oct 2015 07:28:00 GMT") works in Dart.
      
      // We need to implement manual parsing if HttpDate is not available or reliable
      // But HttpDate is in dart:io. Since we want cross platform, avoiding dart:io is better if possible?
      // Actually dart:io is fine for mobile/desktop, but not web. 
      // Requirement: "prioritize mobile". dart:io is fine for mobile.
      // But if we want *web* support, we should use a different approach.
      // Let's use HttpDate for now, or just manual parsing to be safe and dependency-free.
      
      // Let's use a simple regex or intl if we included it.
      // Since I added intl, I could use it, but manual parsing for a specific format is often easier.
      // However, HttpDate is standard.
      // Let's implement a manual parser to avoid dart:io dependency for potential web support future-proofing.
      // Actually, let's just stick to mobile priority -> data:io is fine.
      // Wait, "convert to use dart... cross platform". 
      // Let's assume standard Dart libraries.
      
      // Implementation using a basic mapping:
      final parts = date.split(' ');
      if (parts.length < 6) return null;
      // parts: [Wed,, 21, Oct, 2015, 07:28:00, GMT]
      // Removing comma from day name
      
      final day = int.parse(parts[1]);
      final monthStr = parts[2];
      final year = int.parse(parts[3]);
      final timeParts = parts[4].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);
      
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final month = months.indexOf(monthStr) + 1;
      
      final dt = DateTime.utc(year, month, day, hour, minute, second);
      return dt.millisecondsSinceEpoch / 1000;
    } catch (e) {
      return null;
    }
  }

  static String generateSecMsGec() {
    var ticks = getUnixTimestamp();
    ticks += winEpoch;
    ticks -= ticks % 300;
    ticks *= sToNs / 100;
    
    final strToHash = "${ticks.toStringAsFixed(0)}${Constants.trustedClientToken}";
    final bytes = utf8.encode(strToHash);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  static String generateMuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static Map<String, String> headersWithMuid(Map<String, String> headers) {
    final combinedHeaders = Map<String, String>.from(headers);
    if (!combinedHeaders.containsKey("Cookie")) {
      combinedHeaders["Cookie"] = "muid=${generateMuid()};";
    }
    return combinedHeaders;
  }
}
