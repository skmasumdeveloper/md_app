import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call_state.dart';
import 'call_logger.dart';

/// Manages audio session, output routing (speaker, earpiece, bluetooth),
/// and audio interruption handling for calls.
class AudioManager {
  static const String _scope = 'AudioMgr';

  AudioOutputRoute _currentRoute = AudioOutputRoute.speaker;

  AudioOutputRoute get currentRoute => _currentRoute;

  /// Configure audio session for voice call.
  Future<void> configure() async {
    CallLogger.info(_scope, 'configure');
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowBluetoothA2dp |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // Listen for audio interruptions (incoming phone calls, etc.)
      session.interruptionEventStream.listen((event) {
        CallLogger.info(_scope, 'audioInterruption', {
          'begin': event.begin.toString(),
          'type': event.type.toString(),
        });
      });

      // Listen for audio route changes (bluetooth connect/disconnect)
      session.devicesChangedEventStream.listen((event) {
        CallLogger.info(_scope, 'devicesChanged', {
          'added': event.devicesAdded.map((d) => d.name).toList().toString(),
          'removed':
              event.devicesRemoved.map((d) => d.name).toList().toString(),
        });
      });

      CallLogger.info(_scope, 'configure:done');
    } catch (e) {
      CallLogger.error(_scope, 'configure:error', {'error': e.toString()});
    }
  }

  /// Activate the audio session (call starting).
  Future<void> activate() async {
    CallLogger.info(_scope, 'activate');
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      CallLogger.error(_scope, 'activate:error', {'error': e.toString()});
    }
  }

  /// Deactivate the audio session (call ended).
  Future<void> deactivate() async {
    CallLogger.info(_scope, 'deactivate');
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      CallLogger.error(_scope, 'deactivate:error', {'error': e.toString()});
    }
  }

  /// Set audio output to speaker.
  Future<void> setSpeaker() async {
    CallLogger.info(_scope, 'setSpeaker');
    _currentRoute = AudioOutputRoute.speaker;
    await _applySpeakerMode(true);
  }

  /// Set audio output to earpiece.
  Future<void> setEarpiece() async {
    CallLogger.info(_scope, 'setEarpiece');
    _currentRoute = AudioOutputRoute.earpiece;
    await _applySpeakerMode(false);
  }

  /// Set audio output to bluetooth (if available).
  Future<void> setBluetooth() async {
    CallLogger.info(_scope, 'setBluetooth');
    _currentRoute = AudioOutputRoute.bluetooth;
    // Bluetooth routing is handled by the OS when allowBluetooth is set
    // in the audio session config. We just need to not force speaker.
    await _applySpeakerMode(false);
  }

  /// Cycle through audio outputs: speaker -> earpiece -> bluetooth -> speaker.
  Future<AudioOutputRoute> cycleOutput() async {
    switch (_currentRoute) {
      case AudioOutputRoute.speaker:
        await setEarpiece();
        return AudioOutputRoute.earpiece;
      case AudioOutputRoute.earpiece:
        // Try bluetooth, fall back to speaker
        await setBluetooth();
        return AudioOutputRoute.bluetooth;
      case AudioOutputRoute.bluetooth:
        await setSpeaker();
        return AudioOutputRoute.speaker;
    }
  }

  /// Toggle between speaker and earpiece.
  Future<void> toggleSpeaker(bool speakerOn) async {
    if (speakerOn) {
      await setSpeaker();
    } else {
      await setEarpiece();
    }
  }

  /// Apply speaker mode using WebRTC helper and platform channel.
  Future<void> _applySpeakerMode(bool speakerOn) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (e) {
      CallLogger.error(
          _scope, '_applySpeakerMode:webrtc', {'error': e.toString()});
    }

    // iOS-specific platform channel for audio routing
    if (Platform.isIOS) {
      try {
        const channel = MethodChannel('com.cuapp.app/audiomode');
        await channel.invokeMethod('setSpeakerMode', {
          'speakerOn': speakerOn,
        });
      } catch (e) {
        CallLogger.error(
            _scope, '_applySpeakerMode:ios', {'error': e.toString()});
      }
    }
  }

  /// Dispose and reset state.
  void dispose() {
    CallLogger.info(_scope, 'dispose');
    _currentRoute = AudioOutputRoute.speaker;
  }
}
