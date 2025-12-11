import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Service to manage welcome overlay preferences and celebration date/time
class WelcomePreferencesService {
  static const String _hasShownWelcomeKey = 'has_shown_welcome_overlay';
  static const String _celebrationDateKey = 'celebration_date';
  static const String _celebrationTimeKey = 'celebration_time';
  static const String _welcomeCompletionDateKey = 'welcome_completion_date';

  /// Check if welcome overlay has been shown before
  Future<bool> hasShownWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownWelcomeKey) ?? false;
  }

  /// Mark welcome overlay as completed and store completion date
  Future<void> markWelcomeCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownWelcomeKey, true);
    await prefs.setString(_welcomeCompletionDateKey, DateTime.now().toIso8601String());
    //('✅ Welcome overlay marked as completed at ${DateTime.now()}');
  }

  /// Save celebration date and time preferences
  Future<void> saveCelebrationPreferences({
    DateTime? celebrationDate,
    TimeOfDay? celebrationTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (celebrationDate != null) {
      await prefs.setString(_celebrationDateKey, celebrationDate.toIso8601String());
      //('✅ Celebration date saved: ${DateFormat('dd MMM yyyy').format(celebrationDate)}');
    }

    if (celebrationTime != null) {
      final timeString = '${celebrationTime.hour}:${celebrationTime.minute}';
      await prefs.setString(_celebrationTimeKey, timeString);
      //('✅ Celebration time saved: $timeString');
    }

    // Force reload to ensure changes are committed and available immediately
    await prefs.reload();
    //('🔄 SharedPreferences reloaded after save');
  }

  /// Get saved celebration date
  Future<DateTime?> getCelebrationDate() async {
    final prefs = await SharedPreferences.getInstance();
    // Reload to ensure we get the latest saved values
    await prefs.reload();
    //('🔄 SharedPreferences reloaded before reading celebration date');

    final dateString = prefs.getString(_celebrationDateKey);
    if (dateString != null) {
      try {
        //('📅 Retrieved celebration date string: $dateString');
        return DateTime.parse(dateString);
      } catch (e) {
        //('Error parsing celebration date: $e');
        return null;
      }
    }
    //('⚠️ No celebration date found in SharedPreferences');
    return null;
  }

  /// Get saved celebration time
  Future<TimeOfDay?> getCelebrationTime() async {
    final prefs = await SharedPreferences.getInstance();
    // Reload to ensure we get the latest saved values
    await prefs.reload();
    //('🔄 SharedPreferences reloaded before reading celebration time');

    final timeString = prefs.getString(_celebrationTimeKey);
    if (timeString != null) {
      try {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          //('⏰ Retrieved celebration time string: $timeString');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (e) {
        //('Error parsing celebration time: $e');
        return null;
      }
    }
    //('⚠️ No celebration time found in SharedPreferences');
    return null;
  }

  /// Get welcome completion date
  Future<DateTime?> getWelcomeCompletionDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_welcomeCompletionDateKey);
    if (dateString != null) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        //('Error parsing welcome completion date: $e');
        return null;
      }
    }
    return null;
  }

  /// Get formatted celebration date string for display
  Future<String?> getFormattedCelebrationDate() async {
    final date = await getCelebrationDate();
    if (date != null) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    return null;
  }

  /// Get formatted celebration time string for display
  Future<String?> getFormattedCelebrationTime() async {
    final time = await getCelebrationTime();
    if (time != null) {
      final now = DateTime.now();
      final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      return DateFormat('hh:mm a').format(dateTime);
    }
    return null;
  }

  /// Clear all welcome preferences (for testing/reset)
  Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasShownWelcomeKey);
    await prefs.remove(_celebrationDateKey);
    await prefs.remove(_celebrationTimeKey);
    await prefs.remove(_welcomeCompletionDateKey);
    //('🧹 All welcome preferences cleared');
  }

  /// Check if celebration preferences are set
  Future<bool> hasCelebrationPreferences() async {
    final date = await getCelebrationDate();
    final time = await getCelebrationTime();
    return date != null || time != null;
  }

  /// Get celebration preferences summary for display
  Future<Map<String, String?>> getCelebrationPreferencesSummary() async {
    return {
      'date': await getFormattedCelebrationDate(),
      'time': await getFormattedCelebrationTime(),
      'completionDate': (await getWelcomeCompletionDate())?.toString(),
    };
  }
}