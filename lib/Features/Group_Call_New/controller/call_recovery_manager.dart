import 'dart:async';

import 'call_logger.dart';

/// Manages ICE restart, reconnection, and recovery logic.
/// Prevents infinite restart loops with burst protection.
class CallRecoveryManager {
  static const String _scope = 'RecoveryMgr';

  // ICE restart burst protection
  static const int _maxBurstCount = 5;
  static const Duration _burstWindow = Duration(seconds: 20);
  static const Duration _cooldownBetweenRestarts = Duration(seconds: 4);

  Timer? _sendIceRestartTimer;
  Timer? _recvIceRestartTimer;
  Timer? _fullRecoveryTimer;

  DateTime? _lastIceRestartAt;
  DateTime? _iceRestartWindowStart;
  int _iceRestartBurstCount = 0;
  bool _isRecovering = false;

  /// Callbacks set by the controller.
  Future<void> Function(String direction)? onIceRestart;
  Future<void> Function(String reason)? onFullRecovery;

  bool get isRecovering => _isRecovering;

  /// Called when transport connection state changes.
  void onTransportStateChange(String direction, String state) {
    CallLogger.info(_scope, 'transportState', {
      'direction': direction,
      'state': state,
    });

    switch (state) {
      case 'connected':
        _clearTimerForDirection(direction);
        _iceRestartBurstCount = 0;
        _isRecovering = false;
        CallLogger.info(
            _scope, 'transport:connected:cleared', {'direction': direction});
        break;

      case 'failed':
        _scheduleIceRestart(direction, Duration.zero);
        break;

      case 'disconnected':
        _scheduleIceRestart(direction, const Duration(seconds: 8));
        break;

      case 'new':
      case 'connecting':
        // No action needed
        break;

      default:
        CallLogger.warn(
            _scope, 'unknownState', {'direction': direction, 'state': state});
    }
  }

  /// Schedule an ICE restart for a specific transport direction.
  void _scheduleIceRestart(String direction, Duration delay) {
    // Cooldown check
    if (_lastIceRestartAt != null) {
      final elapsed = DateTime.now().difference(_lastIceRestartAt!);
      if (elapsed < _cooldownBetweenRestarts) {
        CallLogger.info(_scope, 'iceRestart:cooldown', {
          'direction': direction,
          'elapsed': elapsed.inMilliseconds,
        });
        return;
      }
    }

    // Burst protection
    final now = DateTime.now();
    if (_iceRestartWindowStart == null ||
        now.difference(_iceRestartWindowStart!) > _burstWindow) {
      _iceRestartWindowStart = now;
      _iceRestartBurstCount = 0;
    }

    _iceRestartBurstCount++;
    if (_iceRestartBurstCount > _maxBurstCount) {
      CallLogger.warn(_scope, 'iceRestart:burstLimit', {
        'count': _iceRestartBurstCount,
      });
      scheduleFullRecovery('ice-flapping');
      return;
    }

    _clearTimerForDirection(direction);

    CallLogger.info(_scope, 'iceRestart:schedule', {
      'direction': direction,
      'delay': delay.inMilliseconds,
      'burstCount': _iceRestartBurstCount,
    });

    final timer = Timer(delay, () async {
      _lastIceRestartAt = DateTime.now();
      CallLogger.info(_scope, 'iceRestart:execute', {'direction': direction});
      try {
        await onIceRestart?.call(direction);
      } catch (e) {
        CallLogger.error(_scope, 'iceRestart:failed', {
          'direction': direction,
          'error': e.toString(),
        });
        scheduleFullRecovery('ice-restart-failed');
      }
    });

    if (direction == 'send') {
      _sendIceRestartTimer = timer;
    } else {
      _recvIceRestartTimer = timer;
    }
  }

  /// Schedule a full call recovery (re-init mediasoup from scratch).
  void scheduleFullRecovery(String reason, {Duration? delay}) {
    if (_isRecovering) {
      CallLogger.warn(
          _scope, 'fullRecovery:already-recovering', {'reason': reason});
      return;
    }

    final recoveryDelay = delay ?? const Duration(seconds: 3);
    CallLogger.info(_scope, 'fullRecovery:schedule', {
      'reason': reason,
      'delay': recoveryDelay.inMilliseconds,
    });

    _clearAllTimers();
    _isRecovering = true;

    _fullRecoveryTimer = Timer(recoveryDelay, () async {
      CallLogger.info(_scope, 'fullRecovery:execute', {'reason': reason});
      try {
        await onFullRecovery?.call(reason);
        _isRecovering = false;
      } catch (e) {
        CallLogger.error(_scope, 'fullRecovery:failed', {
          'reason': reason,
          'error': e.toString(),
        });
        // Retry with exponential backoff
        _isRecovering = false;
        scheduleFullRecovery(
          'retry-$reason',
          delay: Duration(seconds: recoveryDelay.inSeconds * 2),
        );
      }
    });
  }

  /// Clear timer for a specific direction.
  void _clearTimerForDirection(String direction) {
    if (direction == 'send') {
      _sendIceRestartTimer?.cancel();
      _sendIceRestartTimer = null;
    } else {
      _recvIceRestartTimer?.cancel();
      _recvIceRestartTimer = null;
    }
  }

  /// Clear all timers.
  void _clearAllTimers() {
    _sendIceRestartTimer?.cancel();
    _recvIceRestartTimer?.cancel();
    _fullRecoveryTimer?.cancel();
    _sendIceRestartTimer = null;
    _recvIceRestartTimer = null;
    _fullRecoveryTimer = null;
  }

  /// Reset all state.
  void dispose() {
    CallLogger.info(_scope, 'dispose');
    _clearAllTimers();
    _lastIceRestartAt = null;
    _iceRestartWindowStart = null;
    _iceRestartBurstCount = 0;
    _isRecovering = false;
    onIceRestart = null;
    onFullRecovery = null;
  }
}
