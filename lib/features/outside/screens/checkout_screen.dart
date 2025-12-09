import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';

import '../models/screen_package_model.dart';
import '../models/theater_screen_model.dart';
import '../models/time_slot_model.dart';
import '../models/addon_model.dart';
import '../providers/theater_screen_detail_providers.dart';
import '../services/razorpay_payment_service.dart';
import '../services/theater_booking_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.screen,
    required this.selectedPackage,
    required this.selectedDate,
    required this.timeSlot,
    required this.screenId,
    required this.selectedAddons,
    required this.totalAddonPrice,
    required this.selectedExtraSpecials,
    required this.totalExtraSpecialPrice,
    required this.selectedSpecialServices,
    required this.totalSpecialServicesPrice,
  });

  final TheaterScreen screen;
  final ScreenPackageModel? selectedPackage;
  final String selectedDate;
  final TimeSlotModel timeSlot;
  final String screenId;
  final List<AddonModel> selectedAddons;
  final double totalAddonPrice;
  final List<AddonModel> selectedExtraSpecials;
  final double totalExtraSpecialPrice;
  final List<AddonModel> selectedSpecialServices;
  final double totalSpecialServicesPrice;

  static const String routeName = '/checkout';

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final List<AddonModel> _selectedCakes = [];
  double _totalCakePrice = 0.0;
  int _peopleCount = 1;
  bool _isProcessingPayment = false;
  late RazorpayPaymentService _razorpayService;

  // Advance payment calculation using backend formula
  Map<String, dynamic>? advancePaymentData;
  bool isLoadingAdvancePayment = false;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayPaymentService();

    // Calculate advance payment after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAdvancePayment();
    });
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  // Calculate extra person charges
  double get _extraPersonCharges {
    final allowedCapacity = widget.screen.allowedCapacity ?? 0;
    final chargesPerPerson = widget.screen.chargesExtraPerPerson ?? 0.0;

    if (_peopleCount <= allowedCapacity || allowedCapacity == 0) return 0.0;

    final extraPeople = _peopleCount - allowedCapacity;
    return extraPeople * chargesPerPerson;
  }

  @override
  Widget build(BuildContext context) {
    final cakes = ref.watch(addonsByCategoryProvider(AddonCategoryParams(
      theaterId: widget.screen.theaterId,
      category: 'cake',
    )));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Okra',
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Summary
                  _buildBookingSummary(),
                  const SizedBox(height: 20),

                  // People Count Section
                  _buildPeopleCountSection(),
                  const SizedBox(height: 20),

                  // Cakes Section - Only show if cakes are available
                  cakes.maybeWhen(
                    data: (cakesList) {
                      if (cakesList.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          _buildCakesSection(cakes),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // Order Summary
                  _buildOrderSummary(),
                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ),

          // Bottom Payment Bar
          _buildBottomPaymentBar(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildProgressDot(true, 'Add-ons'),
          _buildProgressLine(),
          _buildProgressDot(true, 'Extra Special'),
          _buildProgressLine(),
          _buildProgressDot(true, 'Special Services'),
          _buildProgressLine(),
          _buildProgressDot(true, 'Checkout'),
        ],
      ),
    );
  }

  Widget _buildProgressDot(bool isActive, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: isActive
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: isActive ? AppTheme.primaryColor : Colors.grey[500],
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine() {
    return Container(
      height: 2,
      width: 20,
      color: Colors.grey[300],
      margin: const EdgeInsets.only(bottom: 24),
    );
  }

  Widget _buildBookingSummary() {
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
            'Booking Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Okra',
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),

          // Screen details
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.screen.images?.isNotEmpty == true
                    ? Image.network(
                        widget.screen.images!.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.theaters, color: Colors.grey),
                          );
                        },
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.theaters, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.screen.screenName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Okra',
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_seat, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.screen.allowedCapacity ?? widget.screen.capacity} Seats',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date and time
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.selectedDate))}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Color(0xFF374151),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Time: ${_formatTime(widget.timeSlot.startTime)} - ${_formatTime(widget.timeSlot.endTime)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Color(0xFF374151),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleCountSection() {
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
            'Number of People',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Okra',
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'How many people will be attending?',
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Okra',
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: _peopleCount > 1
                    ? () {
                        setState(() {
                          _peopleCount--;
                        });
                        // Recalculate advance payment when people count changes
                        _calculateAdvancePayment();
                      }
                    : null,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: _peopleCount > 1 ? AppTheme.primaryColor : Colors.grey[400],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_peopleCount',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Okra',
                    color: AppTheme.primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: _peopleCount < (widget.screen.totalCapacity ?? widget.screen.capacity)
                    ? () {
                        setState(() {
                          _peopleCount++;
                        });
                        // Recalculate advance payment when people count changes
                        _calculateAdvancePayment();
                      }
                    : null,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: _peopleCount < (widget.screen.totalCapacity ?? widget.screen.capacity)
                      ? AppTheme.primaryColor
                      : Colors.grey[400],
                ),
              ),
              const Spacer(),
              Text(
                'Max: ${widget.screen.totalCapacity ?? widget.screen.capacity}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Okra',
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // Capacity info and extra charges warning
          if ((widget.screen.allowedCapacity ?? 0) > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _peopleCount > (widget.screen.allowedCapacity ?? 0)
                    ? Colors.orange[50]
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _peopleCount > (widget.screen.allowedCapacity ?? 0)
                      ? Colors.orange[200]!
                      : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _peopleCount > (widget.screen.allowedCapacity ?? 0)
                        ? Icons.warning_amber
                        : Icons.info_outline,
                    color: _peopleCount > (widget.screen.allowedCapacity ?? 0)
                        ? Colors.orange[700]
                        : Colors.blue[700],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _peopleCount > (widget.screen.allowedCapacity ?? 0)
                          ? 'Extra charges: ₹${(widget.screen.chargesExtraPerPerson ?? 0).round()}/person beyond ${widget.screen.allowedCapacity} people'
                          : 'Package includes up to ${widget.screen.allowedCapacity} people',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Okra',
                        fontWeight: FontWeight.w500,
                        color: _peopleCount > (widget.screen.allowedCapacity ?? 0)
                            ? Colors.orange[700]
                            : Colors.blue[700],
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

  Widget _buildCakesSection(AsyncValue<List<AddonModel>> cakes) {
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
            'Add Cakes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Okra',
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Make your celebration special with delicious cakes',
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Okra',
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          cakes.when(
            data: (cakesList) {
              if (cakesList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No cakes available',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Okra',
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: cakesList.length,
                  itemBuilder: (context, index) {
                    final cake = cakesList[index];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      child: _buildCakeCard(cake),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (error, stack) => Center(
              child: Text(
                'Error loading cakes',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Okra',
                  color: Colors.red[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCakeCard(AddonModel cake) {
    final isSelected = _selectedCakes.contains(cake);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCakes.remove(cake);
            _totalCakePrice -= cake.price;
          } else {
            _selectedCakes.add(cake);
            _totalCakePrice += cake.price;
          }
        });
        // Recalculate advance payment when cakes change
        _calculateAdvancePayment();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: cake.hasImage
                      ? CachedNetworkImage(
                          imageUrl: cake.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.cake,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.cake, color: Colors.grey, size: 30),
                        ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cake.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cake.formattedPrice,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Okra',
                          color: AppTheme.primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final basePrice = widget.timeSlot.basePrice;
    final totalExtraPrice = widget.totalAddonPrice +
                          widget.totalExtraSpecialPrice +
                          widget.totalSpecialServicesPrice +
                          _totalCakePrice +
                          _extraPersonCharges;
    final grandTotal = basePrice + totalExtraPrice;

    // Get the actual total price user sees (with taxes) from advance payment data
    final totalPriceUserSees = advancePaymentData != null
        ? (advancePaymentData!['total_price_user_sees'] as num).toDouble()
        : grandTotal;

    // Calculate convenience fee (₹19 fixed tax) - we show it as "saved"
    const convenienceFee = 19.0;
    final itemTotal = totalPriceUserSees + convenienceFee;

    // Calculate advance payment
    final advanceAmount = advancePaymentData != null
        ? (advancePaymentData!['user_advance_payment'] as num).toDouble()
        : 0.0;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Okra',
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Incl. all taxes)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Okra',
                  color: Colors.grey[600],
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Item Total with strikethrough
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Total',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                    color: Colors.grey[700],
                    letterSpacing: -0.1,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '₹${_formatPrice(itemTotal)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Okra',
                        color: Colors.grey[500],
                        decoration: TextDecoration.lineThrough,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${_formatPrice(totalPriceUserSees)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Okra',
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Convenience Fee (shown as free/saved)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Convenience Fee',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                    color: Colors.grey[700],
                    letterSpacing: -0.1,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '₹${convenienceFee.round()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Okra',
                        color: Colors.grey[500],
                        decoration: TextDecoration.lineThrough,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '₹0',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Okra',
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // To Pay - Advance
          if (advancePaymentData != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'To Pay - Advance',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '₹${_formatPrice(advanceAmount)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

          // Pending amount after service
          if (advancePaymentData != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pending (After Service)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Okra',
                      color: Colors.grey[700],
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    '₹${_formatPrice((advancePaymentData!['remaining_payment'] as num).toDouble())}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      color: Colors.grey[800],
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Total Savings
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.savings_outlined, size: 18, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Total Savings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Colors.green[700],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${convenienceFee.round()}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Okra',
                    color: Colors.green[700],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cancellation Policy
          TextButton(
            onPressed: () {
              _showCancellationPolicyDialog();
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cancellation Policy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: AppTheme.primaryColor,
                    letterSpacing: -0.2,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),

          if (isLoadingAdvancePayment)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool showPrice = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 6 : 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 17 : 15,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'Okra',
              color: isTotal ? const Color(0xFF111827) : Colors.grey[600],
              letterSpacing: isTotal ? -0.3 : -0.1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 22 : 16,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w700,
              fontFamily: 'Okra',
              color: isTotal ? AppTheme.primaryColor : const Color(0xFF111827),
              letterSpacing: isTotal ? -0.5 : -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPaymentBar() {
    // Get the actual total price user sees (with taxes)
    final totalPriceUserSees = advancePaymentData != null
        ? (advancePaymentData!['total_price_user_sees'] as num).toDouble()
        : 0.0;

    // Get advance payment amount from calculation
    final advanceAmount = advancePaymentData != null
        ? (advancePaymentData!['user_advance_payment'] as num).toDouble()
        : 0.0; // Will show 0 if calculation hasn't completed yet

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Now (Advance)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                      color: Colors.grey[700],
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_formatPrice(advanceAmount)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      fontFamily: 'Okra',
                      letterSpacing: -0.8,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Total: ₹${_formatPrice(totalPriceUserSees)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isProcessingPayment ? null : _initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Okra',
                        letterSpacing: -0.3,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timeString) {
    final time = TimeOfDay.fromDateTime(
      DateTime.parse('2000-01-01 $timeString'),
    );
    return time.format(context);
  }

  void _initiatePayment() async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final grandTotal = widget.timeSlot.basePrice +
                        widget.totalAddonPrice +
                        widget.totalExtraSpecialPrice +
                        widget.totalSpecialServicesPrice +
                        _totalCakePrice +
                        _extraPersonCharges;

      // Get calculated advance payment amount
      if (advancePaymentData == null) {
        throw Exception('Payment calculation not completed. Please wait...');
      }

      final advanceAmount = (advancePaymentData!['user_advance_payment'] as num).toDouble();
      final totalPriceUserSees = (advancePaymentData!['total_price_user_sees'] as num).toDouble();
      final remainingPayment = (advancePaymentData!['remaining_payment'] as num).toDouble();

      print('📊 Payment Details:');
      print('  Total Price (with taxes): ₹${_formatPrice(totalPriceUserSees)}');
      print('  Advance Payment: ₹${_formatPrice(advanceAmount)}');
      print('  Remaining Payment: ₹${_formatPrice(remainingPayment)}');

      // For testing without backend, we'll skip order creation
      final orderId = 'test_order_${DateTime.now().millisecondsSinceEpoch}';

      // Create booking first (with pending status)
      print('🎬 Creating theater booking...');
      final bookingService = ref.read(theaterBookingServiceProvider);
      final bookingId = await bookingService.createPrivateTheaterBooking(
        userId: user.id,
        screen: widget.screen,
        timeSlot: widget.timeSlot,
        selectedDate: widget.selectedDate,
        peopleCount: _peopleCount,
        totalAmount: grandTotal,
        selectedAddons: widget.selectedAddons,
        selectedExtraSpecials: widget.selectedExtraSpecials,
        selectedSpecialServices: widget.selectedSpecialServices,
        selectedCakes: _selectedCakes,
        selectedPackage: widget.selectedPackage,
      );
      print('✅ Booking created with ID: $bookingId');

      // Create time slot booking
      print('📅 Creating time slot booking...');
      await bookingService.createTimeSlotBooking(
        timeSlotId: widget.timeSlot.id,
        selectedDate: widget.selectedDate,
      );
      print('✅ Time slot booking created');

      // Initiate Razorpay payment with advance amount
      print('💳 Initiating payment for ₹${advanceAmount.round()}...');
      await _razorpayService.initiatePayment(
        amount: advanceAmount, // Pay calculated advance amount
        orderId: orderId,
        customerName: user.email?.split('@').first ?? user.phone ?? 'User',
        customerEmail: user.email ?? 'user@example.com',
        customerPhone: user.phone ?? '+919999999999',
        description: 'Theater booking for ${widget.screen.screenName} (Advance payment)',
        onSuccess: (PaymentSuccessResponse response) {
          _handlePaymentSuccess(response, bookingId, bookingService, grandTotal, advanceAmount);
        },
        onError: (PaymentFailureResponse response) {
          _handlePaymentError(response, bookingId, bookingService);
        },
        onExternalWallet: (ExternalWalletResponse response) {
          print('External wallet selected: ${response.walletName}');
        },
      );

    } catch (e) {
      print('❌ Booking error: $e');
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        _showErrorDialog('Booking failed: ${e.toString()}');
      }
    }
  }

  void _handlePaymentSuccess(
    PaymentSuccessResponse response,
    String bookingId,
    TheaterBookingService bookingService,
    double grandTotal,
    double advanceAmount,
  ) async {
    try {
      print('✅ Payment successful! Payment ID: ${response.paymentId}');

      // Get payment calculation values
      final userAdvancePayment = advancePaymentData != null
          ? (advancePaymentData!['user_advance_payment'] as num).toDouble()
          : advanceAmount;

      final remainingPayment = advancePaymentData != null
          ? (advancePaymentData!['remaining_payment'] as num).toDouble()
          : grandTotal - advanceAmount;

      final totalVendorPayout = advancePaymentData != null
          ? (advancePaymentData!['total_vendor_payout'] as num).toDouble()
          : grandTotal * 0.95; // Fallback: 95% of total (5% commission)

      print('📊 Payment Breakdown:');
      print('  User Advance Payment: ₹${userAdvancePayment.toStringAsFixed(2)}');
      print('  Remaining Payment: ₹${remainingPayment.toStringAsFixed(2)}');
      print('  Admin Payout (to vendor): ₹${totalVendorPayout.toStringAsFixed(2)}');

      // Update booking with payment details and calculated amounts
      // Note: payment_status stays 'pending' for remaining payment (allowed: pending, paid, failed, refunded)
      // We keep it as 'pending' to indicate the remaining payment is still due
      await bookingService.updateBookingStatus(
        bookingId: bookingId,
        bookingStatus: 'confirmed',
        paymentStatus: 'pending', // Keep as pending since remaining payment is still due (no 'partial' option)
        paymentId: response.paymentId,
        userAdvancePayment: userAdvancePayment,
        pendingAmount: remainingPayment,
        adminPayout: totalVendorPayout,
      );
      print('✅ Booking status updated to confirmed with advance payment details');

      // Mark time slot as booked
      await bookingService.markTimeSlotAsBooked(
        widget.timeSlot.id,
        widget.selectedDate,
      );
      print('✅ Time slot marked as booked');

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        _showSuccessDialog(grandTotal, advanceAmount);
      }
    } catch (e) {
      print('❌ Error updating booking after payment success: $e');
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        _showErrorDialog('Payment successful but booking update failed. Please contact support.');
      }
    }
  }

  void _handlePaymentError(
    PaymentFailureResponse response,
    String bookingId,
    TheaterBookingService bookingService,
  ) async {
    try {
      // Update booking as cancelled (since 'failed' is not allowed by the constraint)
      await bookingService.updateBookingStatus(
        bookingId: bookingId,
        bookingStatus: 'cancelled',
        paymentStatus: 'failed',
      );

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        _showErrorDialog('Payment failed: ${response.message ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error updating booking after payment failure: $e');
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        _showErrorDialog('Payment failed: ${response.message ?? 'Unknown error'}');
      }
    }
  }

  void _showSuccessDialog(double grandTotal, double advanceAmount) {
    final remainingAmount = advancePaymentData != null
        ? (advancePaymentData!['remaining_payment'] as num).toDouble()
        : grandTotal - advanceAmount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Okra',
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your theater booking has been confirmed',
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Okra',
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Payment info container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paid Now (Advance):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontFamily: 'Okra',
                        ),
                      ),
                      Text(
                        '₹${_formatPrice(advanceAmount)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'After Service:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontFamily: 'Okra',
                        ),
                      ),
                      Text(
                        '₹${_formatPrice(remainingAmount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange[700],
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Go to Home',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Okra',
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Okra',
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Okra',
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Okra',
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _initiatePayment();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Okra',
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate advance payment using Supabase RPC
  /// This calls the calculate_advance_payment RPC function with the correct formula
  Future<void> _calculateAdvancePayment() async {
    setState(() {
      isLoadingAdvancePayment = true;
    });

    try {
      final basePrice = widget.timeSlot.basePrice;
      final addonsTotal = widget.totalAddonPrice +
                          widget.totalExtraSpecialPrice +
                          widget.totalSpecialServicesPrice +
                          _totalCakePrice +
                          _extraPersonCharges;

      print('🧮 Calculating advance payment...');
      print('  Base Price: ₹${basePrice.round()}');
      print('  Add-ons Total (including extra person charges): ₹${addonsTotal.round()}');

      // Get theater owner's vendor_id
      final theaterResponse = await Supabase.instance.client
          .from('private_theaters')
          .select('owner_id')
          .eq('id', widget.screen.theaterId)
          .maybeSingle();

      if (theaterResponse == null) {
        throw Exception('Theater not found');
      }

      final ownerId = theaterResponse['owner_id'] as String?;
      if (ownerId == null) {
        throw Exception('Theater has no owner assigned');
      }

      // Get user_profiles id from owner_id (auth.users.id)
      final profileResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('id', ownerId)
          .maybeSingle();

      if (profileResponse == null) {
        // If no profile found, calculate with default values
        print('⚠️ No vendor profile found, using default calculation');
        final result = _calculateWithDefaultFormula(basePrice, addonsTotal);

        if (mounted) {
          setState(() {
            advancePaymentData = result;
            isLoadingAdvancePayment = false;
          });
        }
        return;
      }

      final vendorId = profileResponse['id'] as String;
      print('  Vendor ID: $vendorId');

      // Back-calculate raw base price from final price for RPC call
      // basePrice is already the final price (₹1299), but RPC expects raw price (₹1200)
      // finalPrice = rawBase + 19 + (rawBase * 3.54/100)
      // rawBase = (finalPrice - 19) / 1.0354
      final rawServiceBase = (basePrice - 19) / (1 + 3.54 / 100);
      print('  Raw service base (for RPC): ₹${rawServiceBase.round()}');

      // Call the Supabase RPC function with RAW prices
      final response = await Supabase.instance.client.rpc(
        'calculate_advance_payment',
        params: {
          'p_vendor_id': vendorId,
          'p_service_discounted_price': rawServiceBase,
          'p_addons_discounted_price': addonsTotal,
        },
      );

      if (mounted) {
        setState(() {
          advancePaymentData = response as Map<String, dynamic>;
          isLoadingAdvancePayment = false;
        });
        print('✅ Advance payment calculated:');
        print('  Service with taxes: ₹${(response as Map<String, dynamic>)['service_with_all_taxes']}');
        print('  Addons with taxes: ₹${response['addons_with_all_taxes']}');
        print('  Total price user sees: ₹${response['total_price_user_sees']}');
        print('  Commission: ₹${response['commission']}');
        print('  Total commission (incl GST): ₹${response['total_commission']}');
        print('  Total vendor payout: ₹${response['total_vendor_payout']}');
        print('  User advance payment: ₹${response['user_advance_payment']}');
        print('  Remaining payment: ₹${response['remaining_payment']}');
      }
    } catch (e) {
      print('⚠️ Error calculating advance payment: $e');
      // Fallback to formula with default values
      final basePrice = widget.timeSlot.basePrice;
      final addonsTotal = widget.totalAddonPrice +
                          widget.totalExtraSpecialPrice +
                          widget.totalSpecialServicesPrice +
                          _totalCakePrice +
                          _extraPersonCharges;

      final result = _calculateWithDefaultFormula(basePrice, addonsTotal);

      if (mounted) {
        setState(() {
          advancePaymentData = result;
          isLoadingAdvancePayment = false;
        });
      }
    }
  }

  /// Calculate advance payment with default formula values
  /// This replicates the backend formula with default constants
  /// IMPORTANT: serviceFinalPrice is already the final price (with taxes applied in detail screen)
  ///
  /// Formula breakdown:
  /// S = raw service base price (back-calculated from serviceFinalPrice)
  /// A = addons price
  /// F = fixed tax (₹19)
  /// T = percent tax (3.54%)
  /// C = commission percent (5%)
  /// G = commission GST (18%)
  /// adv = advance factor (40%)
  ///
  /// totalPriceUserSees = applyFinalRounding((S + F + S*T/100) + (A + A*T/100))
  /// x = totalPriceUserSees - round2(totalPriceUserSees - ((S + A) - (((S + A) * C/100) * (1 + G/100))) * adv/100)
  Map<String, dynamic> _calculateWithDefaultFormula(double serviceFinalPrice, double addonsPrice) {
    // Constants from the backend formula
    const fixedTax = 19.00; // F
    const percentTax = 3.54; // T
    const commissionPercent = 5.00; // C
    const commissionGstPercent = 18.00; // G
    const advanceFactor = 40.00; // adv

    // Step 1: Back-calculate raw service base price (S) from final price
    // serviceFinalPrice = S + 19 + (S * 3.54/100)
    // serviceFinalPrice = S * 1.0354 + 19
    // S = (serviceFinalPrice - 19) / 1.0354
    final S = (serviceFinalPrice - fixedTax) / (1 + percentTax / 100);
    final A = addonsPrice;

    // Step 2: Calculate service with all taxes (already done in detail screen, but kept for clarity)
    final serviceWithTax = serviceFinalPrice; // S + F + S*(T/100)

    // Step 3: Calculate add-ons with all taxes
    final addonsWithTaxRaw = A + (A * percentTax / 100); // A + A*(T/100)
    final addonsWithTax = PriceRounding.applyFinalRounding(addonsWithTaxRaw);

    // Step 4: Total price user sees
    // totalPriceUserSees = applyFinalRounding((S + F + S*T/100) + (A + A*T/100))
    final totalPriceUserSeesRaw = serviceWithTax + addonsWithTax;
    final totalPriceUserSees = PriceRounding.applyFinalRounding(totalPriceUserSeesRaw);

    // Step 5: Calculate commission on raw prices
    // commission = (S + A) * (C/100)
    final commission = (S + A) * (commissionPercent / 100);

    // Step 6: Total commission with GST
    // total_commission = commission * (1 + G/100)
    final totalCommission = commission * (1 + commissionGstPercent / 100);

    // Step 7: Vendor payout
    // vendor_payout = (S + A) - total_commission
    final totalVendorPayout = (S + A) - totalCommission;

    // Step 8: User advance payment using exact formula
    // x = totalPriceUserSees - round2(totalPriceUserSees - (vendor_payout * adv/100))
    // Expected output shows: User advance = 847.32, Remaining = totalPrice - advance
    // So advance = totalPriceUserSees - (vendor_payout * adv/100)
    // Keep decimal precision, don't round the advance payment itself
    final vendorPayoutPercentage = totalVendorPayout * (advanceFactor / 100);
    final userAdvancePayment = totalPriceUserSees - vendorPayoutPercentage;

    // Step 9: Remaining payment (what user pays after service)
    final remainingPayment = totalPriceUserSees - userAdvancePayment;

    return {
      'service_with_all_taxes': serviceWithTax,
      'addons_with_all_taxes': addonsWithTax,
      'commission': commission,
      'total_commission': totalCommission,
      'total_vendor_payout': totalVendorPayout,
      'total_price_user_sees': totalPriceUserSees,
      'user_advance_payment': userAdvancePayment,
      'remaining_payment': remainingPayment,
    };
  }

  /// Smart rounding: Round up if decimal > 0.49, otherwise keep decimal
  String _formatPrice(double price) {
    final decimal = price - price.floor();
    if (decimal > 0.49) {
      return price.ceil().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  /// Show cancellation policy dialog
  void _showCancellationPolicyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cancellation Policy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Refunds are subject to the time of cancellation before the scheduled service:',
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRefundTable(),
                const SizedBox(height: 16),
                const Text(
                  'Additional Terms:',
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRefundTerms(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontFamily: 'Okra',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRefundTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Time Before Service',
                    style: TextStyle(
                      fontFamily: 'Okra',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Refund Amount',
                    style: TextStyle(
                      fontFamily: 'Okra',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildTableRow('More than 24 Hours', '50%'),
          _buildTableRow('24 to 12 Hours', '30%'),
          _buildTableRow('12 to 6 Hours', '17%'),
          _buildTableRow('Less than 6 Hours', 'No Refund'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String time, String refundAmount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              time,
              style: const TextStyle(fontFamily: 'Okra', fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              refundAmount,
              style: const TextStyle(fontFamily: 'Okra', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundTerms() {
    const terms = [
      '• Refunds will be processed within 5-7 working days.',
      '• Refund will be credited to the original payment method used during booking.',
      '• Service charges and transaction fees are non-refundable.',
      '• In case of any disputes, the decision of Sylonow management will be final.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: terms
          .map(
            (term) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                term,
                style: const TextStyle(
                  fontFamily: 'Okra',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}