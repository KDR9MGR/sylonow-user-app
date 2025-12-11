import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AccountDeletionService {
  final SupabaseClient _supabaseClient;

  AccountDeletionService(this._supabaseClient);

  /// Send OTP to user's email for account deletion verification
  Future<bool> sendDeletionOTP(String email) async {
    try {
      // Using Supabase Auth OTP for email verification
      await _supabaseClient.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Don't create user if doesn't exist
        data: {
          'type': 'account_deletion',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      //('Error sending deletion OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP and proceed with account deletion
  Future<bool> verifyOTPAndDeleteAccount({
    required String email,
    required String otp,
  }) async {
    try {
      // Verify the OTP
      final response = await _supabaseClient.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: otp,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP');
      }

      // If OTP is valid, proceed with account deletion
      await _deleteUserAccount(response.user!.id);

      return true;
    } catch (e) {
      //('Error verifying OTP and deleting account: $e');
      rethrow;
    }
  }

  /// Delete user account and all associated data
  Future<void> _deleteUserAccount(String userId) async {
    try {
      // 1. Delete user profile data from profiles table
      await _supabaseClient
          .from('profiles')
          .delete()
          .eq('id', userId);

      // 2. Delete user's bookings
      await _supabaseClient
          .from('bookings')
          .delete()
          .eq('user_id', userId);

      // 3. Delete user's quotes
      await _supabaseClient
          .from('quotes')
          .delete()
          .eq('user_id', userId);

      // 4. Delete user's addresses
      await _supabaseClient
          .from('user_addresses')
          .delete()
          .eq('user_id', userId);

      // 5. Delete user's wallet transactions
      await _supabaseClient
          .from('wallet_transactions')
          .delete()
          .eq('user_id', userId);

      // 6. Delete user's notification preferences
      await _supabaseClient
          .from('notification_preferences')
          .delete()
          .eq('user_id', userId);

      // 7. Finally, delete the user from Supabase Auth
      // Note: This requires admin privileges, so we'll call a database function
      await _supabaseClient.rpc('delete_user_account', params: {
        'user_id': userId,
      });

      // 8. Clear local data
      await _clearLocalData();

      //('Account successfully deleted for user: $userId');
    } catch (e) {
      //('Error deleting user account: $e');
      rethrow;
    }
  }

  /// Clear all local application data
  Future<void> _clearLocalData() async {
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear cached network images
      await CachedNetworkImage.evictFromCache('*');
      await DefaultCacheManager().emptyCache();

      //('Local data cleared successfully');
    } catch (e) {
      //('Error clearing local data: $e');
      // Don't rethrow here as local data clearing is not critical
    }
  }

  /// Get user's current email from Supabase Auth
  String? getCurrentUserEmail() {
    return _supabaseClient.auth.currentUser?.email;
  }
}