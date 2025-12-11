import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:crypto/crypto.dart';
import '../../../core/constants/app_constants.dart';

class AuthService {
  final SupabaseClient _supabaseClient;
  late final GoogleSignIn _googleSignIn;

  AuthService(this._supabaseClient) {
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      // This is the WEB Client ID, which is correct for Supabase integration
      serverClientId: '828054656956-9lb66n0bjgeoo7ta808ank5acj09uno7.apps.googleusercontent.com',
    );
  }

  /// Check if Sign in with Apple is available on this device
  /// Note: Apple Sign In only works on real iOS devices, not simulators
  Future<bool> isAppleSignInAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isMacOS) return false;

    // Check if running on simulator
    // Apple Sign In doesn't work on iOS Simulator
    try {
      // The isAvailable() method returns false on simulator
      final isAvailable = await SignInWithApple.isAvailable();

      if (kDebugMode && !isAvailable) {
        //('🍎 Sign in with Apple is not available on this device');
        //('🍎 Note: Apple Sign In only works on real iOS devices, not simulators');
      }

      return isAvailable;
    } catch (e) {
      if (kDebugMode) {
        //('🍎 Error checking Apple Sign In availability: $e');
      }
      return false;
    }
  }
  
  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );
      return response;
    } catch (e) {
      //('Sign up error: $e');
      rethrow;
    }
  }
  
  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.isLoggedInKey, true);
        await prefs.setString(AppConstants.userEmailKey, email);
        await prefs.setString(AppConstants.userIdKey, response.user!.id);
      }
      
      return response;
    } catch (e) {
      //('Sign in error: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Supabase
      await _supabaseClient.auth.signOut();
      
      // Sign out from Google if applicable
      await signOutFromGoogle();
      
      // Clear all local data
      await _clearAllLocalData();
      
      //('Successfully signed out');
    } catch (e) {
      //('Sign out error: $e');
      rethrow;
    }
  }
  
  // Clear all local data including SharedPreferences and cache
  Future<void> _clearAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear authentication related data
      await prefs.setBool(AppConstants.isLoggedInKey, false);
      await prefs.remove(AppConstants.userEmailKey);
      await prefs.remove(AppConstants.userIdKey);
      await prefs.remove(AppConstants.userPhoneKey);
      
      // Clear all app-specific data
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('sylonow_') || 
            key.startsWith('user_') || 
            key.startsWith('profile_') ||
            key.startsWith('address_') ||
            key.startsWith('booking_') ||
            key.startsWith('notification_')) {
          await prefs.remove(key);
        }
      }
      
      // Clear cached images
      await _clearImageCache();
      
      //('All local data cleared');
    } catch (e) {
      //('Error clearing local data: $e');
      rethrow;
    }
  }
  
  // Clear cached images
  Future<void> _clearImageCache() async {
    try {
      // Clear cached network images
      await CachedNetworkImage.evictFromCache('');
      await DefaultCacheManager().emptyCache();
      //('Image cache cleared');
    } catch (e) {
      //('Error clearing image cache: $e');
      // Don't rethrow here as this is not critical
    }
  }
  
  // Send OTP to phone number
  Future<void> sendOtpToPhone(String phoneNumber) async {
    try {
      await _supabaseClient.auth.signInWithOtp(
        phone: phoneNumber,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userPhoneKey, phoneNumber);
    } catch (e) {
      //('Send OTP error: $e');
      rethrow;
    }
  }
  
  // Verify phone OTP
  Future<AuthResponse> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _supabaseClient.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );
      
      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.isLoggedInKey, true);
        await prefs.setString(AppConstants.userPhoneKey, phoneNumber);
        await prefs.setString(AppConstants.userIdKey, response.user!.id);
      }
      
      return response;
    } catch (e) {
      //('Verify OTP error: $e');
      rethrow;
    }
  }
  
  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      // Check if there's a valid Supabase user session
      final user = _supabaseClient.auth.currentUser;
      final hasValidSession = user != null;
      
      // Also check SharedPreferences for consistency
      final prefs = await SharedPreferences.getInstance();
      final isLoggedInFromPrefs = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
      
      // If SharedPreferences says logged in but no valid session, clear the flag
      if (isLoggedInFromPrefs && !hasValidSession) {
        await prefs.setBool(AppConstants.isLoggedInKey, false);
        await prefs.remove(AppConstants.userEmailKey);
        await prefs.remove(AppConstants.userIdKey);
        await prefs.remove(AppConstants.userPhoneKey);
      }
      
      return hasValidSession;
    } catch (e) {
      //('Authentication check error: $e');
      return false;
    }
  }
  
  // Get current user
  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }
  
  /// Initiates the Google Sign-In process and authenticates with Supabase.
  /// Returns the AuthResponse from Supabase if successful, otherwise null.
  /// Now includes app type to differentiate between vendor and customer apps.
  Future<AuthResponse?> signInWithGoogle({String appType = 'customer'}) async {
    try {
      // 1. Trigger the Google Authentication flow.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If the user cancelled the sign-in, return null.
      if (googleUser == null) {
        //('🔵 Google Sign-In was cancelled by the user.');
        return null;
      }

      // 2. Obtain the authentication details from the request.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Throw an error if the ID token is missing.
      if (googleAuth.idToken == null) {
        throw 'Failed to get ID token from Google.';
      }

      // 3. Use the ID token to sign in to Supabase.
      final authResponse = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      // 🔴 NEW: Create user profile with app type after successful Google sign-in
      if (authResponse.user != null) {
        await _createUserProfile(authResponse.user!.id, appType);
        
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.isLoggedInKey, true);
        await prefs.setString(AppConstants.userEmailKey, authResponse.user!.email ?? '');
        await prefs.setString(AppConstants.userIdKey, authResponse.user!.id);
      }

      return authResponse;
    } catch (e) {
      //('Google sign in error: $e');
      rethrow;
    }
  }

  // Sign out from Google
  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) {
        //('Google sign out error: $e');
      }
    }
  }

  /// Sign in with Apple
  /// Returns the AuthResponse from Supabase if successful, otherwise null.
  Future<AuthResponse?> signInWithApple({String appType = 'customer'}) async {
    try {
      // Check if Apple Sign In is available
      final isAvailable = await isAppleSignInAvailable();
      if (!isAvailable) {
        throw 'Sign in with Apple is not available on this device';
      }

      if (kDebugMode) {
        //('🍎 Starting Apple Sign In process...');
      }

      // Generate a random nonce for security
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      if (kDebugMode) {
        //('🍎 Generated nonce for security');
      }

      // Determine clientId based on platform
      // iOS/macOS: Use App ID (com.sylonowusr.app)
      // Web: Use Services ID (com.sylonowusr)
      final clientId = kIsWeb ? 'com.sylonowusr' : 'com.sylonowusr.app';

      if (kDebugMode) {
        //('🍎 Using clientId: $clientId');
      }

      // Request credential from Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce, // Use hashed nonce for Apple request
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: clientId,
                redirectUri: Uri.parse('${AppConstants.supabaseUrl}/auth/v1/callback'),
              )
            : null,
      );

      if (kDebugMode) {
        //('🍎 Received credential from Apple');
        //('🍎 User ID: ${credential.userIdentifier}');
        //('🍎 Email: ${credential.email}');
        //('🍎 Identity Token available: ${credential.identityToken != null}');
      }

      // Check if we got the identity token
      if (credential.identityToken == null) {
        throw 'Failed to get identity token from Apple';
      }

      // Store raw nonce for backend validation (optional but recommended)
      await _storeNonce(rawNonce);

      // Sign in to Supabase with Apple ID token
      // Use raw nonce (not hashed) for Supabase
      final authResponse = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: rawNonce, // Use raw nonce for Supabase validation
      );

      if (kDebugMode) {
        //('🍎 Successfully signed in to Supabase');
        //('🍎 User ID: ${authResponse.user?.id}');
      }

      // Create user profile after successful Apple sign-in
      if (authResponse.user != null) {
        await _createUserProfile(authResponse.user!.id, appType);

        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.isLoggedInKey, true);
        await prefs.setString(AppConstants.userEmailKey, authResponse.user!.email ?? '');
        await prefs.setString(AppConstants.userIdKey, authResponse.user!.id);
      }

      return authResponse;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (kDebugMode) {
        //('🍎 Apple Sign In Authorization Error: ${e.code}');
        //('🍎 Error message: ${e.message}');
      }

      // Handle specific error codes
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          if (kDebugMode) {
            //('🍎 User canceled Apple Sign In');
          }
          return null;
        case AuthorizationErrorCode.failed:
          throw 'Apple Sign In failed. Please try again.';
        case AuthorizationErrorCode.invalidResponse:
          throw 'Invalid response from Apple. Please try again.';
        case AuthorizationErrorCode.notHandled:
          throw 'Apple Sign In not handled. Please contact support.';
        case AuthorizationErrorCode.unknown:
          throw 'An unknown error occurred with Apple Sign In (Error 1000). This may be due to:\n'
              '1. Incorrect Apple Developer configuration\n'
              '2. Missing redirect URL in Supabase\n'
              '3. Bundle ID mismatch (expecting com.sylonowusr.app)\n'
              'Please check your configuration.';
        case AuthorizationErrorCode.notInteractive:
          throw 'Apple Sign In requires user interaction.';
      }
    } on AuthApiException catch (e) {
      if (kDebugMode) {
        //('🍎 Supabase Auth API Error: ${e.statusCode}');
        //('🍎 Error message: ${e.message}');
      }

      // Handle audience mismatch error
      if (e.message.contains('audience') || e.message.contains('aud')) {
        throw 'Apple Sign In configuration error: Client ID mismatch.\n'
            'Expected: com.sylonowusr.app (iOS) or com.sylonowusr (Web)\n'
            'Please verify your Apple Developer Console settings.';
      }

      rethrow;
    } catch (e) {
      if (kDebugMode) {
        //('🍎 Apple sign in error: $e');
      }
      rethrow;
    }
  }

  /// Generate a random nonce for Apple Sign In security
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Compute SHA-256 hash of nonce
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Store nonce securely for backend validation (optional)
  Future<void> _storeNonce(String nonce) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('appleSignInNonce', nonce);
      if (kDebugMode) {
        //('🍎 Nonce stored securely');
      }
    } catch (e) {
      if (kDebugMode) {
        //('🍎 Failed to store nonce: $e');
      }
      // Non-critical, don't throw
    }
  }

  // 🔴 NEW: Helper method to create user profile with app type
  Future<void> _createUserProfile(String userId, String appType, {String? phoneNumber}) async {
    try {
      await _supabaseClient.rpc('create_user_profile', params: {
        'user_id': userId,
        'app_type': appType,
      });
      
      // If phone number is provided, update the profile with phone number
      if (phoneNumber != null) {
        await _supabaseClient
            .from('user_profiles')
            .update({'phone_number': phoneNumber})
            .eq('auth_user_id', userId);
      }
      
      //('🟢 User profile created with app type: $appType');
    } catch (e) {
      //('🔴 Failed to create user profile: $e');
      // Don't throw - this is not critical for auth flow
    }
  }

  // Enhanced phone authentication
  Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await _supabaseClient.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userPhoneKey, phoneNumber);
    } catch (e) {
      //('Phone sign in error: $e');
      rethrow;
    }
  }

  // Verify phone OTP and complete authentication
  Future<AuthResponse> verifyPhoneOtpAndSignIn({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _supabaseClient.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );
      
      if (response.user != null) {
        // Create user profile with app type after successful phone sign-in
        await _createUserProfile(response.user!.id, 'customer', phoneNumber: phoneNumber);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.isLoggedInKey, true);
        await prefs.setString(AppConstants.userPhoneKey, phoneNumber);
        await prefs.setString(AppConstants.userIdKey, response.user!.id);
      }
      
      return response;
    } catch (e) {
      //('Verify phone OTP error: $e');
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
    } catch (e) {
      //('Reset password error: $e');
      rethrow;
    }
  }
  
  // Check if user profile is complete
  Future<bool> isProfileComplete() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return false;
      
      final response = await _supabaseClient
          .from('user_profiles')
          .select('full_name, gender')
          .eq('auth_user_id', user.id)
          .single();
      
      final fullName = response['full_name'] as String?;
      final gender = response['gender'] as String?;
      
      return fullName != null && fullName.trim().isNotEmpty &&
             gender != null && gender.trim().isNotEmpty;
    } catch (e) {
      //('Profile check error: $e');
      // If profile doesn't exist or there's an error, assume it's incomplete
      return false;
    }
  }

  // Check if user has completed onboarding
  Future<bool> isOnboardingCompleted() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return false;
      
      final response = await _supabaseClient
          .from('user_profiles')
          .select('is_onboarding_completed')
          .eq('auth_user_id', user.id)
          .single();
      
      final isCompleted = response['is_onboarding_completed'] as bool?;
      
      return isCompleted ?? false;
    } catch (e) {
      //('Onboarding check error: $e');
      // If profile doesn't exist or there's an error, assume onboarding not completed
      return false;
    }
  }

  // Complete onboarding for the current user
  Future<void> completeOnboarding() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      await _supabaseClient
          .from('user_profiles')
          .update({'is_onboarding_completed': true})
          .eq('auth_user_id', user.id);
      
      //('Onboarding completed for user: ${user.id}');
    } catch (e) {
      //('Complete onboarding error: $e');
      rethrow;
    }
  }

  // Save onboarding data to user profile
  Future<void> saveOnboardingData({
    String? userName,
    String? selectedOccasion,
    String? selectedOccasionId,
    String? celebrationDate,
    String? celebrationTime,
    String? phoneNumber,
  }) async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final updateData = <String, dynamic>{};
      
      if (userName != null) updateData['full_name'] = userName;
      // Save category_id from selected occasion
      if (selectedOccasionId != null && selectedOccasionId.isNotEmpty) {
        // Validate that it's a proper UUID format (36 chars with 4 hyphens)
        final RegExp uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        if (uuidRegex.hasMatch(selectedOccasionId)) {
          updateData['category_id'] = selectedOccasionId;
        } else {
          updateData['category_id'] = null;
        }
      }
      if (celebrationDate != null) {
        // Parse ISO string to date format for database
        try {
          final parsedDate = DateTime.parse(celebrationDate);
          updateData['celebration_date'] = parsedDate.toIso8601String().split('T')[0];
        } catch (e) {
          updateData['celebration_date'] = celebrationDate;
        }
      }
      if (celebrationTime != null) updateData['celebration_time'] = celebrationTime;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      
      // Always set app_type to 'customer' for this app
      updateData['app_type'] = 'customer';
      
      if (updateData.isNotEmpty) {
        await _supabaseClient
            .from('user_profiles')
            .update(updateData)
            .eq('auth_user_id', user.id);
      }
    } catch (e) {
      //('Save onboarding data error: $e');
      rethrow;
    }
  }
  
  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return null;
      
      final response = await _supabaseClient
          .from('user_profiles')
          .select('*')
          .eq('auth_user_id', user.id)
          .single();
      
      return response;
    } catch (e) {
      //('Get user profile error: $e');
      return null;
    }
  }

  bool get isSignedIn => _supabaseClient.auth.currentUser != null;
  
  User? get currentUser => _supabaseClient.auth.currentUser;
}