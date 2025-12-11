import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';

class ProfileController extends StateNotifier<AsyncValue<UserProfileModel?>> {
  final ProfileService _profileService;

  ProfileController(this._profileService) : super(const AsyncValue.loading()) {
    loadCurrentUserProfile();
  }

  /// Load current user profile
  Future<void> loadCurrentUserProfile() async {
    try {
      state = const AsyncValue.loading();
      final profile = await _profileService.getCurrentUserProfile();
      
      if (profile == null) {
        state = AsyncValue.error(
          'No user profile found. Please sign in again.',
          StackTrace.current,
        );
        return;
      }
      
      state = AsyncValue.data(profile);
    } catch (e, stackTrace) {
      //('Error loading user profile: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update user profile
  Future<bool> updateProfile(UserProfileModel profile) async {
    try {
      // Validate profile data
      final validationError = _profileService.validateProfile(profile);
      if (validationError != null) {
        state = AsyncValue.error(validationError, StackTrace.current);
        return false;
      }

      state = const AsyncValue.loading();
      final updatedProfile = await _profileService.updateProfile(profile);
      state = AsyncValue.data(updatedProfile);
      return true;
    } catch (e, stackTrace) {
      //('Error updating profile: $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Update profile image
  Future<bool> updateProfileImage(File imageFile) async {
    try {
      if (state.value == null) {
        state = AsyncValue.error('No profile loaded', StackTrace.current);
        return false;
      }

      state = const AsyncValue.loading();
      final updatedProfile = await _profileService.updateProfileImage(state.value!, imageFile);
      state = AsyncValue.data(updatedProfile);
      return true;
    } catch (e, stackTrace) {
      //('Error updating profile image: $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Remove profile image
  Future<bool> removeProfileImage() async {
    try {
      if (state.value == null) {
        state = AsyncValue.error('No profile loaded', StackTrace.current);
        return false;
      }

      state = const AsyncValue.loading();
      final updatedProfile = await _profileService.removeProfileImage(state.value!);
      state = AsyncValue.data(updatedProfile);
      return true;
    } catch (e, stackTrace) {
      //('Error removing profile image: $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Refresh profile data
  Future<void> refresh() async {
    await loadCurrentUserProfile();
  }

  /// Get current profile synchronously
  UserProfileModel? get currentProfile => state.valueOrNull;

  /// Check if profile is loaded
  bool get isLoaded => state.hasValue && !state.isLoading;

  /// Check if profile has error
  bool get hasError => state.hasError;

  /// Get error message
  String? get errorMessage => state.hasError ? state.error.toString() : null;
}