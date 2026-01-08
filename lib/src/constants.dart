class Constants {
  static const String baseUrl =
      "speech.platform.bing.com/consumer/speech/synthesize/readaloud";
  static const String trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";

  static const String wssUrl =
      "wss://$baseUrl/edge/v1?TrustedClientToken=$trustedClientToken";
  static const String voiceList =
      "https://$baseUrl/voices/list?trustedclienttoken=$trustedClientToken";

  static const String defaultVoice = "en-US-EmmaMultilingualNeural";

  static const String chromiumFullVersion = "143.0.3650.75";
  static String get chromiumMajorVersion => chromiumFullVersion.split(".")[0];
  static String get secMsGecVersion => "1-$chromiumFullVersion";

  static Map<String, String> get baseHeaders => {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromiumMajorVersion.0.0.0 Safari/537.36 Edg/$chromiumMajorVersion.0.0.0",
        "Accept-Encoding": "gzip, deflate, br, zstd",
        "Accept-Language": "en-US,en;q=0.9",
      };

  static Map<String, String> get wssHeaders {
    final headers = {
      "Pragma": "no-cache",
      "Cache-Control": "no-cache",
      "Origin": "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold",
      "Sec-WebSocket-Version": "13",
    };
    headers.addAll(baseHeaders);
    return headers;
  }

  static Map<String, String> get voiceHeaders {
    final headers = {
      "Authority": "speech.platform.bing.com",
      "Sec-CH-UA":
          '" Not;A Brand";v="99", "Microsoft Edge";v="$chromiumMajorVersion", "Chromium";v="$chromiumMajorVersion"',
      "Sec-CH-UA-Mobile": "?0",
      "Accept": "*/*",
      "Sec-Fetch-Site": "none",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
    };
    headers.addAll(baseHeaders);
    return headers;
  }
}
