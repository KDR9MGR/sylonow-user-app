import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class LogoutTestService {
  static Future<Map<String, dynamic>> testLogoutState() async {
    final testResults = <String, dynamic>{};
    
    try {
      // Test 1: Check Supabase session
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;
      
      testResults['supabase_session_cleared'] = session == null;
      testResults['supabase_user_cleared'] = user == null;
      
      // Test 2: Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final authKeys = keys.where((key) => 
        key.contains('isLoggedIn') ||
        key.contains('userEmail') ||
        key.contains('userId') ||
        key.contains('userPhone')
      ).toList();
      
      final appDataKeys = keys.where((key) => 
        key.startsWith('sylonow_') ||
        key.startsWith('user_') ||
        key.startsWith('profile_') ||
        key.startsWith('address_') ||
        key.startsWith('booking_') ||
        key.startsWith('notification_')
      ).toList();
      
      testResults['auth_keys_cleared'] = authKeys.isEmpty;
      testResults['app_data_keys_cleared'] = appDataKeys.isEmpty;
      testResults['remaining_auth_keys'] = authKeys;
      testResults['remaining_app_data_keys'] = appDataKeys;
      
      // Test 3: Check cache state
      final cacheManager = DefaultCacheManager();
      final cacheKeys = await cacheManager.getFileStream('test_key').isEmpty;
      
      testResults['cache_cleared'] = cacheKeys;
      
      // Test 4: Overall logout success
      testResults['logout_successful'] = 
        testResults['supabase_session_cleared'] == true &&
        testResults['supabase_user_cleared'] == true &&
        testResults['auth_keys_cleared'] == true &&
        testResults['app_data_keys_cleared'] == true;
      
      // Test 5: Specific key checks
      testResults['is_logged_in_key'] = prefs.getBool('isLoggedIn') ?? false;
      testResults['user_email_key'] = prefs.getString('userEmail');
      testResults['user_id_key'] = prefs.getString('userId');
      testResults['user_phone_key'] = prefs.getString('userPhone');
      
      //('Logout test results: $testResults');
      
    } catch (e) {
      testResults['error'] = e.toString();
      //('Error during logout test: $e');
    }
    
    return testResults;
  }
  
  static Future<void> printLogoutState() async {
    final results = await testLogoutState();
    
    //('=== LOGOUT STATE TEST RESULTS ===');
    //('Supabase Session Cleared: ${results['supabase_session_cleared']}');
    //('Supabase User Cleared: ${results['supabase_user_cleared']}');
    //('Auth Keys Cleared: ${results['auth_keys_cleared']}');
    //('App Data Keys Cleared: ${results['app_data_keys_cleared']}');
    //('Cache Cleared: ${results['cache_cleared']}');
    //('Logout Successful: ${results['logout_successful']}');
    
    if (results['remaining_auth_keys'] != null && 
        (results['remaining_auth_keys'] as List).isNotEmpty) {
      //('Remaining Auth Keys: ${results['remaining_auth_keys']}');
    }
    
    if (results['remaining_app_data_keys'] != null && 
        (results['remaining_app_data_keys'] as List).isNotEmpty) {
      //('Remaining App Data Keys: ${results['remaining_app_data_keys']}');
    }
    
    if (results['error'] != null) {
      //('Error: ${results['error']}');
    }
    
    //('=== END LOGOUT STATE TEST ===');
  }
}