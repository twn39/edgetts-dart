import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'constants.dart';
import 'drm.dart';
import 'util.dart';

/// Centralized HTTP client manager with proxy support and DRM clock skew correction.
class EdgeHttpClient {
  /// Create an [http.Client] configured with native proxy settings.
  static http.Client createClient({String? proxy}) {
    final ioClient = HttpClient();
    if (proxy != null && proxy.trim().isNotEmpty) {
      final formattedProxy = EdgeTTSUtil.formatProxy(proxy);
      ioClient.findProxy = (uri) => formattedProxy;
    }
    return IOClient(ioClient);
  }

  /// Perform a GET request with DRM headers and automatic 403 clock-skew synchronization retry.
  static Future<http.Response> getWithRetry(
    http.Client client,
    String url, {
    Map<String, String>? baseHeaders,
  }) async {
    final headers = DRM.headersWithMuid(baseHeaders ?? Constants.voiceHeaders);
    final uri = Uri.parse(url);

    try {
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 403) {
        await syncClock(client, headers: headers);
        final retriedHeaders =
            DRM.headersWithMuid(baseHeaders ?? Constants.voiceHeaders);
        return await client.get(uri, headers: retriedHeaders);
      }
      return response;
    } on http.ClientException catch (e) {
      if (!e.message.contains('403')) rethrow;
      await syncClock(client, headers: headers);
      final retriedHeaders =
          DRM.headersWithMuid(baseHeaders ?? Constants.voiceHeaders);
      return await client.get(uri, headers: retriedHeaders);
    }
  }

  /// Sync client-server clock skew by fetching HTTP Date headers.
  static Future<void> syncClock(
    http.Client client, {
    Map<String, String>? headers,
  }) async {
    try {
      final reqHeaders = headers ?? DRM.headersWithMuid(Constants.wssHeaders);
      final syncResponse = await client.get(
        Uri.parse(Constants.voiceList),
        headers: reqHeaders,
      );
      DRM.handleClientResponseError(
        syncResponse.statusCode,
        syncResponse.headers,
      );
    } catch (_) {
      // Ignore sync failures during clock adjustment
    }
  }
}
