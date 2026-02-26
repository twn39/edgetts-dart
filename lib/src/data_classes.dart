import 'constants.dart';

class TTSConfig {
  String voice;
  final String rate;
  final String volume;
  final String pitch;
  final String boundary;

  // Compile-once regex patterns for validation
  static final _ratePattern = RegExp(r'^[+-]\d+%$');
  static final _volumePattern = RegExp(r'^[+-]\d+%$');
  static final _pitchPattern = RegExp(r'^[+-]\d+Hz$');
  static final _voiceShortPattern =
      RegExp(r'^([a-z]{2,})-([A-Z]{2,})-(.+Neural)$');
  static final _voiceLongPattern =
      RegExp(r'^Microsoft Server Speech Text to Speech Voice \(.+,.+\)$');

  TTSConfig({
    String? voice,
    this.rate = '+0%',
    this.volume = '+0%',
    this.pitch = '+0Hz',
    this.boundary = 'SentenceBoundary',
  }) : voice = voice ?? Constants.defaultVoice {
    _validate();
  }

  void _validate() {
    if (!_ratePattern.hasMatch(rate)) {
      throw ArgumentError("Invalid rate '$rate'.");
    }
    if (!_volumePattern.hasMatch(volume)) {
      throw ArgumentError("Invalid volume '$volume'.");
    }
    if (!_pitchPattern.hasMatch(pitch)) {
      throw ArgumentError("Invalid pitch '$pitch'.");
    }
    if (boundary != 'WordBoundary' && boundary != 'SentenceBoundary') {
      throw ArgumentError(
          "Invalid boundary '$boundary'. Must be 'WordBoundary' or 'SentenceBoundary'.");
    }

    // Convert short voice name to full Microsoft format
    // e.g. "en-US-AriaNeural" -> "Microsoft Server Speech Text to Speech Voice (en-US, AriaNeural)"
    final match = _voiceShortPattern.firstMatch(voice);
    if (match != null) {
      final lang = match.group(1)!;
      var region = match.group(2)!;
      var name = match.group(3)!;

      if (name.contains('-')) {
        region = '$region-${name.substring(0, name.indexOf('-'))}';
        name = name.substring(name.indexOf('-') + 1);
      }

      voice =
          'Microsoft Server Speech Text to Speech Voice ($lang-$region, $name)';
    }

    // Validate the final voice format
    if (!_voiceLongPattern.hasMatch(voice)) {
      throw ArgumentError("Invalid voice '$voice'.");
    }
  }
}

class Voice {
  final String name;
  final String shortName;
  final String gender;
  final String locale;
  final String suggestedCodec;
  final String friendlyName;
  final String status;
  final Map<String, dynamic> voiceTag;

  Voice({
    required this.name,
    required this.shortName,
    required this.gender,
    required this.locale,
    required this.suggestedCodec,
    required this.friendlyName,
    required this.status,
    required this.voiceTag,
  });

  factory Voice.fromJson(Map<String, dynamic> json) {
    final rawTag = json['VoiceTag'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final tag = Map<String, dynamic>.from(rawTag);
    tag.putIfAbsent('ContentCategories', () => <dynamic>[]);
    tag.putIfAbsent('VoicePersonalities', () => <dynamic>[]);

    return Voice(
      name: json['Name'] ?? '',
      shortName: json['ShortName'] ?? '',
      gender: json['Gender'] ?? '',
      locale: json['Locale'] ?? '',
      suggestedCodec: json['SuggestedCodec'] ?? '',
      friendlyName: json['FriendlyName'] ?? '',
      status: json['Status'] ?? '',
      voiceTag: tag,
    );
  }
}

class TTSChunk {
  final String type; // "audio", "WordBoundary", "SentenceBoundary"
  final List<int>? audioData;
  final Metadata? metadata;

  const TTSChunk({required this.type, this.audioData, this.metadata});
}

class Metadata {
  final String type;
  final double offset;
  final double duration;
  final String text;

  const Metadata({
    required this.type,
    required this.offset,
    required this.duration,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'offset': offset,
        'duration': duration,
        'text': text,
      };
}
