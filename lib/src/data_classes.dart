import 'constants.dart';

class TTSConfig {
  String voice;
  String rate;
  String volume;
  String pitch;
  String boundary; // "WordBoundary" or "SentenceBoundary"

  TTSConfig({
    String? voice,
    this.rate = "+0%",
    this.volume = "+0%",
    this.pitch = "+0Hz",
    this.boundary = "SentenceBoundary",
  }) : voice = voice ?? Constants.defaultVoice {
    _validate();
  }

  void _validate() {
    // Basic validation logic
    if (!RegExp(r"^[+-]\d+%$").hasMatch(rate)) {
      throw ArgumentError("Invalid rate '$rate'.");
    }
    if (!RegExp(r"^[+-]\d+%$").hasMatch(volume)) {
      throw ArgumentError("Invalid volume '$volume'.");
    }
    if (!RegExp(r"^[+-]\d+Hz$").hasMatch(pitch)) {
      throw ArgumentError("Invalid pitch '$pitch'.");
    }

    // Handle the voice name parsing logic akin to Python if necessary
    // match = re.match(r"^([a-z]{2,})-([A-Z]{2,})-(.+Neural)$", self.voice)
    final match =
        RegExp(r"^([a-z]{2,})-([A-Z]{2,})-(.+Neural)$").firstMatch(voice);
    if (match != null) {
      final lang = match.group(1);
      var region = match.group(2)!;
      var name = match.group(3)!;

      if (name.contains("-")) {
        region = "$region-${name.substring(0, name.indexOf('-'))}";
        name = name.substring(name.indexOf('-') + 1);
      }

      voice =
          "Microsoft Server Speech Text to Speech Voice ($lang-$region, $name)";
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
    return Voice(
      name: json['Name'],
      shortName: json['ShortName'],
      gender: json['Gender'],
      locale: json['Locale'],
      suggestedCodec: json['SuggestedCodec'],
      friendlyName: json['FriendlyName'],
      status: json['Status'],
      voiceTag: json['VoiceTag'] ?? {},
    );
  }
}

class TTSChunk {
  final String type; // "audio", "WordBoundary", "SentenceBoundary"
  // Or better typed:
  final List<int>? audioData;
  final Metadata? metadata;

  TTSChunk({required this.type, this.audioData, this.metadata});
}

class Metadata {
  final String type;
  final double offset;
  final double duration;
  final String text;

  Metadata(
      {required this.type,
      required this.offset,
      required this.duration,
      required this.text});

  factory Metadata.fromJson(Map<String, dynamic> json) {
    // Logic from communicate.py __parse_metadata
    // It receives the inner data object usually?
    // Wait, python yield parsed_metadata which is a dict.
    /*
                return {
                    "type": meta_type,
                    "offset": current_offset,
                    "duration": current_duration,
                    "text": unescape(meta_obj["Data"]["text"]["Text"]),
                }
      */
    return Metadata(
      type: json['type'],
      offset: json['offset'],
      duration: json['duration'],
      text: json['text'],
    );
  }
}
