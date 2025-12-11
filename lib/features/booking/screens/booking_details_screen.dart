import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/models/service_listing_model.dart';
import '../../profile/providers/profile_providers.dart';
import 'checkout_screen.dart';

class BookingDetailsScreen extends ConsumerStatefulWidget {
  final ServiceListingModel service;
  final Map<String, dynamic> customizationData;
  final Map<String, Map<String, dynamic>>? selectedAddOns;

  const BookingDetailsScreen({
    super.key,
    required this.service,
    required this.customizationData,
    this.selectedAddOns,
  });

  static const String routeName = '/booking-details';

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  // Customer info controllers
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerAgeController = TextEditingController();
  final TextEditingController occasionController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await ref.read(currentUserProfileProvider.future);

      if (userProfile?.fullName != null && mounted) {
        setState(() {
          customerNameController.text = userProfile!.fullName!;
        });
      }
    } catch (e) {
      //('Error loading user profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerAgeController.dispose();
    occasionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            color: Colors.black87,
            fontFamily: 'Okra',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Summary Card
                  _buildServiceSummaryCard(),
                  const SizedBox(height: 24),

                  // Customer Info Section
                  _buildCustomerInfoSection(),
                  const SizedBox(height: 120), // Space for bottom button
                ],
              ),
            ),
      // Continue Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _validateAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Continue to Checkout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSummaryCard() {
    final selectedDate = widget.customizationData['date'] ?? 'Not selected';
    final selectedTime = widget.customizationData['time'] ?? 'Not selected';
    final venueType = widget.customizationData['venueType'] ?? 'Not selected';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.event_note_rounded,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Booking Summary',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Okra',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.celebration_outlined,
                  'Service',
                  widget.service.name,
                  Colors.purple,
                ),
                const SizedBox(height: 14),
                _buildSummaryRow(
                  Icons.calendar_today_rounded,
                  'Date',
                  selectedDate,
                  Colors.blue,
                ),
                const SizedBox(height: 14),
                _buildSummaryRow(
                  Icons.access_time_rounded,
                  'Time',
                  selectedTime,
                  Colors.orange,
                ),
                const SizedBox(height: 14),
                _buildSummaryRow(
                  Icons.location_on_rounded,
                  'Venue',
                  venueType,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'Okra',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Okra',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name Field (Pre-filled from profile)
          _buildInputField(
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_rounded,
            controller: customerNameController,
            isRequired: true,
          ),
          const SizedBox(height: 18),

          // Age Field (Optional)
          _buildInputField(
            label: 'Age',
            hint: 'Enter your age',
            icon: Icons.cake_rounded,
            controller: customerAgeController,
            isRequired: false,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),

          // Occasion Field (Optional)
          _buildInputField(
            label: 'Occasion',
            hint: 'e.g., Birthday, Anniversary, Wedding',
            icon: Icons.celebration_rounded,
            controller: occasionController,
            isRequired: false,
            helperText: 'This helps us prepare the perfect setup for your celebration',
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool isRequired,
    TextInputType? keyboardType,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
                color: Colors.black87,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontFamily: 'Okra',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontFamily: 'Okra',
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  helperText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'Okra',
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _validateAndContinue() {
    // Validate customer name (required)
    if (customerNameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }

    // Validate age if provided (optional but must be valid if entered)
    if (customerAgeController.text.trim().isNotEmpty) {
      final age = int.tryParse(customerAgeController.text.trim());
      if (age == null || age <= 0 || age > 120) {
        _showError('Please enter a valid age');
        return;
      }
    }

    // Add customer info to customization data
    final updatedCustomizationData = {
      ...widget.customizationData,
      'customerName': customerNameController.text.trim(),
      'customerAge': customerAgeController.text.trim().isNotEmpty
          ? int.tryParse(customerAgeController.text.trim()) ?? 0
          : null,
      'occasion': occasionController.text.trim().isNotEmpty
          ? occasionController.text.trim()
          : null,
    };

    //('✅ Navigating to checkout with booking details:');
    //('  - Customer Name: ${customerNameController.text.trim()}');
    //('  - Customer Age: ${customerAgeController.text.trim().isNotEmpty ? customerAgeController.text.trim() : "Not provided"}');
    //('  - Occasion: ${occasionController.text.trim().isNotEmpty ? occasionController.text.trim() : "Not provided"}');

    try {
      // Navigate to checkout
      context.push(
        CheckoutScreen.routeName,
        extra: {
          'service': widget.service,
          'customization': updatedCustomizationData,
          'selectedDate': widget.customizationData['date'],
          'selectedTimeSlot': null,
          'selectedScreen': null,
          'selectedAddressId': null,
          'selectedAddOns': widget.selectedAddOns,
        },
      );
    } catch (e) {
      //('❌ Navigation error: $e');
      _showError('Unable to proceed to checkout. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
