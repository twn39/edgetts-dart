import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'drm.dart';
import 'data_classes.dart';

Future<List<Voice>> listVoices({http.Client? client, String? proxy}) async {
  // Proxy support in Dart http is not direct unless using IOClient with custom HttpClient.
  // We will ignore proxy for now or let user pass a custom client.

  final httpClient = client ?? http.Client();

  try {
    final secMsGec = DRM.generateSecMsGec();
    final url =
        "${Constants.voiceList}&Sec-MS-GEC=$secMsGec&Sec-MS-GEC-Version=${Constants.secMsGecVersion}";
    final headers = DRM.headersWithMuid(Constants.voiceHeaders);

    final response = await httpClient.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Voice.fromJson(json)).toList();
    } else {
      // Handle error, maybe clock skew?
      // Python: DRM.handle_client_response_error(e)
      // If 403, it might be clock skew.

      /*
        except aiohttp.ClientResponseError as e:
            if e.status != 403:
                raise

            DRM.handle_client_response_error(e)
            data = await __list_voices(session, ssl_ctx, proxy)
        */

      if (response.statusCode == 403) {
        final dateHeader = response.headers['date'];
        if (dateHeader != null) {
          final serverDate = DRM.parseRfc2616Date(dateHeader);
          if (serverDate != null) {
            final clientDate = DRM.getUnixTimestamp();
            DRM.adjClockSkewSeconds(serverDate - clientDate);

            // Retry
            final retrySecMsGec = DRM.generateSecMsGec();
            final retryUrl =
                "${Constants.voiceList}&Sec-MS-GEC=$retrySecMsGec&Sec-MS-GEC-Version=${Constants.secMsGecVersion}";
            final retryResponse =
                await httpClient.get(Uri.parse(retryUrl), headers: headers);
            if (retryResponse.statusCode == 200) {
              final List<dynamic> data = jsonDecode(retryResponse.body);
              return data.map((json) => Voice.fromJson(json)).toList();
            }
          }
        }
      }

      throw Exception(
          "Failed to list voices: ${response.statusCode} ${response.body}");
    }
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}
