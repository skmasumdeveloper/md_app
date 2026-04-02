part of 'group_call.dart';

extension GroupCallAudioExtension on GroupcallController {
  // Invoke iOS native speaker mode.
  Future<void> setSpeakerMode(bool speakerOn) async {
    debugPrint('[Audio] setSpeakerMode: speakerOn=$speakerOn');
    try {
      await PlatformChannels.iosaudioplatform.invokeMethod('setSpeakerMode', {
        'speakerOn': speakerOn,
      });
      debugPrint('[Audio] setSpeakerMode: ✓ done');
    } catch (e) {
      debugPrint('[Audio] setSpeakerMode: error: $e');
    }
  }

  // Configure audio session — call once at controller init.
  Future<void> configureAudioSession() async {
    debugPrint('[Audio] configureAudioSession: starting...');
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
    debugPrint('[Audio] configureAudioSession: ✓ configured');
  }

  /// Activate the audio session BEFORE producing tracks.
  /// On iOS this is critical — if the session isn't active when WebRTC
  /// starts sending, audio tracks are silenced.
  Future<void> activateAudioSession() async {
    debugPrint('[Audio] activateAudioSession: activating...');
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      debugPrint('[Audio] activateAudioSession: ✓ audio session activated');
    } catch (e) {
      debugPrint('[Audio] activateAudioSession: ✗ FAILED: $e');
    }
  }

  /// Deactivate the audio session when leaving a call.
  Future<void> deactivateAudioSession() async {
    debugPrint('[Audio] deactivateAudioSession: deactivating...');
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
      debugPrint('[Audio] deactivateAudioSession: ✓ audio session deactivated');
    } catch (e) {
      debugPrint('[Audio] deactivateAudioSession: ✗ FAILED: $e');
    }
  }

  void toggleSpeaker() async {
    debugPrint('[Audio] toggleSpeaker: current=${isSpeakerOn.value}');
    isSpeakerOn.value = !isSpeakerOn.value;
    await setAudioToSpeaker(isSpeakerOn.value);
    debugPrint('[Audio] toggleSpeaker: new=${isSpeakerOn.value}');
  }

  Future<void> setAudioToSpeaker([bool speakerOn = true]) async {
    debugPrint('[Audio] setAudioToSpeaker: speakerOn=$speakerOn');
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
      await setSpeakerMode(speakerOn);
      debugPrint('[Audio] setAudioToSpeaker: ✓ done');
    } catch (e) {
      debugPrint('[Audio] setAudioToSpeaker: error: $e');
    }
  }
}
