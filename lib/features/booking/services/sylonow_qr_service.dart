import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';

class SylonowQrService {
  final PaymentRepository _paymentRepository;

  // QR Code configuration
  static const String _qrVersion = '1.0';
  static const String _merchantId =
      'SYLONOW_MERCHANT_001'; // Configure as needed
  static const String _merchantName = 'Sylonow';

  SylonowQrService(this._paymentRepository);

  /// Generate QR code for Sylonow payment
  Future<QrPaymentResult> generateQrPayment({
    String? bookingId,
    String? orderId,
    required String userId,
    required String vendorId,
    required double amount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) async {
    try {
      // Validate that either bookingId or orderId is provided
      if (bookingId == null && orderId == null) {
        return QrPaymentResult.error(
          'Either bookingId or orderId must be provided',
        );
      }

      final referenceId = bookingId ?? orderId!;

      // Create payment transaction record first
      final paymentTransaction = await _paymentRepository
          .createPaymentTransaction(
            bookingId: bookingId,
            orderId: orderId,
            userId: userId,
            vendorId: vendorId,
            paymentMethod: 'sylonow_qr',
            amount: amount,
            metadata: {
              'customer_name': customerName,
              'customer_phone': customerPhone,
              'customer_email': customerEmail,
              'qr_version': _qrVersion,
            },
          );

      // Generate payment reference
      final paymentReference = _generatePaymentReference(
        referenceId: referenceId,
        paymentTransactionId: paymentTransaction.id,
        amount: amount,
      );

      // Create QR code data
      final qrData = _createQrCodeData(
        paymentReference: paymentReference,
        amount: amount,
        customerName: customerName,
        customerPhone: customerPhone,
        referenceId: referenceId,
      );

      // Update payment transaction with QR data
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransaction.id,
        status: 'processing',
        processedAt: DateTime.now(),
      );

      // Generate QR code widget
      final qrWidget = _generateQrWidget(qrData);

      return QrPaymentResult.success(
        paymentTransactionId: paymentTransaction.id,
        qrCodeData: qrData,
        paymentReference: paymentReference,
        qrWidget: qrWidget,
        amount: amount,
        expiryTime: DateTime.now().add(
          const Duration(minutes: 15),
        ), // 15 minutes validity
      );
    } catch (e) {
      //('Error generating QR payment: $e');
      return QrPaymentResult.error(
        'Failed to generate QR payment: ${e.toString()}',
      );
    }
  }

  /// Generate payment reference
  String _generatePaymentReference({
    required String referenceId,
    required String paymentTransactionId,
    required double amount,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final amountString = amount.toStringAsFixed(2).replaceAll('.', '');
    final referenceShort = referenceId.substring(0, 8);

    return 'SLN${timestamp}_${referenceShort}_$amountString';
  }

  /// Create QR code data
  String _createQrCodeData({
    required String paymentReference,
    required double amount,
    required String customerName,
    required String customerPhone,
    required String referenceId,
  }) {
    final qrPayload = {
      'version': _qrVersion,
      'type': 'sylonow_payment',
      'merchant_id': _merchantId,
      'merchant_name': _merchantName,
      'payment_reference': paymentReference,
      'amount': amount,
      'currency': 'INR',
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'reference_id': referenceId,
      'timestamp': DateTime.now().toIso8601String(),
      'expiry': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'payment_method': 'sylonow_wallet',
    };

    return jsonEncode(qrPayload);
  }

  /// Generate QR code widget
  Widget _generateQrWidget(String qrData) {
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      padding: const EdgeInsets.all(8.0),
      embeddedImage: null, // Can add Sylonow logo here
      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
    );
  }

  /// Verify QR payment (to be called when user scans and pays)
  Future<PaymentVerificationResult> verifyQrPayment({
    required String paymentTransactionId,
    required String paymentReference,
    required String verificationCode,
    String? verifiedBy,
  }) async {
    try {
      // Get payment transaction
      final payment = await _paymentRepository.getPaymentById(
        paymentTransactionId,
      );
      if (payment == null) {
        return PaymentVerificationResult.error('Payment transaction not found');
      }

      // Check if payment is still valid
      if (payment.status == 'completed') {
        return PaymentVerificationResult.error('Payment already completed');
      }

      if (payment.status == 'failed' || payment.status == 'cancelled') {
        return PaymentVerificationResult.error(
          'Payment transaction is ${payment.status}',
        );
      }

      // Verify payment reference matches
      if (payment.qrPaymentReference != paymentReference) {
        return PaymentVerificationResult.error('Invalid payment reference');
      }

      // Check if payment is not expired (15 minutes)
      final createdAt = payment.createdAt;
      final expiryTime = createdAt.add(const Duration(minutes: 15));
      if (DateTime.now().isAfter(expiryTime)) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransactionId,
          status: 'failed',
          failureReason: 'Payment expired',
        );
        return PaymentVerificationResult.error('Payment has expired');
      }

      // In a real implementation, you would verify the payment with your payment processor
      // For now, we'll simulate verification based on verification code
      final isValidCode = _verifyPaymentCode(
        verificationCode,
        paymentReference,
      );

      if (!isValidCode) {
        return PaymentVerificationResult.error('Invalid verification code');
      }

      // Update payment status to completed
      final updatedPayment = await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'completed',
        processedAt: DateTime.now(),
      );

      return PaymentVerificationResult.success(updatedPayment);
    } catch (e) {
      //('Error verifying QR payment: $e');
      return PaymentVerificationResult.error(
        'Failed to verify payment: ${e.toString()}',
      );
    }
  }

  /// Verify payment code (simplified implementation)
  bool _verifyPaymentCode(String verificationCode, String paymentReference) {
    // In a real implementation, this would check with your payment processor
    // For demo purposes, we'll accept codes that match a simple pattern

    // Example: verification code should be last 6 digits of payment reference + 'PAID'
    final expectedCode =
        '${paymentReference.substring(paymentReference.length - 6)}PAID';
    return verificationCode.toUpperCase() == expectedCode.toUpperCase();
  }

  /// Get QR payment status
  Future<PaymentModel?> getQrPaymentStatus(String paymentTransactionId) async {
    try {
      return await _paymentRepository.getPaymentById(paymentTransactionId);
    } catch (e) {
      //('Error getting QR payment status: $e');
      return null;
    }
  }

  /// Cancel QR payment
  Future<bool> cancelQrPayment(String paymentTransactionId) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'cancelled',
        failureReason: 'Payment cancelled by user',
      );
      return true;
    } catch (e) {
      //('Error cancelling QR payment: $e');
      return false;
    }
  }

  /// Get payment instructions for users
  String getPaymentInstructions(double amount) {
    return '''
🔹 Open Sylonow app and tap on "Scan QR"
🔹 Scan the QR code above
🔹 Verify payment amount: ₹${amount.toStringAsFixed(2)}
🔹 Complete payment using your Sylonow wallet
🔹 Payment will be automatically verified

Note: QR code is valid for 15 minutes only.
''';
  }

  /// Generate QR code for wallet top-up
  Future<QrTopUpResult> generateWalletTopUpQr({
    required String userId,
    required double amount,
  }) async {
    try {
      final topUpReference =
          'TOPUP_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}';

      final qrData = jsonEncode({
        'version': _qrVersion,
        'type': 'sylonow_topup',
        'merchant_id': _merchantId,
        'merchant_name': _merchantName,
        'topup_reference': topUpReference,
        'user_id': userId,
        'amount': amount,
        'currency': 'INR',
        'timestamp': DateTime.now().toIso8601String(),
        'expiry': DateTime.now()
            .add(const Duration(minutes: 30))
            .toIso8601String(),
      });

      final qrWidget = _generateQrWidget(qrData);

      return QrTopUpResult.success(
        topUpReference: topUpReference,
        qrCodeData: qrData,
        qrWidget: qrWidget,
        amount: amount,
        expiryTime: DateTime.now().add(const Duration(minutes: 30)),
      );
    } catch (e) {
      //('Error generating wallet top-up QR: $e');
      return QrTopUpResult.error(
        'Failed to generate top-up QR: ${e.toString()}',
      );
    }
  }

  /// Refresh QR code (generate new one with extended expiry)
  Future<QrPaymentResult> refreshQrPayment(String paymentTransactionId) async {
    try {
      final payment = await _paymentRepository.getPaymentById(
        paymentTransactionId,
      );
      if (payment == null) {
        return QrPaymentResult.error('Payment transaction not found');
      }

      // Get reference ID (either bookingId or orderId)
      final referenceId = payment.bookingId ?? payment.orderId;
      if (referenceId == null) {
        return QrPaymentResult.error(
          'Payment has no valid booking or order ID',
        );
      }

      // Generate new payment reference
      final newPaymentReference = _generatePaymentReference(
        referenceId: referenceId,
        paymentTransactionId: paymentTransactionId,
        amount: payment.amount,
      );

      // Create new QR code data
      final qrData = _createQrCodeData(
        paymentReference: newPaymentReference,
        amount: payment.amount,
        customerName: payment.metadata?['customer_name'] ?? 'Customer',
        customerPhone: payment.metadata?['customer_phone'] ?? '',
        referenceId: referenceId,
      );

      // Update payment transaction
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'processing',
        processedAt: DateTime.now(),
      );

      final qrWidget = _generateQrWidget(qrData);

      return QrPaymentResult.success(
        paymentTransactionId: paymentTransactionId,
        qrCodeData: qrData,
        paymentReference: newPaymentReference,
        qrWidget: qrWidget,
        amount: payment.amount,
        expiryTime: DateTime.now().add(const Duration(minutes: 15)),
      );
    } catch (e) {
      //('Error refreshing QR payment: $e');
      return QrPaymentResult.error(
        'Failed to refresh QR payment: ${e.toString()}',
      );
    }
  }
}

// Result classes for type-safe returns
class QrPaymentResult {
  final bool isSuccess;
  final String message;
  final String? paymentTransactionId;
  final String? qrCodeData;
  final String? paymentReference;
  final Widget? qrWidget;
  final double? amount;
  final DateTime? expiryTime;

  QrPaymentResult._({
    required this.isSuccess,
    required this.message,
    this.paymentTransactionId,
    this.qrCodeData,
    this.paymentReference,
    this.qrWidget,
    this.amount,
    this.expiryTime,
  });

  factory QrPaymentResult.success({
    required String paymentTransactionId,
    required String qrCodeData,
    required String paymentReference,
    required Widget qrWidget,
    required double amount,
    required DateTime expiryTime,
  }) {
    return QrPaymentResult._(
      isSuccess: true,
      message: 'QR payment generated successfully',
      paymentTransactionId: paymentTransactionId,
      qrCodeData: qrCodeData,
      paymentReference: paymentReference,
      qrWidget: qrWidget,
      amount: amount,
      expiryTime: expiryTime,
    );
  }

  factory QrPaymentResult.error(String message) {
    return QrPaymentResult._(isSuccess: false, message: message);
  }
}

class PaymentVerificationResult {
  final bool isSuccess;
  final String message;
  final PaymentModel? payment;

  PaymentVerificationResult._({
    required this.isSuccess,
    required this.message,
    this.payment,
  });

  factory PaymentVerificationResult.success(PaymentModel payment) {
    return PaymentVerificationResult._(
      isSuccess: true,
      message: 'Payment verified successfully',
      payment: payment,
    );
  }

  factory PaymentVerificationResult.error(String message) {
    return PaymentVerificationResult._(isSuccess: false, message: message);
  }
}

class QrTopUpResult {
  final bool isSuccess;
  final String message;
  final String? topUpReference;
  final String? qrCodeData;
  final Widget? qrWidget;
  final double? amount;
  final DateTime? expiryTime;

  QrTopUpResult._({
    required this.isSuccess,
    required this.message,
    this.topUpReference,
    this.qrCodeData,
    this.qrWidget,
    this.amount,
    this.expiryTime,
  });

  factory QrTopUpResult.success({
    required String topUpReference,
    required String qrCodeData,
    required Widget qrWidget,
    required double amount,
    required DateTime expiryTime,
  }) {
    return QrTopUpResult._(
      isSuccess: true,
      message: 'Top-up QR generated successfully',
      topUpReference: topUpReference,
      qrCodeData: qrCodeData,
      qrWidget: qrWidget,
      amount: amount,
      expiryTime: expiryTime,
    );
  }

  factory QrTopUpResult.error(String message) {
    return QrTopUpResult._(isSuccess: false, message: message);
  }
}
