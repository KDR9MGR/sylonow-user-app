import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/services/image_upload_service.dart';
import '../../home/models/service_listing_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/booking_providers.dart';
import '../models/order_model.dart';
import '../services/razorpay_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bookingData;

  const PaymentScreen({
    super.key,
    required this.bookingData,
  });

  static const String routeName = '/payment';

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool isPaymentSelected = false;

  // Calculate payment amounts
  double get totalAmount => widget.bookingData['totalAmount'] as double;
  double get advanceAmount => totalAmount * 0.6; // 60% advance payment
  double get remainingAmount => totalAmount * 0.4; // 40% remaining payment
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(
            fontFamily: 'Okra',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Amount Card
                  _buildPaymentAmountCard(),
                  const SizedBox(height: 24),

                  // Payment Breakdown
                  _buildPaymentBreakdownCard(),
                  const SizedBox(height: 24),

                  // Payment Method Section
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 24),

                  // Payment Security Info
                  _buildSecurityInfo(),
                  const SizedBox(height: 24),

                  // Service Details Card
                  _buildServiceDetailsCard(),
                ],
              ),
            ),
          ),
          
          // Bottom Payment Button
          _buildPaymentButton(),
        ],
      ),
    );
  }

  Widget _buildPaymentAmountCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Colors.pink[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advance Payment (60%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${advanceAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remaining amount to be paid after service completion',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontFamily: 'Okra',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentBreakdownRow(
            label: 'Total Amount',
            amount: totalAmount,
            isTotal: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _buildPaymentBreakdownRow(
            label: 'Advance Payment (60%)',
            amount: advanceAmount,
            isPrimary: true,
          ),
          const SizedBox(height: 8),
          _buildPaymentBreakdownRow(
            label: 'Remaining Payment (40%)',
            amount: remainingAmount,
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownRow({
    required String label,
    required double amount,
    bool isTotal = false,
    bool isPrimary = false,
    bool isSecondary = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isPrimary 
                ? AppTheme.primaryColor
                : isSecondary 
                    ? Colors.grey[600]
                    : Colors.black,
            fontFamily: 'Okra',
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isPrimary 
                ? AppTheme.primaryColor
                : isSecondary 
                    ? Colors.grey[600]
                    : Colors.black,
            fontFamily: 'Okra',
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 20),

          // Razorpay Payment Method
          GestureDetector(
            onTap: () {
              setState(() {
                isPaymentSelected = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isPaymentSelected 
                    ? LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                      )
                    : null,
                color: isPaymentSelected ? null : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPaymentSelected ? Colors.transparent : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  // Razorpay Logo
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/razorpay.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay with Razorpay',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPaymentSelected ? Colors.white : Colors.black,
                            fontFamily: 'Okra',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cards, UPI, Wallets & More',
                          style: TextStyle(
                            fontSize: 14,
                            color: isPaymentSelected ? Colors.white70 : Colors.grey[600],
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isPaymentSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isPaymentSelected ? Colors.white : Colors.grey[400],
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          if (isPaymentSelected) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Razorpay selected - Proceed to secure payment',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.green[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                    fontFamily: 'Okra',
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment information is encrypted and secure. We use industry-standard security measures.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[600],
                    fontFamily: 'Okra',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetailsCard() {
    final service = widget.bookingData['service'] as ServiceListingModel;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.celebration, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
              const SizedBox(width: 8),
              Text(
                'Booking Date: ${widget.bookingData['selectedDate']?.toString().split(' ')[0] ?? 'TBD'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.grey[600], size: 16),
              const SizedBox(width: 8),
              Text(
                'Time Slot: ${widget.bookingData['selectedTimeSlot'] ?? 'TBD'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ll pay ₹${remainingAmount.toStringAsFixed(2)} after service completion',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: isPaymentSelected 
                    ? 'Pay ₹${advanceAmount.toStringAsFixed(2)} Now'
                    : 'Select Payment Method',
                onPressed: isPaymentSelected ? _processPayment : () {},
                backgroundColor: isPaymentSelected 
                    ? AppTheme.primaryColor 
                    : Colors.grey[400]!,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processPayment() async {
    final bookingData = widget.bookingData;
    final service = bookingData['service'] as ServiceListingModel;
    final user = ref.read(currentUserProvider);
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated. Please login again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Extract customer details from booking data
      final customization = bookingData['customization'] as Map<String, dynamic>? ?? {};
      final customerAge = customization['customerAge'] as int?;
      final occasion = customization['occasion'] as String?;

      // First create the order in the database (without place image initially)
      final order = await ref.read(orderCreationProvider.notifier).createOrder(
        userId: user.id,
        vendorId: service.vendorId ?? service.vendor?.id ?? 'unknown-vendor',
        customerName: bookingData['customerName'] ?? user.userMetadata?['full_name'] ?? 'Customer',
        serviceListingId: service.id,
        serviceTitle: service.name,
        bookingDate: bookingData['selectedDate'] ?? DateTime.now(),
        totalAmount: totalAmount,
        advanceAmount: advanceAmount,
        remainingAmount: remainingAmount,
        customerPhone: user.phone ?? bookingData['customerPhone'],
        customerEmail: user.email,
        serviceDescription: service.description,
        bookingTime: bookingData['selectedTimeSlot'],
        specialRequirements: bookingData['specialRequirements'],
        addressId: bookingData['selectedAddressId'],
        placeImageUrl: null, // Will be updated after payment success
        age: customerAge,
        occasion: occasion,
      );

      // Store the order in the current order provider
      ref.read(currentOrderProvider.notifier).state = order;

      // Process Razorpay payment for 60% advance (this will trigger payment UI)
      await ref.read(razorpayPaymentProvider.notifier).processPayment(
        bookingId: order.id,
        userId: user.id,
        vendorId: order.vendorId ?? '',
        amount: advanceAmount,
        customerName: order.customerName,
        customerEmail: order.customerEmail ?? user.email ?? '',
        customerPhone: order.customerPhone ?? user.phone ?? '',
        metadata: {
          ...bookingData,
          'orderId': order.id,
          'isAdvancePayment': true,
          'advanceAmount': advanceAmount,
          'remainingAmount': remainingAmount,
        },
      );

      // Listen for payment result to handle success/failure
      _listenForPaymentResult(order);

    } catch (error) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _listenForPaymentResult(OrderModel order) {
    // Listen to payment provider state changes
    ref.listen<AsyncValue<RazorpayPaymentResult?>>(
      razorpayPaymentProvider,
      (previous, next) async {
        next.when(
          data: (result) async {
            if (result != null && result.isSuccess) {
              // Payment successful - now upload place image if available
              await _handlePaymentSuccess(order);
            } else if (result != null && !result.isSuccess) {
              // Payment failed
              _handlePaymentFailure(result.message);
            }
          },
          loading: () {
            // Payment in progress - show loading if needed
            //('Payment processing...');
          },
          error: (error, stackTrace) {
            // Payment error
            _handlePaymentFailure(error.toString());
          },
        );
      },
    );
  }

  Future<void> _handlePaymentSuccess(OrderModel order) async {
    //('🎉 Payment successful! Processing place image upload...');
    
    try {
      String? placeImageUrl;
      
      // Check if there's a place image to upload
      final placeImageData = widget.bookingData['placeImage'];
      if (placeImageData != null && placeImageData is XFile) {
        //('📸 Uploading place image after successful payment...');
        
        final uploadService = ImageUploadService();
        final user = ref.read(currentUserProvider)!;
        
        placeImageUrl = await uploadService.uploadPlaceImage(
          imageFile: placeImageData,
          userId: user.id,
          orderId: 'orders/${order.id}',
        );
        
        if (placeImageUrl != null) {
          //('✅ Place image uploaded: $placeImageUrl');
          
          // Update the order with the place image URL
          await ref.read(orderRepositoryProvider).updateOrderPlaceImage(
            orderId: order.id,
            placeImageUrl: placeImageUrl,
          );
          //('✅ Order updated with place image URL');
        } else {
          //('❌ Failed to upload place image');
        }
      } else {
        //('ℹ️ No place image to upload');
      }

      // Navigate to success screen
      _navigateToSuccess(order.copyWith(placeImageUrl: placeImageUrl));
      
    } catch (e) {
      //('❌ Error handling payment success: $e');
      // Still navigate to success even if image upload fails
      _navigateToSuccess(order);
    }
  }

  void _handlePaymentFailure(String error) {
    //('❌ Payment failed: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _navigateToSuccess(OrderModel order) {
    context.push('/booking/success', extra: {
      'order': order,
      'bookingData': {
        ...widget.bookingData,
        'orderId': order.id,
        'advanceAmount': advanceAmount,
        'remainingAmount': remainingAmount,
      },
      'paymentMethod': 'razorpay',
    });
  }
} 