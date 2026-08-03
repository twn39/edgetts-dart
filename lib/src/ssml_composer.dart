import 'data_classes.dart';
import 'util.dart';

/// Utility class for composing WebSocket command and SSML request payloads.
class SSMLComposer {
  /// Build the `speech.config` JSON request payload.
  static String buildCommandConfig(TTSConfig config) {
    final wordBoundary = config.boundary == 'WordBoundary';
    final wd = wordBoundary ? 'true' : 'false';
    final sq = wordBoundary ? 'false' : 'true';

    return 'X-Timestamp:${EdgeTTSUtil.dateToString()}\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{'
        '"sentenceBoundaryEnabled":"$sq","wordBoundaryEnabled":"$wd"'
        '},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n';
  }

  /// Build the `ssml` XML request payload.
  static String buildSsmlRequest(
      String connectId, TTSConfig config, String partialText) {
    final ssml = EdgeTTSUtil.mkssml(config, partialText);
    return 'X-RequestId:$connectId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${EdgeTTSUtil.dateToString()}Z\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml';
  }
}
