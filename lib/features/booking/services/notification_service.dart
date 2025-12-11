import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Notification types
  static const String typeBookingConfirmed = 'booking_confirmed';
  static const String typeBookingCancelled = 'booking_cancelled';
  static const String typePaymentCompleted = 'payment_completed';
  static const String typeBookingReminder = 'booking_reminder';
  static const String typeBookingStarted = 'booking_started';
  static const String typeBookingCompleted = 'booking_completed';

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Request permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Configure FCM
      await _configureFCM();

      //('Notification service initialized successfully');
    } catch (e) {
      //('Error initializing notification service: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (_firebaseMessaging == null) return;

    final settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    //('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    if (_localNotifications == null) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (_localNotifications == null) return;

    const bookingChannel = AndroidNotificationChannel(
      'booking_notifications',
      'Booking Notifications',
      description: 'Notifications related to bookings',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const paymentChannel = AndroidNotificationChannel(
      'payment_notifications',
      'Payment Notifications',
      description: 'Notifications related to payments',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _localNotifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(bookingChannel);

    await _localNotifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(paymentChannel);
  }

  /// Configure Firebase Cloud Messaging
  Future<void> _configureFCM() async {
    if (_firebaseMessaging == null) return;

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);

    // Handle when app is opened from terminated state
    final initialMessage = await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpenedApp(initialMessage);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    //('Received foreground message: ${message.messageId}');
    _showLocalNotification(message);
  }

  /// Handle when notification is opened from background/terminated state
  void _handleNotificationOpenedApp(RemoteMessage message) {
    //('Notification opened app: ${message.messageId}');
    _navigateToScreen(message);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    //('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _navigateToScreenFromData(data);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _getChannelId(data['type']),
          _getChannelName(data['type']),
          channelDescription: 'Sylonow booking notifications',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFF0080), // Sylonow brand color
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications!.show(
        message.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode(data),
      );
    }
  }

  /// Get channel ID based on notification type
  String _getChannelId(String? type) {
    switch (type) {
      case typePaymentCompleted:
        return 'payment_notifications';
      default:
        return 'booking_notifications';
    }
  }

  /// Get channel name based on notification type
  String _getChannelName(String? type) {
    switch (type) {
      case typePaymentCompleted:
        return 'Payment Notifications';
      default:
        return 'Booking Notifications';
    }
  }

  /// Navigate to appropriate screen based on message
  void _navigateToScreen(RemoteMessage message) {
    _navigateToScreenFromData(message.data);
  }

  /// Navigate to screen based on data
  void _navigateToScreenFromData(Map<String, dynamic> data) {
    // This would be implemented based on your navigation requirements
    // For now, just log the navigation intent
    //('Would navigate to: ${data['screen']} with data: $data');
  }

  /// Send booking confirmation notification to vendor
  Future<NotificationResult> sendBookingConfirmationToVendor({
    required String vendorId,
    required BookingModel booking,
  }) async {
    try {
      final vendor = await _getVendorById(vendorId);
      if (vendor == null) {
        return NotificationResult.error('Vendor not found');
      }

      final fcmToken = vendor['fcm_token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        return NotificationResult.error('Vendor FCM token not available');
      }

      final notificationData = {
        'type': typeBookingConfirmed,
        'booking_id': booking.id,
        'vendor_id': vendorId,
        'customer_name': booking.customerName,
        'service_title': booking.serviceTitle,
        'booking_date': booking.bookingDate.toIso8601String(),
        'booking_time': booking.bookingTime,
        'total_amount': booking.totalAmount.toString(),
        'screen': 'booking_details',
      };

      final title = '🎉 New Booking Confirmed!';
      final body = '${booking.customerName} booked ${booking.serviceTitle} for ${_formatDate(booking.bookingDate)} at ${booking.bookingTime}';

      // Queue notification in database
      await _queueNotification(
        vendorId: vendorId,
        bookingId: booking.id,
        fcmToken: fcmToken,
        type: typeBookingConfirmed,
        title: title,
        body: body,
        data: notificationData,
      );

      // Send immediate notification
      final result = await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: notificationData,
      );

      if (result.isSuccess) {
        // Mark notification as sent
        await _markNotificationAsSent(booking.id, vendorId);
      }

      return result;
    } catch (e) {
      //('Error sending booking confirmation: $e');
      return NotificationResult.error('Failed to send notification: ${e.toString()}');
    }
  }

  /// Send payment completion notification to vendor
  Future<NotificationResult> sendPaymentCompletionToVendor({
    required String vendorId,
    required BookingModel booking,
    required double totalPaidAmount,
  }) async {
    try {
      final vendor = await _getVendorById(vendorId);
      if (vendor == null) {
        return NotificationResult.error('Vendor not found');
      }

      final fcmToken = vendor['fcm_token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        return NotificationResult.error('Vendor FCM token not available');
      }

      final notificationData = {
        'type': typePaymentCompleted,
        'booking_id': booking.id,
        'vendor_id': vendorId,
        'customer_name': booking.customerName,
        'service_title': booking.serviceTitle,
        'paid_amount': totalPaidAmount.toString(),
        'screen': 'booking_details',
      };

      final title = '💰 Payment Received!';
      final body = 'Payment of ₹${totalPaidAmount.toStringAsFixed(2)} received for booking by ${booking.customerName}';

      return await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: notificationData,
      );
    } catch (e) {
      //('Error sending payment completion notification: $e');
      return NotificationResult.error('Failed to send notification: ${e.toString()}');
    }
  }

  /// Send booking reminder notification
  Future<NotificationResult> sendBookingReminder({
    required String vendorId,
    required BookingModel booking,
    required int hoursBeforeBooking,
  }) async {
    try {
      final vendor = await _getVendorById(vendorId);
      if (vendor == null) {
        return NotificationResult.error('Vendor not found');
      }

      final fcmToken = vendor['fcm_token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        return NotificationResult.error('Vendor FCM token not available');
      }

      final notificationData = {
        'type': typeBookingReminder,
        'booking_id': booking.id,
        'vendor_id': vendorId,
        'customer_name': booking.customerName,
        'service_title': booking.serviceTitle,
        'booking_date': booking.bookingDate.toIso8601String(),
        'booking_time': booking.bookingTime,
        'hours_before': hoursBeforeBooking.toString(),
        'screen': 'booking_details',
      };

      final title = '⏰ Booking Reminder';
      final body = 'You have a booking with ${booking.customerName} in $hoursBeforeBooking hours (${booking.bookingTime})';

      return await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: notificationData,
      );
    } catch (e) {
      //('Error sending booking reminder: $e');
      return NotificationResult.error('Failed to send notification: ${e.toString()}');
    }
  }

  /// Send FCM notification
  Future<NotificationResult> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Note: In production, this should be done through your backend server
      // This is a simplified implementation for demo purposes
      
      // For now, we'll simulate sending the notification
      // In real implementation, you would make HTTP request to FCM endpoint
      
      //('Sending FCM notification:');
      //('Title: $title');
      //('Body: $body');
      //('Token: ${token.substring(0, 20)}...');
      //('Data: $data');

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Simulate success (in real implementation, check actual response)
      return NotificationResult.success('Notification sent successfully');
    } catch (e) {
      //('Error sending FCM notification: $e');
      return NotificationResult.error('Failed to send FCM notification');
    }
  }

  /// Queue notification in database
  Future<void> _queueNotification({
    required String vendorId,
    required String bookingId,
    required String fcmToken,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _supabase.from('notification_queue').insert({
        'vendor_id': vendorId,
        'booking_id': bookingId,
        'fcm_token': fcmToken,
        'notification_type': type,
        'title': title,
        'body': body,
        'data': data,
        'sent': false,
        'retry_count': 0,
      });
    } catch (e) {
      //('Error queueing notification: $e');
    }
  }

  /// Mark notification as sent
  Future<void> _markNotificationAsSent(String bookingId, String vendorId) async {
    try {
      await _supabase
          .from('notification_queue')
          .update({
            'sent': true,
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('booking_id', bookingId)
          .eq('vendor_id', vendorId);
    } catch (e) {
      //('Error marking notification as sent: $e');
    }
  }

  /// Get vendor by ID
  Future<Map<String, dynamic>?> _getVendorById(String vendorId) async {
    try {
      final response = await _supabase
          .from('vendors')
          .select('id, fcm_token, business_name, full_name')
          .eq('id', vendorId)
          .maybeSingle();

      return response;
    } catch (e) {
      //('Error getting vendor: $e');
      return null;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Get FCM token for current user
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging?.getToken();
    } catch (e) {
      //('Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging?.subscribeToTopic(topic);
      //('Subscribed to topic: $topic');
    } catch (e) {
      //('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging?.unsubscribeFromTopic(topic);
      //('Unsubscribed from topic: $topic');
    } catch (e) {
      //('Error unsubscribing from topic: $e');
    }
  }
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  //('Handling background message: ${message.messageId}');
  // Handle background message processing here
}

/// Result class for notification operations
class NotificationResult {
  final bool isSuccess;
  final String message;

  NotificationResult._({
    required this.isSuccess,
    required this.message,
  });

  factory NotificationResult.success(String message) {
    return NotificationResult._(
      isSuccess: true,
      message: message,
    );
  }

  factory NotificationResult.error(String message) {
    return NotificationResult._(
      isSuccess: false,
      message: message,
    );
  }
} 