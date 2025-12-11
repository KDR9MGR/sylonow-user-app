import 'package:flutter/foundation.dart';

class Logger {
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final logMessage = tag != null ? '[$tag] $message' : message;
      //('ℹ️ $logMessage');
    }
  }

  static void error(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final logMessage = tag != null ? '[$tag] $message' : message;
      //('❌ $logMessage');
      if (error != null) {
        //('Error details: $error');
      }
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final logMessage = tag != null ? '[$tag] $message' : message;
      //('⚠️ $logMessage');
    }
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final logMessage = tag != null ? '[$tag] $message' : message;
      //('🔍 $logMessage');
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      final logMessage = tag != null ? '[$tag] $message' : message;
      //('✅ $logMessage');
    }
  }
}