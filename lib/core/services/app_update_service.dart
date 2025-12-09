import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if app update is available
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      debugPrint('📱 Current app version: $currentVersion');
      debugPrint('📱 Platform: $platform');

      // Fetch latest version from Supabase
      final response = await _supabase
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      debugPrint('📱 Database response: $response');

      if (response.isEmpty) {
        debugPrint('📱 No versions found in database');
        return null;
      }

      final latestVersion = response['version'] as String;
      final isForceUpdate = response['force_update'] as bool? ?? false;
      final updateMessage = response['update_message'] as String? ??
          'A new version of the app is available. Please update to continue using the app.';
      final storeUrl = response['store_url'] as String?;

      debugPrint('📱 Latest version from DB: $latestVersion');
      debugPrint('📱 Force update: $isForceUpdate');

      // Compare versions
      final shouldUpdate = _shouldUpdate(currentVersion, latestVersion);
      debugPrint('📱 Should update: $shouldUpdate');

      if (shouldUpdate) {
        return {
          'current_version': currentVersion,
          'latest_version': latestVersion,
          'force_update': isForceUpdate,
          'update_message': updateMessage,
          'store_url': storeUrl,
        };
      }

      return null;
    } catch (e) {
      debugPrint('📱 ❌ Error checking for update: $e');
      return null;
    }
  }

  /// Compare version numbers (semantic versioning)
  bool _shouldUpdate(String currentVersion, String latestVersion) {
    try {
      final current = currentVersion.split('.').map(int.parse).toList();
      final latest = latestVersion.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (current.length < 3) {
        current.add(0);
      }
      while (latest.length < 3) {
        latest.add(0);
      }

      // Compare major.minor.patch
      for (var i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }

      return false; // Versions are equal
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  /// Show update bottom sheet with beautiful UI
  Future<void> showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> updateInfo,
  ) async {
    final isForceUpdate = updateInfo['force_update'] as bool;
    final updateMessage = updateInfo['update_message'] as String;
    final storeUrl = updateInfo['store_url'] as String?;
    final latestVersion = updateInfo['latest_version'] as String;

    await showModalBottomSheet(
      context: context,
      isDismissible: !isForceUpdate,
      enableDrag: !isForceUpdate,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag indicator (only if not force update)
                  if (!isForceUpdate)
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                  // Update Icon with gradient background
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                     
                    ),
                    child: Image.asset(
                      'assets/images/app_logo_new.jpg'
                    )
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    isForceUpdate ? 'Update Required' : 'Update Available',
                    style: const TextStyle(
                      fontFamily: 'Okra',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Version badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange[50]!,
                          Colors.orange[100]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange[200]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.new_releases,
                          color: Colors.orange[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Version $latestVersion',
                          style: TextStyle(
                            fontFamily: 'Okra',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Update message
                  Text(
                    updateMessage,
                    style: const TextStyle(
                      fontFamily: 'Okra',
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      // Later button (only if not force update)
                      if (!isForceUpdate)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Later',
                              style: TextStyle(
                                fontFamily: 'Okra',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),

                      if (!isForceUpdate) const SizedBox(width: 12),

                      // Update Now button
                      Expanded(
                        flex: isForceUpdate ? 1 : 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              if (storeUrl != null) {
                                final uri = Uri.parse(storeUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Update Now',
                                  style: TextStyle(
                                    fontFamily: 'Okra',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
