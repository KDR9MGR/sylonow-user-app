import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

/// Handle background messages when app is terminated or in background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    //('🔔 Background message received: ${message.messageId}');
    //('🔔 Background message title: ${message.notification?.title}');
    //('🔔 Background message body: ${message.notification?.body}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      //('🔥 Firebase initialized successfully');
    }

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Supabase
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    if (kDebugMode) {
      //('🗄️ Supabase initialized successfully');
    }

  } catch (e) {
    if (kDebugMode) {
      //('❌ Error initializing services: $e');
    }
  }
  
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  DateTime? _lastPressedAt;

  Future<bool> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Exit App',
          style: TextStyle(
            fontFamily: 'Okra',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Do you really want to exit the app?',
          style: TextStyle(
            fontFamily: 'Okra',
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Okra',
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontFamily: 'Okra',
                fontWeight: FontWeight.w600,
                color: Colors.red,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
    
    return shouldExit ?? false;
  }

  Future<bool> _handleWillPop() async {
    final now = DateTime.now();
    const maxDuration = Duration(seconds: 2);
    final isWarning = _lastPressedAt == null || 
        now.difference(_lastPressedAt!) > maxDuration;

    if (isWarning) {
      _lastPressedAt = DateTime.now();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Press back again to exit',
            style: TextStyle(fontFamily: 'Okra'),
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    return await _showExitDialog();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    //set status bar color
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: AppTheme.primaryColor,
      ),
    );
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldExit = await _handleWillPop();
          if (shouldExit) {
            SystemNavigator.pop();
          }
        }
      },
      child: MaterialApp.router(
        title: 'Sylonow',
        theme: AppTheme.lightTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    );
  }
}
