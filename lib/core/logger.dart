import 'package:flutter/foundation.dart';

class AppLogger {
  static void warning(String message, [Object? error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('⚠️ WARNING: $message - Error: $error');
      } else {
        debugPrint('⚠️ WARNING: $message');
      }
    }
  }

  static void error(String message, [Object? error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('❌ ERROR: $message - Error: $error');
      } else {
        debugPrint('❌ ERROR: $message');
      }
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }
}