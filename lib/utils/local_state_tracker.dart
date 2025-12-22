import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/dashboard_widget.dart';

/// Generic state management utility for MQTT widgets
///
/// This class provides a unified way to manage local vs remote state for all widget types.
///
/// Features:
/// - Always tracks remote state (can be null if undefined/disconnected)
/// - Always provides local state for rendering
/// - Timer-based sync from local to remote state
/// - Dirty state detection for UI indicators
class LocalStateTracker<T> {
  T? _remoteValue;
  T _localValue;
  Timer? _syncTimer;
  final Duration _syncDelay;

  // Equality function for comparing values
  final bool Function(T, T) _equals;

  // Debug info
  final String debugTag;

  // Callback to trigger UI updates when state changes
  final VoidCallback? _onStateUpdated;

  LocalStateTracker({
    required T initialValue,
    required T? remoteValue,
    Duration syncDelay = const Duration(milliseconds: 500),
    required bool Function(T, T) equals,
    this.debugTag = '',
    VoidCallback? onStateUpdated,
  }) : _localValue = initialValue,
       _remoteValue = remoteValue,
       _syncDelay = syncDelay,
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
      debugPrint('[$debugTag] Remote value updated: $newValue (hasTimer: ${_syncTimer != null})');
    }
    _remoteValue = newValue;

    // Only sync local to remote if no timer is active
    // This prevents remote updates from overriding user interactions
    if (_syncTimer == null && newValue != null && !_equals(_localValue, newValue)) {
      debugPrint('[$debugTag] Auto-syncing local to remote (no timer active): $newValue');
      _localValue = newValue;
      _onStateUpdated?.call(); // Trigger UI update
    } else if (_syncTimer != null) {
      debugPrint('[$debugTag] Not syncing - timer active (user interaction in progress)');
    }
  }

  /// Update local state immediately (call this on user interactions)
  void updateLocalValue(T newValue) {
    if (kDebugMode && debugTag.isNotEmpty) {
      debugPrint('[$debugTag] Local value updated: $newValue');
    }
    _cancelSyncTimer();
    _localValue = newValue;
    _onStateUpdated?.call(); // Trigger UI update
  }

  /// Start timer to sync local state back to remote state
  void startSyncToRemote() {
    _cancelSyncTimer();
    _syncTimer = Timer(_syncDelay, () {
      if (kDebugMode && debugTag.isNotEmpty) {
        debugPrint('[$debugTag] Sync timer fired');
      }
      _syncToRemoteIfAvailable();
      _syncTimer = null;
    });
  }

  /// Cancel any pending sync
  void cancelSync() {
    _cancelSyncTimer();
  }

  /// Force immediate sync to remote value if available
  void syncToRemoteNow() {
    _syncToRemoteIfAvailable();
  }

  /// Clear remote state (call on disconnect)
  void clearRemoteState() {
    if (kDebugMode && debugTag.isNotEmpty) {
      debugPrint('[$debugTag] Remote state cleared');
    }
    _remoteValue = null;
  }

  void _syncToRemoteIfAvailable() {
    final remote = _remoteValue;
    if (remote != null) {
      if (kDebugMode && debugTag.isNotEmpty) {
        debugPrint('[$debugTag] Syncing local to remote: $remote');
      }
      _localValue = remote;
      _onStateUpdated?.call(); // Trigger UI update
    } else {
      if (kDebugMode && debugTag.isNotEmpty) {
        debugPrint('[$debugTag] No remote value available - keeping local value');
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