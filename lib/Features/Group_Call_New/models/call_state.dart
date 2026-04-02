/// Represents the current state of a group call.
enum GroupCallState {
  idle,
  preparing,
  connecting,
  connected,
  reconnecting,
  error,
  left,
}

/// Represents the audio output route.
enum AudioOutputRoute {
  speaker,
  earpiece,
  bluetooth,
}
