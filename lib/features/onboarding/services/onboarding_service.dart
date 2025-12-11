import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/onboarding_constants.dart';
import '../models/onboarding_data_model.dart';
import '../../auth/services/auth_service.dart';

class OnboardingService {
  final AuthService _authService;
  static const String _onboardingDataKey = OnboardingConstants.onboardingDataKey;
  static const String _onboardingCompletedKey = OnboardingConstants.onboardingCompletedKey;

  OnboardingService(this._authService);

  Future<bool> isOnboardingCompleted() async {
    // In debug mode, always show onboarding for testing
    if (kDebugMode) {
      return false;
    }
    
    // Check onboarding completion from user_profiles table
    return await _authService.isOnboardingCompleted();
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  Future<OnboardingDataModel> getOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_onboardingDataKey);
    
    if (jsonString != null) {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return OnboardingDataModel.fromJson(jsonMap);
    }
    
    return const OnboardingDataModel();
  }

  Future<void> saveOnboardingData(OnboardingDataModel data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(data.toJson());
    await prefs.setString(_onboardingDataKey, jsonString);
  }

  Future<void> updateUserName(String userName) async {
    final currentData = await getOnboardingData();
    final updatedData = currentData.copyWith(userName: userName);
    await saveOnboardingData(updatedData);
    
    // Also save to database immediately
    try {
      // Get current user's phone if available
      final currentUser = _authService.getCurrentUser();
      String? userPhone;
      if (currentUser?.phone != null) {
        userPhone = currentUser!.phone!;
      }
      
      await _authService.saveOnboardingData(
        userName: userName,
        phoneNumber: userPhone,
      );
    } catch (e) {
      //('Failed to save userName to database: $e');
      // Don't throw - keep local data intact
    }
  }

  Future<void> updateOccasion(String occasion) async {
    final currentData = await getOnboardingData();
    final updatedData = currentData.copyWith(selectedOccasion: occasion);
    await saveOnboardingData(updatedData);
  }

  Future<void> updateOccasionWithId(String occasionId, String occasionName) async {
    final currentData = await getOnboardingData();
    final updatedData = currentData.copyWith(
      selectedOccasion: occasionName,
      selectedOccasionId: occasionId,
    );
    await saveOnboardingData(updatedData);
    
    // Also save to database immediately
    try {
      // Get current user's phone if available
      final currentUser = _authService.getCurrentUser();
      String? userPhone;
      if (currentUser?.phone != null) {
        userPhone = currentUser!.phone!;
      }
      
      await _authService.saveOnboardingData(
        selectedOccasion: occasionName,
        selectedOccasionId: occasionId,
        phoneNumber: userPhone,
      );
    } catch (e) {
      //('Failed to save occasion to database: $e');
      // Don't throw - keep local data intact
    }
  }

  Future<void> updateCelebrationDate(String date) async {
    final currentData = await getOnboardingData();
    final updatedData = currentData.copyWith(celebrationDate: date);
    await saveOnboardingData(updatedData);
    
    // Also save to database immediately
    try {
      // Get current user's phone if available
      final currentUser = _authService.getCurrentUser();
      String? userPhone;
      if (currentUser?.phone != null) {
        userPhone = currentUser!.phone!;
      }
      
      await _authService.saveOnboardingData(
        celebrationDate: date,
        selectedOccasionId: currentData.selectedOccasionId, // Preserve existing category_id
        phoneNumber: userPhone,
      );
    } catch (e) {
      //('Failed to save celebration date to database: $e');
      // Don't throw - keep local data intact
    }
  }

  Future<void> updateCelebrationTime(String time) async {
    final currentData = await getOnboardingData();
    final updatedData = currentData.copyWith(celebrationTime: time);
    await saveOnboardingData(updatedData);
    
    // Also save to database immediately
    try {
      // Get current user's phone if available
      final currentUser = _authService.getCurrentUser();
      String? userPhone;
      if (currentUser?.phone != null) {
        userPhone = currentUser!.phone!;
      }
      
      await _authService.saveOnboardingData(
        celebrationTime: time,
        selectedOccasionId: currentData.selectedOccasionId, // Preserve existing category_id
        phoneNumber: userPhone,
      );
    } catch (e) {
      //('Failed to save celebration time to database: $e');
      // Don't throw - keep local data intact
    }
  }

  Future<void> completeOnboarding() async {
    final currentData = await getOnboardingData();
    final completedData = currentData.copyWith(isCompleted: true);
    await saveOnboardingData(completedData);
    
    // Mark onboarding as completed in user_profiles table
    await _authService.completeOnboarding();
    
    // Also keep local preference for backward compatibility
    await setOnboardingCompleted(true);
  }

  Future<void> clearOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingDataKey);
    await prefs.remove(_onboardingCompletedKey);
  }

  /// Debug method to reset onboarding data for testing
  Future<void> resetOnboardingForDebug() async {
    if (kDebugMode) {
      await clearOnboardingData();
    }
  }
}