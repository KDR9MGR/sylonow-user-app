import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sylonow_user/features/booking/controllers/booking_controller.dart';
import '../providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../booking/providers/booking_providers.dart';
import '../../address/providers/address_providers.dart' hide selectedAddressProvider;
import '../../home/screens/main_screen.dart';
import '../../../core/providers/welcome_providers.dart';

class LogoutService {
  static Future<void> clearAllProviders(WidgetRef ref) async {
    try {
      // Reset bottom navigation to home screen (index 0)
      ref.read(currentIndexProvider.notifier).state = 0;

      // Clear authentication providers
      ref.invalidate(currentUserProvider);
      ref.invalidate(isAuthenticatedProvider);
      ref.invalidate(authControllerProvider);

      // Clear profile providers
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(profileControllerProvider);

      // Clear booking providers
      ref.invalidate(userBookingsProvider);
      ref.invalidate(bookingControllerProvider);
      ref.invalidate(bookingCreationProvider);
      ref.invalidate(razorpayPaymentProvider);
      ref.invalidate(sylonowQrPaymentProvider);
      ref.invalidate(bookingStatusProvider);

      // Clear address providers
      ref.invalidate(addressesProvider);
      ref.invalidate(selectedAddressProvider);

      // Clear welcome preferences (celebration date/time from SharedPreferences)
      try {
        final welcomeService = ref.read(welcomePreferencesServiceProvider);
        await welcomeService.clearAllPreferences();
        //('✅ Welcome preferences cleared successfully');
      } catch (e) {
        //('⚠️ Error clearing welcome preferences: $e');
      }

      //('All providers cleared successfully');
    } catch (e) {
      //('Error clearing providers: $e');
      // Don't rethrow as this is not critical
    }
  }
  
  static Future<void> performCompleteLogout(WidgetRef ref) async {
    try {
      // First clear all providers
      await clearAllProviders(ref);
      
      // Then perform auth logout
      await ref.read(authControllerProvider.notifier).signOut();
      
      // Final cleanup
      await clearAllProviders(ref);
      
      //('Complete logout performed successfully');
    } catch (e) {
      //('Error during complete logout: $e');
      rethrow;
    }
  }
}