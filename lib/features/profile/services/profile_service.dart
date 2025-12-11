import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile_model.dart';
import '../repositories/profile_repository.dart';
import 'package:flutter/foundation.dart'; // Added for //

class ProfileService {
  final ProfileRepository _profileRepository;

  ProfileService(this._profileRepository);

  /// Get current user profile or create if doesn't exist
  Future<UserProfileModel?> getCurrentUserProfile() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return null;

    try {
      // Try to get existing profile
      UserProfileModel? profile = await _profileRepository.getUserProfile(authUser.id);
      
      // If no profile exists, create one
      profile ??= await _profileRepository.createUserProfileFromAuth(authUser);
      
      return profile;
    } catch (e) {
      //('Failed to get current user profile: $e');
      // Re-throw with a more user-friendly message
      throw 'Unable to load profile. Please try again later.';
    }
  }

  /// Update user profile
  Future<UserProfileModel> updateProfile(UserProfileModel profile) async {
    try {
      return await _profileRepository.updateUserProfile(profile);
    } catch (e) {
      //('Failed to update profile: $e');
      throw 'Unable to update profile. Please try again later.';
    }
  }

  /// Upload and update profile image
  Future<UserProfileModel> updateProfileImage(UserProfileModel profile, File imageFile) async {
    try {
      // Delete old profile image if exists
      if (profile.profileImageUrl != null) {
        await _profileRepository.deleteProfileImage(profile.authUserId, profile.profileImageUrl!);
      }

      // Upload new image
      final imageUrl = await _profileRepository.uploadProfileImage(profile.authUserId, imageFile);

      // Update profile with new image URL
      final updatedProfile = profile.copyWith(profileImageUrl: imageUrl);
      return await _profileRepository.updateUserProfile(updatedProfile);
    } catch (e) {
      //('Failed to update profile image: $e');
      throw 'Unable to update profile image. Please try again later.';
    }
  }

  /// Remove profile image
  Future<UserProfileModel> removeProfileImage(UserProfileModel profile) async {
    try {
      if (profile.profileImageUrl != null) {
        await _profileRepository.deleteProfileImage(profile.authUserId, profile.profileImageUrl!);
      }

      // Update profile to remove image URL
      final updatedProfile = profile.copyWith(profileImageUrl: null);
      return await _profileRepository.updateUserProfile(updatedProfile);
    } catch (e) {
      //('Failed to remove profile image: $e');
      throw 'Unable to remove profile image. Please try again later.';
    }
  }

  /// Validate profile data
  String? validateProfile(UserProfileModel profile) {
    if (profile.fullName?.trim().isEmpty ?? true) {
      return 'Full name is required';
    }

    if (profile.email?.trim().isEmpty ?? true) {
      return 'Email is required';
    }

    // Email validation
    final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    if (profile.email != null && !emailRegex.hasMatch(profile.email!)) {
      return 'Please enter a valid email address';
    }

    // Phone validation (if provided)
    if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) {
      final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
      if (!phoneRegex.hasMatch(profile.phoneNumber!)) {
        return 'Please enter a valid phone number';
      }
    }

    return null; // No validation errors
  }

  /// Get profile completeness percentage
  double getProfileCompleteness(UserProfileModel profile) {
    int completedFields = 0;
    const int totalFields = 8;

    if (profile.fullName?.isNotEmpty ?? false) completedFields++;
    if (profile.email?.isNotEmpty ?? false) completedFields++;
    if (profile.phoneNumber?.isNotEmpty ?? false) completedFields++;
    if (profile.dateOfBirth != null) completedFields++;
    if (profile.gender?.isNotEmpty ?? false) completedFields++;
    if (profile.profileImageUrl?.isNotEmpty ?? false) completedFields++;
    if (profile.city?.isNotEmpty ?? false) completedFields++;
    if (profile.bio?.isNotEmpty ?? false) completedFields++;

    return completedFields / totalFields;
  }
}