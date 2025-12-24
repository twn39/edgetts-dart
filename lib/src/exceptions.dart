class EdgeTTSException implements Exception {
  final String message;
  EdgeTTSException(this.message);

  @override
  String toString() => "EdgeTTSException: $message";
}

class NoAudioReceived extends EdgeTTSException {
  NoAudioReceived(String message) : super(message);
}

class UnexpectedResponse extends EdgeTTSException {
  UnexpectedResponse(String message) : super(message);
}

class UnknownResponse extends EdgeTTSException {
  UnknownResponse(String message) : super(message);
}

class WebSocketError extends EdgeTTSException {
  WebSocketError(String message) : super(message);
}

class SkewAdjustmentError extends EdgeTTSException {
  SkewAdjustmentError(String message) : super(message);
}
