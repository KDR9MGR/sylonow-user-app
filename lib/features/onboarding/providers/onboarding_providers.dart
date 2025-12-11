import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/onboarding_data_model.dart';
import '../services/onboarding_service.dart';

part 'onboarding_providers.g.dart';

@riverpod
OnboardingService onboardingService(OnboardingServiceRef ref) {
  final authService = ref.watch(authServiceProvider);
  return OnboardingService(authService);
}

@riverpod
Future<bool> isOnboardingCompleted(IsOnboardingCompletedRef ref) async {
  final service = ref.watch(onboardingServiceProvider);
  return await service.isOnboardingCompleted();
}

@riverpod
Future<OnboardingDataModel> onboardingData(OnboardingDataRef ref) async {
  final service = ref.watch(onboardingServiceProvider);
  return await service.getOnboardingData();
}

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingDataModel build() {
    return const OnboardingDataModel();
  }

  Future<void> updateUserName(String userName) async {
    final service = ref.read(onboardingServiceProvider);
    await service.updateUserName(userName);
    state = state.copyWith(userName: userName);
    ref.invalidate(onboardingDataProvider);
  }

  Future<void> updateOccasion(String occasion) async {
    final service = ref.read(onboardingServiceProvider);
    await service.updateOccasion(occasion);
    state = state.copyWith(selectedOccasion: occasion);
    ref.invalidate(onboardingDataProvider);
  }

  Future<void> updateOccasionWithId(
    String occasionId,
    String occasionName,
  ) async {
    final service = ref.read(onboardingServiceProvider);
    await service.updateOccasionWithId(occasionId, occasionName);
    state = state.copyWith(
      selectedOccasion: occasionName,
      selectedOccasionId: occasionId,
    );
    ref.invalidate(onboardingDataProvider);
  }

  Future<void> updateCelebrationDate(String date) async {
    final service = ref.read(onboardingServiceProvider);
    await service.updateCelebrationDate(date);
    state = state.copyWith(celebrationDate: date);
    ref.invalidate(onboardingDataProvider);
  }

  Future<void> updateCelebrationTime(String time) async {
    final service = ref.read(onboardingServiceProvider);
    await service.updateCelebrationTime(time);
    state = state.copyWith(celebrationTime: time);
    ref.invalidate(onboardingDataProvider);
  }

  Future<void> completeOnboarding() async {
    final service = ref.read(onboardingServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Get current user's phone if available
    final currentUser = authService.getCurrentUser();
    String? userPhone;
    if (currentUser?.phone != null) {
      userPhone = currentUser!.phone!;
    }

    await authService.saveOnboardingData(
      userName: state.userName,
      selectedOccasion: state.selectedOccasion,
      selectedOccasionId: state.selectedOccasionId,
      celebrationDate: state.celebrationDate,
      celebrationTime: state.celebrationTime,
      phoneNumber: userPhone,
    );

    await service.completeOnboarding();
    state = state.copyWith(isCompleted: true);
    ref.invalidate(isOnboardingCompletedProvider);
    ref.invalidate(onboardingDataProvider);
  }

  Future<void> loadOnboardingData() async {
    final service = ref.read(onboardingServiceProvider);
    final data = await service.getOnboardingData();
    state = data;
  }

  /// Debug method to reset onboarding for testing
  Future<void> resetForDebug() async {
    final service = ref.read(onboardingServiceProvider);
    await service.resetOnboardingForDebug();
    state = const OnboardingDataModel();
    ref.invalidate(isOnboardingCompletedProvider);
    ref.invalidate(onboardingDataProvider);
  }
}
