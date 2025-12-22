import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/dashboard_widget.dart';

/// Generic state management utility for MQTT widgets
///
/// This class provides a unified way to manage local vs remote state for all widget types.
///
/// Features:
/// - Always tracks remote state (can be null if undefined/disconnected)
/// - Always provides local state for rendering
/// - Auto-sync from remote to local when remote updates
/// - Dirty state detection for UI indicators
class LocalStateTracker<T> {
  T? _remoteValue;
  T _localValue;
  Timer? _syncTimer;

  // Equality function for comparing values
  final bool Function(T, T) _equals;

  // Debug info
  final String debugTag;

  // Callback to trigger UI updates when state changes
  final VoidCallback? _onStateUpdated;

  LocalStateTracker({
    required T initialValue,
    required T? remoteValue,
    required bool Function(T, T) equals,
    this.debugTag = '',
    VoidCallback? onStateUpdated,
  }) : _localValue = initialValue,
       _remoteValue = remoteValue,
       _equals = equals,
       _onStateUpdated = onStateUpdated;

  /// Get the current local value (always use this for rendering)
  T get localValue => _localValue;

  /// Get the current remote value (can be null if undefined/disconnected)
  T? get remoteValue => _remoteValue;

  /// Check if state is dirty (remote undefined or doesn't match local)
  bool get isDirty {
    final remote = _remoteValue;
    if (remote == null) return true;
    return !_equals(_localValue, remote);
  }

  /// Update remote state (call this when MQTT messages arrive)
  void updateRemoteValue(T? newValue) {
    if (kDebugMode && debugTag.isNotEmpty) {
      debugPrint('[$debugTag] Remote value updated: $newValue');
    }
    _remoteValue = newValue;

    // Always sync local to remote if values differ
    // This ensures the UI reflects the latest confirmed remote state
    if (newValue != null && !_equals(_localValue, newValue)) {
      debugPrint('[$debugTag] Auto-syncing local to remote: $newValue');
      _localValue = newValue;
      _notifyStateUpdated();
    }
  }

  /// Update local state immediately (call this on user interactions)
  void updateLocalValue(T newValue) {
    if (kDebugMode && debugTag.isNotEmpty) {
      debugPrint('[$debugTag] Local value updated: $newValue');
    }
    _cancelSyncTimer();
    _localValue = newValue;
    _notifyStateUpdated();
  }

  /// Clear remote state (call on disconnect)
  void clearRemoteState() {
    if (kDebugMode && debugTag.isNotEmpty) {
      debugPrint('[$debugTag] Remote state cleared');
    }
    _remoteValue = null;
  }

  void _notifyStateUpdated() {
    final callback = _onStateUpdated;
    if (callback != null) {
      // Check if we're currently in a build phase
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        // We're in a build phase, use post-frame callback
        SchedulerBinding.instance.addPostFrameCallback((_) {
          callback();
        });
      } else {
        // Safe to call directly
        callback();
      }
    }
  }

  void _cancelSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Dispose resources
  void dispose() {
    _cancelSyncTimer();
  }
}

/// Extensions for common equality operations
extension DoubleEquality on LocalStateTracker<double> {
  static bool equals(double a, double b) {
    return (a - b).abs() < 0.001;
  }
}

extension StringEquality on LocalStateTracker<String> {
  static bool equals(String a, String b) {
    return a == b;
  }
}

extension MqttStateEquality on LocalStateTracker<MqttWidgetState> {
  static bool equals(MqttWidgetState a, MqttWidgetState b) {
    return a == b;
  }
}
