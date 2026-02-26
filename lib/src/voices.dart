import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'drm.dart';
import 'data_classes.dart';

Future<List<Voice>> _listVoicesRequest(
    http.Client httpClient, Map<String, String> headers, String? proxy) async {
  final secMsGec = DRM.generateSecMsGec();
  final url =
      "${Constants.voiceList}&Sec-MS-GEC=$secMsGec&Sec-MS-GEC-Version=${Constants.secMsGecVersion}";
  final response = await httpClient.get(Uri.parse(url), headers: headers);

  if (response.statusCode != 200) {
    throw http.ClientException(
        "Failed to list voices: ${response.statusCode}", Uri.parse(url));
  }

  final List<dynamic> data = jsonDecode(response.body);

  // Ensure VoiceTag defaults are present, matching Python behavior
  for (final voice in data) {
    if (voice is Map) {
      voice['VoiceTag'] ??= {};
      (voice['VoiceTag'] as Map)['ContentCategories'] ??= [];
      (voice['VoiceTag'] as Map)['VoicePersonalities'] ??= [];
    }
  }

  return data.map((json) => Voice.fromJson(json)).toList();
}

/// List all available voices and their attributes.
Future<List<Voice>> listVoices({http.Client? client, String? proxy}) async {
  final httpClient = client ?? http.Client();

  try {
    final headers = DRM.headersWithMuid(Constants.voiceHeaders);

    try {
      return await _listVoicesRequest(httpClient, headers, proxy);
    } on http.ClientException catch (e) {
      if (!e.message.contains("403")) rethrow;

      DRM.handleClientResponseError(403, {});

      // Try to get date header via a direct request for clock skew
      try {
        final syncResponse = await httpClient.get(
          Uri.parse(Constants.voiceList),
          headers: headers,
        );
        DRM.handleClientResponseError(
            syncResponse.statusCode, syncResponse.headers);
      } catch (_) {
        // Ignore sync errors
      }

      return await _listVoicesRequest(httpClient, headers, proxy);
    }
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}

/// A class to find voices based on their attributes.
///
/// Usage:
/// ```dart
/// final manager = await VoicesManager.create();
/// final voices = manager.find(gender: 'Female', locale: 'en-US');
/// ```
class VoicesManager {
  List<VoicesManagerVoice> voices = [];
  bool _calledCreate = false;

  VoicesManager._();

  /// Creates a VoicesManager and populates it with all available voices.
  static Future<VoicesManager> create({List<Voice>? customVoices}) async {
    final manager = VoicesManager._();
    final voiceList = customVoices ?? await listVoices();

    manager.voices = voiceList.map((voice) {
      return VoicesManagerVoice.fromVoice(voice);
    }).toList();

    manager._calledCreate = true;
    return manager;
  }

  /// Find voices matching the given attributes.
  ///
  /// Supported filter keys: `gender`, `locale`, `language`.
  List<VoicesManagerVoice> find({
    String? gender,
    String? locale,
    String? language,
  }) {
    if (!_calledCreate) {
      throw StateError(
          "VoicesManager.find() called before VoicesManager.create()");
    }

    return voices.where((voice) {
      if (gender != null && voice.gender != gender) return false;
      if (locale != null && voice.locale != locale) return false;
      if (language != null && voice.language != language) return false;
      return true;
    }).toList();
  }
}

/// Extended Voice with a `language` field derived from locale.
class VoicesManagerVoice extends Voice {
  final String language;

  VoicesManagerVoice({
    required super.name,
    required super.shortName,
    required super.gender,
    required super.locale,
    required super.suggestedCodec,
    required super.friendlyName,
    required super.status,
    required super.voiceTag,
    required this.language,
  });

  factory VoicesManagerVoice.fromVoice(Voice voice) {
    return VoicesManagerVoice(
      name: voice.name,
      shortName: voice.shortName,
      gender: voice.gender,
      locale: voice.locale,
      suggestedCodec: voice.suggestedCodec,
      friendlyName: voice.friendlyName,
      status: voice.status,
      voiceTag: voice.voiceTag,
      language: voice.locale.split('-')[0],
    );
  }
}
