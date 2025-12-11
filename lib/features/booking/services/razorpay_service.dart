import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/payment_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';

class RazorpayService {
  late Razorpay _razorpay;
  final PaymentRepository _paymentRepository;
  final OrderRepository _orderRepository;

  // Razorpay LIVE API credentials
  static const String _keyId = 'rzp_live_RSUaC7MqY7BfsZ';
  static const String _keySecret = 'Cc2vEjqs2SATSz0uI10TYLi7';

  // Callback functions
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function(ExternalWalletResponse)? _onExternalWallet;

  RazorpayService(this._paymentRepository, this._orderRepository) {
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // Callback for payment success with order creation
  Function(String paymentTransactionId, String razorpayPaymentId)? _onOrderCreation;
  Function(String error)? _onPaymentFailed;

  /// Create a Razorpay order and initiate payment with callbacks for payment-first flow
  Future<RazorpayPaymentResult> processPaymentWithCallback({
    required String userId,
    required String vendorId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required Map<String, dynamic> metadata,
    required Future<void> Function(String paymentTransactionId, String razorpayPaymentId) onPaymentSuccess,
    required void Function(String error) onPaymentFailure,
  }) async {
    try {
      // Store callbacks for later use
      _onOrderCreation = onPaymentSuccess;
      _onPaymentFailed = onPaymentFailure;

      // Create payment transaction record WITHOUT order/booking ID (payment-first approach)
      final paymentTransaction = await _paymentRepository
          .createPaymentTransaction(
            userId: userId,
            vendorId: vendorId,
            paymentMethod: 'razorpay',
            amount: amount,
            metadata: metadata,
          );

      // Create Razorpay order
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final receiptId = 'P_$timestamp'; // P for Payment-first

      //('📝 [RAZORPAY] Creating Razorpay order for amount: $amount INR');
      //('📝 [RAZORPAY] Payment transaction ID: ${paymentTransaction.id}');

      final razorpayOrderId = await _createRazorpayOrder(
        amount: amount,
        currency: 'INR',
        receipt: receiptId,
        notes: {
          'user_id': userId,
          'vendor_id': vendorId,
          'payment_transaction_id': paymentTransaction.id,
          'payment_first': 'true', // Flag to indicate payment-first flow
        },
      );

      if (razorpayOrderId == null) {
        //('❌ [RAZORPAY] Failed to create Razorpay order');
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransaction.id,
          status: 'failed',
          failureReason: 'Failed to create Razorpay order',
        );
        _onPaymentFailed?.call('Failed to create payment order');
        return RazorpayPaymentResult.error('Failed to create payment order');
      }

      //('✅ [RAZORPAY] Razorpay order created successfully: $razorpayOrderId');

      // Update payment transaction with order ID
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransaction.id,
        status: 'processing',
        processedAt: DateTime.now(),
      );

      // Configure payment options
      final options = {
        'key': _keyId,
        'amount': (amount * 100).toInt(), // Amount in paise
        'currency': 'INR',
        'order_id': razorpayOrderId,
        'name': 'Sylonow',
        'description': 'Booking Payment (60%)',
        'timeout': 300, // 5 minutes
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
          'name': customerName,
        },
        'theme': {
          'color': '#FF0080', // Sylonow brand color
        },
        'notes': {
          'payment_type': 'razorpay_60_percent',
          'payment_transaction_id': paymentTransaction.id,
          'payment_first': 'true',
        },
      };

      // Set up callbacks for this specific payment
      _setupPaymentCallbacksWithOrderCreation(paymentTransaction.id);

      //('🚀 [RAZORPAY] Opening Razorpay checkout with options: ${options.keys}');
      //('🚀 [RAZORPAY] Payment amount: ${options['amount']} paise');
      //('🚀 [RAZORPAY] Order ID: ${options['order_id']}');
      //('🚀 [RAZORPAY] Razorpay instance hashCode: ${_razorpay.hashCode}');
      final prefillData = options['prefill'] as Map<String, dynamic>?;
      //('🚀 [RAZORPAY] Prefill contact: ${prefillData?['contact']}');
      //('🚀 [RAZORPAY] Prefill email: ${prefillData?['email']}');
      //('🚀 [RAZORPAY] Prefill name: ${prefillData?['name']}');

      // Add a small delay to ensure database transaction is committed
      await Future.delayed(const Duration(milliseconds: 300));

      // Open Razorpay checkout
      try {
        //('🔧 [RAZORPAY] Calling _razorpay.open() with options...');
        //('🔧 [RAZORPAY] Options map: $options');
        _razorpay.open(options);
        //('✅ [RAZORPAY] Razorpay.open() called successfully');
        //('⏳ [RAZORPAY] Waiting for payment UI to appear...');
        //('⏳ [RAZORPAY] If UI does not appear, check:');
        //('   1. App is in foreground');
        //('   2. CheckoutActivity is declared in AndroidManifest.xml');
        //('   3. Full app rebuild was done (not hot reload)');
      } catch (e, stackTrace) {
        //('❌ [RAZORPAY] Error calling _razorpay.open(): $e');
        //('❌ [RAZORPAY] Stack trace: $stackTrace');

        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransaction.id,
          status: 'failed',
          failureReason: 'Failed to open Razorpay: $e',
        );
        _onPaymentFailed?.call('Failed to open payment gateway: $e');
        throw Exception('Failed to open Razorpay checkout: $e');
      }

      return RazorpayPaymentResult.processing(
        paymentTransaction.id,
        razorpayOrderId,
      );
    } catch (e) {
      //('Error processing Razorpay payment: $e');
      _onPaymentFailed?.call('Failed to process payment: ${e.toString()}');
      return RazorpayPaymentResult.error(
        'Failed to process payment: ${e.toString()}',
      );
    }
  }

  /// Create a Razorpay order and initiate payment
  Future<RazorpayPaymentResult> processPayment({
    String? bookingId,
    String? orderId,
    required String userId,
    required String vendorId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      // Validate that either bookingId or orderId is provided
      if (bookingId == null && orderId == null) {
        return RazorpayPaymentResult.error(
          'Either bookingId or orderId must be provided',
        );
      }

      // Create payment transaction record first
      final paymentTransaction = await _paymentRepository
          .createPaymentTransaction(
            bookingId: bookingId,
            orderId: orderId,
            userId: userId,
            vendorId: vendorId,
            paymentMethod: 'razorpay',
            amount: amount,
            metadata: metadata,
          );

      // Create Razorpay order
      // Receipt must be max 40 characters
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final receiptId = '${bookingId != null ? 'B' : 'O'}_$timestamp';

      final razorpayOrderId = await _createRazorpayOrder(
        amount: amount,
        currency: 'INR',
        receipt: receiptId,
        notes: {
          if (bookingId != null) 'booking_id': bookingId,
          if (orderId != null) 'order_id': orderId,
          'user_id': userId,
          'vendor_id': vendorId,
          'payment_transaction_id': paymentTransaction.id,
        },
      );

      if (razorpayOrderId == null) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransaction.id,
          status: 'failed',
          failureReason: 'Failed to create Razorpay order',
        );
        return RazorpayPaymentResult.error('Failed to create payment order');
      }

      // Update payment transaction with order ID
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransaction.id,
        status: 'processing',
        processedAt: DateTime.now(),
      );

      // Configure payment options
      final options = {
        'key': _keyId,
        'amount': (amount * 100).toInt(), // Amount in paise
        'currency': 'INR',
        'order_id': razorpayOrderId,
        'name': 'Sylonow',
        'description': 'Booking Payment (60%)',
        'timeout': 300, // 5 minutes
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
          'name': customerName,
        },
        'theme': {
          'color': '#FF0080', // Sylonow brand color
        },
        'notes': {
          if (bookingId != null) 'booking_id': bookingId,
          if (orderId != null) 'order_id': orderId,
          'payment_type': 'razorpay_60_percent',
          'payment_transaction_id': paymentTransaction.id,
        },
      };

      // Set up callbacks for this specific payment
      _setupPaymentCallbacks(paymentTransaction.id);

      // Open Razorpay checkout
      _razorpay.open(options);

      return RazorpayPaymentResult.processing(
        paymentTransaction.id,
        razorpayOrderId,
      );
    } catch (e) {
      //('Error processing Razorpay payment: $e');
      return RazorpayPaymentResult.error(
        'Failed to process payment: ${e.toString()}',
      );
    }
  }

  /// Create Razorpay order using Razorpay Orders API
  Future<String?> _createRazorpayOrder({
    required double amount,
    required String currency,
    required String receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      // WARNING: In production, this should ALWAYS be done on your backend server
      // Exposing your key_secret in the client app is a security risk
      // This is only for MVP/testing purposes

      final url = Uri.parse('https://api.razorpay.com/v1/orders');
      final basicAuth =
          'Basic ${base64Encode(utf8.encode('$_keyId:$_keySecret'))}';

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(), // Amount in paise
          'currency': currency,
          'receipt': receipt,
          'notes': notes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orderId = data['id'] as String;
        //('✅ Razorpay order created: $orderId');
        return orderId;
      } else {
        //('❌ Razorpay order creation failed: ${response.statusCode}');
        //('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      //('❌ Error creating Razorpay order: $e');
      return null;
    }
  }

  /// Set up payment callbacks for specific payment transaction
  void _setupPaymentCallbacks(String paymentTransactionId) {
    _onPaymentSuccess = (response) =>
        _handleSpecificPaymentSuccess(response, paymentTransactionId);
    _onPaymentError = (response) =>
        _handleSpecificPaymentError(response, paymentTransactionId);
    _onExternalWallet = (response) =>
        _handleSpecificExternalWallet(response, paymentTransactionId);
  }

  /// Set up payment callbacks for payment-first flow with order creation
  void _setupPaymentCallbacksWithOrderCreation(String paymentTransactionId) {
    _onPaymentSuccess = (response) =>
        _handlePaymentSuccessWithOrderCreation(response, paymentTransactionId);
    _onPaymentError = (response) =>
        _handlePaymentErrorWithFailureCallback(response, paymentTransactionId);
    _onExternalWallet = (response) =>
        _handleSpecificExternalWallet(response, paymentTransactionId);
  }

  /// Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_onPaymentSuccess != null) {
      _onPaymentSuccess!(response);
    }
  }

  /// Handle payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    if (_onPaymentError != null) {
      _onPaymentError!(response);
    }
  }

  /// Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    if (_onExternalWallet != null) {
      _onExternalWallet!(response);
    }
  }

  /// Handle specific payment success
  Future<void> _handleSpecificPaymentSuccess(
    PaymentSuccessResponse response,
    String paymentTransactionId,
  ) async {
    try {
      // Verify payment signature
      final isSignatureValid = _verifyPaymentSignature(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );

      if (!isSignatureValid) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransactionId,
          status: 'failed',
          failureReason: 'Invalid payment signature',
        );
        return;
      }

      // Update payment transaction as completed
      final updatedPayment = await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'completed',
        razorpayPaymentId: response.paymentId,
        razorpaySignature: response.signature,
        processedAt: DateTime.now(),
      );

      // Update the order with advance payment information
      // Support both bookings and orders tables
      if (updatedPayment.orderId != null) {
        await _orderRepository.updateOrderPayment(
          orderId: updatedPayment.orderId!,
          paymentStatus: 'advance_paid',
        );
      } else if (updatedPayment.bookingId != null) {
      
      }

      //('Razorpay payment successful: ${response.paymentId}');
    } catch (e) {
      //('Error handling payment success: $e');
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: 'Error processing successful payment',
      );
    }
  }

  /// Handle specific payment error
  Future<void> _handleSpecificPaymentError(
    PaymentFailureResponse response,
    String paymentTransactionId,
  ) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: '${response.code}: ${response.message}',
      );

    
    } catch (e) {
     
    }
  }

  /// Handle specific external wallet
  Future<void> _handleSpecificExternalWallet(
    ExternalWalletResponse response,
    String paymentTransactionId,
  ) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'processing',
        failureReason:
            'Payment redirected to external wallet: ${response.walletName}',
      );

      
    } catch (e) {
      //('Error handling external wallet: $e');
    }
  }

  /// Handle payment success for payment-first flow (triggers order creation)
  Future<void> _handlePaymentSuccessWithOrderCreation(
    PaymentSuccessResponse response,
    String paymentTransactionId,
  ) async {
    try {
      // Verify payment signature
      final isSignatureValid = _verifyPaymentSignature(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );

      if (!isSignatureValid) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransactionId,
          status: 'failed',
          failureReason: 'Invalid payment signature',
        );
        _onPaymentFailed?.call('Invalid payment signature');
        return;
      }

      // Update payment transaction as completed
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'completed',
        razorpayPaymentId: response.paymentId,
        razorpaySignature: response.signature,
        processedAt: DateTime.now(),
      );

      //('✅ Razorpay payment successful: ${response.paymentId}');
      //('✅ Now triggering order creation callback...');

      // Trigger the order creation callback
      if (_onOrderCreation != null) {
        await _onOrderCreation!(paymentTransactionId, response.paymentId ?? '');
      }
    } catch (e) {
      //('❌ Error handling payment success: $e');
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: 'Error processing successful payment',
      );
      _onPaymentFailed?.call('Error processing payment: ${e.toString()}');
    }
  }

  /// Handle payment error for payment-first flow (triggers failure callback)
  Future<void> _handlePaymentErrorWithFailureCallback(
    PaymentFailureResponse response,
    String paymentTransactionId,
  ) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: '${response.code}: ${response.message}',
      );

     

      // Trigger the failure callback
      _onPaymentFailed?.call('${response.code}: ${response.message}');
    } catch (e) {
      //('Error handling payment failure: $e');
      _onPaymentFailed?.call('Payment failed: ${e.toString()}');
    }
  }

  /// Verify Razorpay payment signature
  bool _verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    try {
      final data = '$orderId|$paymentId';
      final key = utf8.encode(_keySecret);
      final bytes = utf8.encode(data);

      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final generatedSignature = digest.toString();

      return generatedSignature == signature;
    } catch (e) {
      //('Error verifying payment signature: $e');
      return false;
    }
  }

  /// Get payment status
  Future<PaymentModel?> getPaymentStatus(String paymentTransactionId) async {
    try {
      return await _paymentRepository.getPaymentById(paymentTransactionId);
    } catch (e) {
      //('Error getting payment status: $e');
      return null;
    }
  }

  /// Process refund
  Future<RefundResult> processRefund({
    required String paymentId,
    required double amount,
    String? reason,
  }) async {
    try {
      // Note: In production, refund should be processed through your backend
      // This is a simplified implementation

      final refundId = 'rfnd_${DateTime.now().millisecondsSinceEpoch}';

      await _paymentRepository.processRefund(
        paymentId: paymentId,
        refundAmount: amount,
        refundId: refundId,
        reason: reason,
      );

      return RefundResult.success(refundId);
    } catch (e) {
      //('Error processing refund: $e');
      return RefundResult.error('Failed to process refund: ${e.toString()}');
    }
  }

  /// Dispose Razorpay instance
  void dispose() {
    _razorpay.clear();
  }
}

// Result classes for type-safe returns
class RazorpayPaymentResult {
  final bool isSuccess;
  final String message;
  final String? paymentTransactionId;
  final String? orderId;

  RazorpayPaymentResult._({
    required this.isSuccess,
    required this.message,
    this.paymentTransactionId,
    this.orderId,
  });

  factory RazorpayPaymentResult.processing(
    String paymentTransactionId,
    String orderId,
  ) {
    return RazorpayPaymentResult._(
      isSuccess: true,
      message: 'Payment processing initiated',
      paymentTransactionId: paymentTransactionId,
      orderId: orderId,
    );
  }

  factory RazorpayPaymentResult.error(String message) {
    return RazorpayPaymentResult._(isSuccess: false, message: message);
  }
}

class RefundResult {
  final bool isSuccess;
  final String message;
  final String? refundId;

  RefundResult._({
    required this.isSuccess,
    required this.message,
    this.refundId,
  });

  factory RefundResult.success(String refundId) {
    return RefundResult._(
      isSuccess: true,
      message: 'Refund processed successfully',
      refundId: refundId,
    );
  }

  factory RefundResult.error(String message) {
    return RefundResult._(isSuccess: false, message: message);
  }
}
