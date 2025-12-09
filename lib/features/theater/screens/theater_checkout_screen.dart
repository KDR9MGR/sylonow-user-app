import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';
import 'package:sylonow_user/features/theater/models/occasion_model.dart';
import 'package:sylonow_user/features/theater/models/selected_add_on_model.dart';
import 'package:sylonow_user/features/theater/providers/theater_providers.dart';

// Get Supabase client instance
final supabase = Supabase.instance.client;

class TheaterCheckoutScreen extends ConsumerStatefulWidget {
  static const String routeName = '/theater/checkout';

  final String theaterId;
  final String selectedDate;
  final Map<String, dynamic> selectionData;

  const TheaterCheckoutScreen({
    super.key,
    required this.theaterId,
    required this.selectedDate,
    required this.selectionData,
  });

  @override
  ConsumerState<TheaterCheckoutScreen> createState() =>
      _TheaterCheckoutScreenState();
}

class _TheaterCheckoutScreenState extends ConsumerState<TheaterCheckoutScreen> {
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;
  bool _isBillDetailsExpanded = false;

  // Form controllers and state
  final TextEditingController _celebrationNameController =
      TextEditingController();
  int _numberOfPeople = 2;
  bool _wantsDecoration = true;

  // ValueNotifier for forcing UI updates
  late final ValueNotifier<int> _peopleCountNotifier;

  // Local state for managing selected items with quantities
  final Map<String, Map<String, dynamic>> _selectedAddOns = {};
  final Map<String, Map<String, dynamic>> _selectedSpecialServices = {};

  bool _looksLikeUuid(String? value) {
    if (value == null) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value);
  }

  bool _timesMatch(String time1, String time2) {
    // Normalize both time strings to HH:mm:ss format for comparison
    String normalizeTime(String time) {
      if (time.length == 5 && !time.contains(':')) {
        // Handle HHMM format
        return '${time.substring(0, 2)}:${time.substring(2)}:00';
      } else if (time.length == 8 && time.contains(':')) {
        // Already in HH:mm:ss format
        return time;
      } else if (time.length == 5 && time.contains(':')) {
        // HH:mm format, add seconds
        return '$time:00';
      }
      return time; // Return as-is if format is unclear
    }

    final normalized1 = normalizeTime(time1);
    final normalized2 = normalizeTime(time2);
    debugPrint(
      '🧾 Time comparison: "$time1" -> "$normalized1" vs "$time2" -> "$normalized2"',
    );
    return normalized1 == normalized2;
  }

  // Resolved screen data when only screenId/name are passed in selection
  Map<String, dynamic>? _resolvedScreenData;

  // Get screen information for capacity and pricing
  Map<String, dynamic> get _screenInfo {
    // Try to get screen info from selection data first
    if (widget.selectionData['selectedScreen'] != null) {
      final screenData =
          widget.selectionData['selectedScreen'] as Map<String, dynamic>;
      debugPrint('📺 Using selected screen data: $screenData');
      return screenData;
    }

    // Use resolved screen data if we fetched by screenId
    if (_resolvedScreenData != null) {
      debugPrint('📺 Using resolved screen data: $_resolvedScreenData');
      return _resolvedScreenData!;
    }

    // Try to extract screen info from the selected time slot
    final dynamic selectedSlot = widget.selectionData['selectedTimeSlot'];
    if (selectedSlot is Map<String, dynamic>) {
      final screenInfo = <String, dynamic>{};

      // Extract capacity information
      if (selectedSlot['screen_capacity'] != null) {
        screenInfo['capacity'] = selectedSlot['screen_capacity'];
      } else if (selectedSlot['capacity'] != null) {
        screenInfo['capacity'] = selectedSlot['capacity'];
      }

      // Extract allowed capacity
      if (selectedSlot['allowed_capacity'] != null) {
        screenInfo['allowed_capacity'] = selectedSlot['allowed_capacity'];
      } else if (selectedSlot['total_capacity'] != null) {
        screenInfo['allowed_capacity'] = selectedSlot['total_capacity'];
      }

      // Extract extra charges per person
      if (selectedSlot['charges_extra_per_person'] != null) {
        screenInfo['charges_extra_per_person'] =
            selectedSlot['charges_extra_per_person'];
      }

      // Extract hourly rate
      if (selectedSlot['hourly_rate'] != null) {
        screenInfo['hourly_rate'] = selectedSlot['hourly_rate'];
      } else if (selectedSlot['price_per_hour'] != null) {
        screenInfo['hourly_rate'] = selectedSlot['price_per_hour'];
      } else if (selectedSlot['final_price'] != null) {
        screenInfo['hourly_rate'] = selectedSlot['final_price'];
      }

      if (screenInfo.isNotEmpty) {
        debugPrint(
          '📺 Using screen data extracted from time slot: $screenInfo',
        );
        return screenInfo;
      }
    }

    // Fallback to theater capacity if no screen selected
    final theaterAsync = ref.read(theaterProvider(widget.theaterId));
    final theater = theaterAsync.value;
    final theaterCapacity = theater?.capacity ?? 20;
    final fallbackData = {
      'capacity': theaterCapacity > 0 ? theaterCapacity : 20,
      'allowed_capacity': 2, // Default base capacity
      'charges_extra_per_person': 0.0, // Default no extra charge
    };
    debugPrint(
      '📺 Using fallback screen data: $fallbackData (theater capacity: $theaterCapacity)',
    );
    return fallbackData;
  }

  // Get max allowed people from screen data
  int get _maxAllowedPeople {
    final capacity = _screenInfo['capacity'];
    if (capacity is int) {
      return capacity;
    } else if (capacity is num) {
      return capacity.toInt();
    } else if (capacity is String) {
      return int.tryParse(capacity) ?? 20;
    }
    return 20;
  }

  // Get base allowed capacity (included in base price)
  int get _baseAllowedCapacity {
    final capacity = _screenInfo['allowed_capacity'];
    if (capacity is int) {
      return capacity;
    } else if (capacity is num) {
      return capacity.toInt();
    } else if (capacity is String) {
      return int.tryParse(capacity) ?? 2;
    }
    return 2;
  }

  // Get extra charge per person beyond base capacity
  double get _extraChargePerPerson {
    final charges = _screenInfo['charges_extra_per_person'];
    double result = 0.0;

    if (charges is num) {
      result = charges.toDouble();
    } else if (charges is String) {
      result = double.tryParse(charges) ?? 0.0;
    }

    // debugPrint(
    //   '💰 Extra charge per person: ₹$result (base capacity: $_baseAllowedCapacity, max: $_maxAllowedPeople)',
    // );
    return result;
  }

  @override
  void initState() {
    super.initState();
    _peopleCountNotifier = ValueNotifier(_numberOfPeople);
    _razorpay = Razorpay();

    // Set up event handlers using function references (recommended by Razorpay docs)
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Initialize selected items from widget data
    _initializeSelectedItems();

    // Resolve full screen details if only screenId/name were provided
    try {
      final dynamic maybeSelectedScreen =
          widget.selectionData['selectedScreen'];
      final String? maybeScreenId = widget.selectionData['screenId'] as String?;
      if (maybeSelectedScreen == null && maybeScreenId != null) {
        final screensAsync = ref.read(theaterScreensProvider(widget.theaterId));
        screensAsync.whenData((screens) {
          final match = screens.where((s) => s.id == maybeScreenId).toList();
          if (match.isNotEmpty) {
            final s = match.first;
            setState(() {
              _resolvedScreenData = {
                'id': s.id,
                'screen_name': s.screenName,
                'capacity': (s.capacity <= 0)
                    ? (s.allowedCapacity + 10)
                    : s.capacity, // Use allowed_capacity + buffer if capacity is 0
                'allowed_capacity': s.allowedCapacity,
                'charges_extra_per_person': s.chargesExtraPerPerson,
                'hourly_rate': s.hourlyRate,
              };
            });
            debugPrint(
              '🧾 Resolved screen data for screenId $maybeScreenId: $_resolvedScreenData',
            );
          }
        });
      }
    } catch (_) {}
  }

  void _initializeSelectedItems() {
    // Initialize add-ons
    if (widget.selectionData['selectedAddOns'] != null) {
      final List<dynamic> addOns = widget.selectionData['selectedAddOns'];
      for (var addOn in addOns) {
        if (addOn is Map<String, dynamic>) {
          final id = addOn['id'] ?? addOn['name'] ?? 'unknown';
          final quantity = (addOn['quantity'] is int)
              ? addOn['quantity'] as int
              : 1;
          _selectedAddOns[id.toString()] = {...addOn, 'quantity': quantity};
        } else if (addOn is SelectedAddOnModel) {
          final id = addOn.id;
          _selectedAddOns[id] = {
            'id': addOn.id,
            'name': addOn.name,
            'price': addOn.addOn.price,
            'image': addOn.imageUrl,
            'quantity': addOn.quantity,
            'category': addOn.category,
          };
        }
      }
    }

    // Initialize special services
    if (widget.selectionData['selectedSpecialServices'] != null) {
      final List<dynamic> services =
          widget.selectionData['selectedSpecialServices'];
      for (var service in services) {
        if (service is Map<String, dynamic>) {
          final id = service['id'] ?? service['name'] ?? 'unknown';
          final quantity = (service['quantity'] is int)
              ? service['quantity'] as int
              : 1;
          _selectedSpecialServices[id.toString()] = {
            ...service,
            'quantity': quantity,
          };
        } else if (service is SelectedAddOnModel) {
          final id = service.id;
          _selectedSpecialServices[id] = {
            'id': service.id,
            'name': service.name,
            'price': service.addOn.price,
            'image': service.imageUrl,
            'quantity': service.quantity,
            'category': service.category,
          };
        }
      }
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _celebrationNameController.dispose();
    _peopleCountNotifier.dispose();
    super.dispose();
  }

  // Pricing calculations for Indian taxation
  double get _slotPrice {
    // Get real slot price from the selected time slot
    final dynamic selectedSlot = widget.selectionData['selectedTimeSlot'];

    // Debug logging to understand the data structure
    debugPrint(
      '🧾 _slotPrice - selectedSlot type: ${selectedSlot.runtimeType}',
    );
    debugPrint('🧾 _slotPrice - selectedSlot value: $selectedSlot');

    // Try to extract price from the selected slot object
    if (selectedSlot is Map<String, dynamic>) {
      // Check for base_price field (new screen-based system)
      if (selectedSlot['base_price'] != null) {
        final price = selectedSlot['base_price'];
        debugPrint('🧾 Found base_price: $price');
        if (price is num) return price.toDouble();
        if (price is String) {
          final parsedPrice = double.tryParse(price);
          if (parsedPrice != null) return parsedPrice;
        }
      }

      // Check for final_price field (direct query system)
      if (selectedSlot['final_price'] != null) {
        final price = selectedSlot['final_price'];
        debugPrint('🧾 Found final_price: $price');
        if (price is num) return price.toDouble();
        if (price is String) {
          final parsedPrice = double.tryParse(price);
          if (parsedPrice != null) return parsedPrice;
        }
      }

      // Check for slot_price field (legacy system)
      if (selectedSlot['slot_price'] != null) {
        final price = selectedSlot['slot_price'];
        debugPrint('🧾 Found slot_price: $price');
        if (price is num) return price.toDouble();
        if (price is String) {
          final parsedPrice = double.tryParse(price);
          if (parsedPrice != null) return parsedPrice;
        }
      }

      // Check for price_per_hour field
      if (selectedSlot['price_per_hour'] != null) {
        final price = selectedSlot['price_per_hour'];
        debugPrint('🧾 Found price_per_hour: $price');
        if (price is num) return price.toDouble();
        if (price is String) {
          final parsedPrice = double.tryParse(price);
          if (parsedPrice != null) return parsedPrice;
        }
      }

      // Check for original_hourly_price field
      if (selectedSlot['original_hourly_price'] != null) {
        final price = selectedSlot['original_hourly_price'];
        debugPrint('🧾 Found original_hourly_price: $price');
        if (price is num) return price.toDouble();
        if (price is String) {
          final parsedPrice = double.tryParse(price);
          if (parsedPrice != null) return parsedPrice;
        }
      }
    }

    // Fallback to slotPrice in selectionData
    if (widget.selectionData['slotPrice'] != null) {
      final price = widget.selectionData['slotPrice'];
      debugPrint('🧾 Found slotPrice in selectionData: $price');
      if (price is num) return price.toDouble();
      if (price is String) {
        final parsedPrice = double.tryParse(price);
        if (parsedPrice != null) return parsedPrice;
      }
    }

    // Log warning if no price found
    debugPrint(
      '🧾 WARNING: No valid price found in selectedTimeSlot data, using default 1500.0',
    );
    debugPrint(
      '🧾 Available keys in selectionData: ${widget.selectionData.keys.toList()}',
    );

    // Default fallback - use a reasonable default instead of hardcoded value
    return 1500.0;
  }

  double get _addOnsPrice {
    double total = 0.0;

    // Calculate add-ons price from local state
    for (var addOn in _selectedAddOns.values) {
      double price = 0.0;
      int quantity = 1;

      // Extract price from the add-on data
      if (addOn['price'] != null) {
        final priceValue = addOn['price'];
        if (priceValue is num) {
          price = priceValue.toDouble();
        } else if (priceValue is String) {
          price = double.tryParse(priceValue) ?? 0.0;
        }
      }

      // Extract quantity from the add-on data
      if (addOn['quantity'] != null) {
        final qtyValue = addOn['quantity'];
        if (qtyValue is int) {
          quantity = qtyValue;
        } else if (qtyValue is String) {
          quantity = int.tryParse(qtyValue) ?? 1;
        }
      }

      total += price * quantity;
    }

    // Calculate special services price from local state
    for (var service in _selectedSpecialServices.values) {
      double price = 0.0;
      int quantity = 1;

      // Extract price from the service data
      if (service['price'] != null) {
        final priceValue = service['price'];
        if (priceValue is num) {
          price = priceValue.toDouble();
        } else if (priceValue is String) {
          price = double.tryParse(priceValue) ?? 0.0;
        }
      }

      // Extract quantity from the service data
      if (service['quantity'] != null) {
        final qtyValue = service['quantity'];
        if (qtyValue is int) {
          quantity = qtyValue;
        } else if (qtyValue is String) {
          quantity = int.tryParse(qtyValue) ?? 1;
        }
      }

      total += price * quantity;
    }

    return total;
  }

  // Calculate extra person charges
  double get _extraPersonCharges {
    if (_numberOfPeople <= _baseAllowedCapacity) {
      return 0.0; // No extra charge if within base capacity
    }

    final extraPeople = _numberOfPeople - _baseAllowedCapacity;
    final charges = extraPeople * _extraChargePerPerson;
    debugPrint(
      '🎯 Extra person charges: $_numberOfPeople people, $extraPeople extra, ₹$_extraChargePerPerson per person = ₹$charges',
    );
    return charges;
  }

  double get _subtotal {
    final subtotal = _slotPrice + _addOnsPrice + _extraPersonCharges;
    debugPrint(
      '🧮 Subtotal calculation: slot(₹$_slotPrice) + addons(₹$_addOnsPrice) + extra(₹$_extraPersonCharges) = ₹$subtotal',
    );
    return subtotal;
  }

  double get _serviceCharge {
    // Service charge of 2.5% (like Swiggy/Zomato)
    return _subtotal * 0.025;
  }

  double get _handlingFee {
    // Fixed handling fee
    return 25.0;
  }

  double get _taxableAmount {
    return _subtotal + _serviceCharge + _handlingFee;
  }

  double get _gstAmount {
    // GST 18% for entertainment services in India
    final gstRaw = _taxableAmount * 0.18;
    // Apply rounding to ensure GST amount ends with 49 or 99
    return PriceRounding.applyFinalRounding(gstRaw);
  }

  double get _totalAmount {
    final totalRaw = _taxableAmount + _gstAmount;
    // Apply rounding to ensure total amount ends with 49 or 99
    final total = PriceRounding.applyFinalRounding(totalRaw);
    debugPrint(
      '🎯 Total amount calculation: ₹$total (taxable: ₹$_taxableAmount, gst: ₹$_gstAmount)',
    );
    return total;
  }

  // 60% advance payment calculation
  double get _advanceAmount {
    final advanceRaw = _totalAmount * 0.6;
    // Apply rounding to ensure advance payment ends with 49 or 99
    final advance = PriceRounding.applyFinalRounding(advanceRaw);
    debugPrint(
      '💰 Advance payment calculation: 60% of ₹$_totalAmount = ₹$advance',
    );
    return advance;
  }

  // Remaining amount after advance payment
  double get _remainingAmount {
    final remainingRaw = _totalAmount - _advanceAmount;
    // Apply rounding to ensure remaining amount ends with 49 or 99
    return PriceRounding.applyFinalRounding(remainingRaw);
  }

  double get _savings {
    // Show savings for user psychology
    double originalPriceRaw = _slotPrice * 1.2; // Assume 20% markup on original
    final originalPrice = PriceRounding.applyFinalRounding(originalPriceRaw);
    final savingsRaw = originalPrice - _slotPrice;
    // Apply rounding to savings display
    return PriceRounding.applyFinalRounding(savingsRaw);
  }

  Future<void> _notifyVendor(String bookingId) async {
    try {
      final dynamic selectedOccasion = widget.selectionData['selectedOccasion'];
      String? occasionName;

      if (selectedOccasion is OccasionModel) {
        occasionName = selectedOccasion.name;
      } else if (selectedOccasion is Map<String, dynamic>) {
        occasionName =
            selectedOccasion['name']?.toString() ??
            selectedOccasion['title']?.toString() ??
            selectedOccasion['occasion']?.toString() ??
            selectedOccasion['label']?.toString();
      } else if (selectedOccasion is String) {
        occasionName = selectedOccasion;
      }

      final dynamic selectedSlot = widget.selectionData['selectedTimeSlot'];
      String startTime = '00:00';
      String endTime = '00:00';

      // Extract time information from slot data
      if (selectedSlot is Map<String, dynamic>) {
        startTime = selectedSlot['start_time']?.toString() ?? startTime;
        endTime = selectedSlot['end_time']?.toString() ?? endTime;
      } else if (selectedSlot is String && selectedSlot.contains('-')) {
        final parts = selectedSlot.split('-');
        startTime = parts[0].trim();
        endTime = parts.length > 1 ? parts[1].trim() : endTime;
      }

      final user = supabase.auth.currentUser;
      final celebrationName = _celebrationNameController.text.trim();
      final customerName =
          user?.userMetadata?['full_name']?.toString() ??
          user?.email?.split('@').first ??
          (celebrationName.isNotEmpty ? celebrationName : 'Customer');

      // Get theater owner's auth_user_id for vendor lookup
      String? vendorAuthId;
      try {
        final theaterResp = await supabase
            .from('private_theaters')
            .select('owner_id')
            .eq('id', widget.theaterId)
            .maybeSingle();
        vendorAuthId = theaterResp?['owner_id'] as String?;
      } catch (e) {
        debugPrint('⚠️ Failed to get theater owner: $e');
      }

      final notificationPayload = {
        'booking_id': bookingId,
        'theater_id': widget.theaterId,
        'vendor_id':
            vendorAuthId, // Remove fallback to user?.id as this should be theater owner
        'customer_name': customerName,
        'booking_date': widget.selectedDate.contains('T')
            ? widget.selectedDate.split('T')[0]
            : widget.selectedDate,
        'start_time': startTime,
        'end_time': endTime,
        'total_amount': _totalAmount,
        'occasion_name': occasionName,
        'number_of_people': _numberOfPeople,
      };

      // Only send notification if we have a valid vendor ID
      if (vendorAuthId != null && vendorAuthId.isNotEmpty) {
        debugPrint('📱 Sending vendor notification: $notificationPayload');

        final response = await supabase.functions.invoke(
          'notify-vendor-booking',
          body: notificationPayload,
        );

        if (response.status != 200) {
          debugPrint('⚠️ Failed to send vendor notification: ${response.data}');
        } else {
          debugPrint(
            '✅ Vendor notification sent successfully: ${response.data}',
          );
        }
      } else {
        debugPrint('⚠️ No vendor ID found, skipping notification');
      }
    } catch (e) {
      debugPrint('⚠️ Error sending vendor notification: $e');
      // Don't throw error as this shouldn't block the booking flow
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _isProcessingPayment = false;
    });

    debugPrint('🎉 Payment Success!');
    debugPrint('💳 Payment ID: ${response.paymentId}');
    debugPrint('📋 Order ID: ${response.orderId}');
    debugPrint('🔑 Signature: ${response.signature}');
    debugPrint('💰 Amount paid: ₹${_advanceAmount.toStringAsFixed(2)}');

    // Validate payment response according to Razorpay documenta tion
    if (response.paymentId == null || response.paymentId!.isEmpty) {
      debugPrint('❌ Invalid payment response: Missing payment ID');
      _handlePaymentError(
        PaymentFailureResponse(
          1,
          'Invalid payment response received - missing payment ID',
          {'error': 'INVALID_PAYMENT_ID'},
        ),
      );
      return;
    }

    // Additional validation for signature (recommended by Razorpay)
    if (response.signature == null || response.signature!.isEmpty) {
      debugPrint(
        '⚠️ Warning: Payment signature is missing - this may indicate a security issue',
      );
    }

    try {
      // Show immediate success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment successful! Processing your booking...',
              style: TextStyle(fontFamily: 'Okra'),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Save booking to Supabase
      debugPrint('💾 Starting database save...');
      final bookingId = await _saveBookingToDatabase(response.paymentId);
      debugPrint('✅ Database save completed successfully');

      // Send notification to vendor (don't block on this)
      debugPrint('📱 Starting vendor notification...');
      _notifyVendor(bookingId).catchError((e) {
        debugPrint('⚠️ Vendor notification failed: $e');
      });
      debugPrint('✅ Vendor notification initiated');

      // Show final success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking confirmed! You will receive a confirmation shortly.',
              style: TextStyle(fontFamily: 'Okra'),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to home after a brief delay to show success message
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            // Check auth state before navigation to prevent login redirect
            final user = supabase.auth.currentUser;
            if (user != null) {
              context.go('/');
            } else {
              debugPrint(
                '⚠️ User authentication lost, staying on current screen',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Booking completed! Please refresh the app to see your bookings.',
                    style: TextStyle(fontFamily: 'Okra'),
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error in payment success handler: $e');
      debugPrint('❌ Error stack trace: ${StackTrace.current}');

      if (mounted) {
        // Clear any existing snackbars
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show error message but still navigate since payment was successful
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment successful but booking save failed. Please contact support with Payment ID: ${response.paymentId}',
              style: const TextStyle(fontFamily: 'Okra'),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Copy ID',
              textColor: Colors.white,
              onPressed: () {
                // Copy payment ID to clipboard for support
                debugPrint(
                  'User requested to copy Payment ID: ${response.paymentId}',
                );
              },
            ),
          ),
        );

        // Navigate to home after showing error message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Check auth state before navigation to prevent login redirect
            final user = supabase.auth.currentUser;
            if (user != null) {
              context.go('/');
            } else {
              debugPrint(
                '⚠️ User authentication lost, staying on current screen',
              );
            }
          }
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessingPayment = false;
    });

    debugPrint(
      '❌ Payment Error - Code: ${response.code}, Message: ${response.message}',
    );
    debugPrint('💰 Failed amount: ₹${_advanceAmount.toStringAsFixed(2)}');

    String errorMessage = response.message ?? "Unknown error occurred";
    String actionLabel = 'Retry';
    bool showRetry = true;

    // Enhanced error handling based on Razorpay documentation
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      errorMessage =
          "Payment was cancelled by you. You can try again when ready.";
      showRetry = true;
      actionLabel = 'Try Again';
    } else if (response.code == Razorpay.NETWORK_ERROR) {
      errorMessage =
          "Network error. Please check your internet connection and try again.";
      showRetry = true;
    } else if (response.code == 2) {
      // Invalid credentials
      errorMessage = "Payment configuration error. Please contact support.";
      showRetry = false;
      actionLabel = 'Contact Support';
    } else if (response.code == 3) {
      // Amount limit exceeded
      errorMessage = "Payment amount exceeds limit. Please contact support.";
      showRetry = false;
      actionLabel = 'Contact Support';
    } else if (response.code == 4) {
      // Bad request error
      errorMessage =
          "Invalid payment request. Please try again or contact support.";
      showRetry = true;
    } else if (response.code == 5) {
      // Server error
      errorMessage = "Payment server error. Please try again in a few moments.";
      showRetry = true;
    } else if (response.code == 6) {
      // Gateway error
      errorMessage =
          "Payment gateway error. Please try again or use a different payment method.";
      showRetry = true;
    } else if (errorMessage.toLowerCase().contains('svg') ||
        errorMessage.toLowerCase().contains('attribute') ||
        errorMessage.toLowerCase().contains('width') ||
        errorMessage.toLowerCase().contains('height')) {
      errorMessage =
          "Payment interface loading issue. This is a browser compatibility issue. Please try using a different browser.";
      showRetry = true;
      actionLabel = 'Try Different Browser';
    } else if (errorMessage.toLowerCase().contains('timeout')) {
      errorMessage = "Payment request timed out. Please try again.";
      showRetry = true;
    } else if (errorMessage.toLowerCase().contains('insufficient')) {
      errorMessage =
          "Insufficient funds. Please check your account balance or try a different payment method.";
      showRetry = true;
      actionLabel = 'Try Again';
    }

    // Show error message with appropriate action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: $errorMessage',
          style: const TextStyle(fontFamily: 'Okra'),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
        action: showRetry
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: () {
                  if (actionLabel.contains('Support')) {
                    // You can add support contact functionality here
                    debugPrint(
                      'User requested support for payment error: ${response.code}',
                    );
                  } else {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _startPayment();
                    });
                  }
                },
              )
            : null,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      _isProcessingPayment = false;
    });

    // Show wallet selected message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName}',
          style: const TextStyle(fontFamily: 'Okra'),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _startPayment() async {
    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one item to proceed.',
            style: TextStyle(fontFamily: 'Okra'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    final theaterAsync = ref.read(theaterProvider(widget.theaterId));
    final theater = theaterAsync.value;

    // Get current user data for prefill
    final user = supabase.auth.currentUser;
    final userPhone =
        user?.phone ?? user?.userMetadata?['phone'] ?? '9999999999';
    final userEmail = user?.email ?? 'user@example.com';
    final userName =
        user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        'User';

    // Create payment options following Razorpay documentation
    var options = <String, dynamic>{
      'key': 'rzp_live_RSUaC7MqY7BfsZ', // Razorpay LIVE key
      'amount': (_advanceAmount * 100).toInt(), // Amount in paise
      'currency': 'INR',
      'name': 'Sylonow',
      'description':
          'Theater Booking (Advance Payment) - ${theater?.name ?? "Private Theater"}',
      'timeout': 300, // 5 minutes timeout
      'prefill': {'contact': userPhone, 'email': userEmail, 'name': userName},
      'theme': {'color': '#FF0080'},
      'modal': {'backdropclose': false, 'escape': false, 'handleback': false},
      'retry': {'enabled': true, 'max_count': 3},
      'send_sms_hash': true,
      'remember_customer': false,
      'readonly': {'email': false, 'contact': false, 'name': false},
    };

    try {
      debugPrint(
        '🚀 Opening Razorpay checkout with options: ${options.keys.join(", ")}',
      );
      debugPrint(
        '💰 Payment amount: ₹${_advanceAmount.toStringAsFixed(2)} (${(_advanceAmount * 100).toInt()} paise)',
      );

      _razorpay.open(options);
    } catch (e) {
      debugPrint('❌ Razorpay checkout error: $e');
      setState(() {
        _isProcessingPayment = false;
      });

      String errorMessage = 'Payment initialization failed';
      String actionLabel = 'Retry';

      // Enhanced error handling based on Razorpay documentation
      if (e.toString().toLowerCase().contains('key')) {
        errorMessage = 'Invalid payment configuration. Please contact support.';
        actionLabel = 'Contact Support';
      } else if (e.toString().toLowerCase().contains('amount')) {
        errorMessage = 'Invalid payment amount. Please try again.';
      } else if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('internet') ||
          e.toString().toLowerCase().contains('connection')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().toLowerCase().contains('svg') ||
          e.toString().toLowerCase().contains('attribute') ||
          e.toString().toLowerCase().contains('width') ||
          e.toString().toLowerCase().contains('height')) {
        errorMessage =
            'Payment interface loading issue. This may be a browser compatibility issue. Please try using a different browser.';
      } else if (e.toString().toLowerCase().contains('timeout')) {
        errorMessage = 'Payment request timed out. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(fontFamily: 'Okra'),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: actionLabel,
            textColor: Colors.white,
            onPressed: () {
              Future.delayed(const Duration(milliseconds: 500), () {
                _startPayment();
              });
            },
          ),
        ),
      );
    }
  }

  Future<String> _saveBookingToDatabase(String? paymentId) async {
    debugPrint('💾 _saveBookingToDatabase called with paymentId: $paymentId');
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint('❌ User not authenticated');
      throw Exception('User not authenticated');
    }

    debugPrint('✅ User authenticated: ${user.id}');
    debugPrint('📋 Selection data: ${widget.selectionData}');

    try {
      debugPrint('🧾 Starting booking save...');
      debugPrint(
        '🧾 selectionData keys: ${widget.selectionData.keys.toList()}',
      );
      debugPrint('🧾 selectionData full: ${widget.selectionData}');

      // Parse time slot from selectionData (supports Map or String)
      final dynamic selectedSlot = widget.selectionData['selectedTimeSlot'];
      debugPrint(
        '🧾 selectedSlot type: ${selectedSlot.runtimeType}, value: $selectedSlot',
      );
      String? slotIdFromSelection;
      String startTime = '00:00';
      String endTime = '00:00';

      // Extract time slot information based on data type
      if (selectedSlot is Map) {
        // Extract slot ID if available
        slotIdFromSelection = selectedSlot['id']?.toString();

        // Extract start and end times
        if (selectedSlot['start_time'] != null) {
          startTime = selectedSlot['start_time'].toString().trim();
        }
        if (selectedSlot['end_time'] != null) {
          endTime = selectedSlot['end_time'].toString().trim();
        }

        debugPrint(
          '🧾 Selected slot (Map): id=$slotIdFromSelection start=$startTime end=$endTime',
        );
        debugPrint('🧾 Full selected slot data: $selectedSlot');
      } else if (selectedSlot is String) {
        final rawSlot = selectedSlot;
        if (rawSlot.contains('-')) {
          final parts = rawSlot.split('-');
          startTime = parts[0].trim();
          endTime = parts.length > 1 ? parts[1].trim() : endTime;
        }
        debugPrint(
          '🧾 Selected slot (String): start=$startTime end=$endTime from "$selectedSlot"',
        );
      } else {
        final String rawSlot =
            widget.selectionData['selectedTimeSlot']?.toString() ?? '';
        if (rawSlot.contains('-')) {
          final parts = rawSlot.split('-');
          startTime = parts[0].trim();
          endTime = parts.length > 1 ? parts[1].trim() : endTime;
        }
        debugPrint(
          '🧾 Selected slot (Fallback): start=$startTime end=$endTime from "$rawSlot"',
        );
      }

      // Additional validation for time values
      if (startTime == '00:00' || endTime == '00:00') {
        debugPrint(
          '⚠️ WARNING: Invalid time values detected - start: $startTime, end: $endTime',
        );
      }

      // Ensure times are in HH:mm:ss
      String normalizeHms(String t) {
        if (t.isEmpty) return '00:00:00';
        final segs = t.split(':');
        if (segs.length == 2) {
          return '${segs[0].padLeft(2, '0')}:${segs[1].padLeft(2, '0')}:00';
        }
        if (segs.length >= 3) {
          return '${segs[0].padLeft(2, '0')}:${segs[1].padLeft(2, '0')}:${segs[2].padLeft(2, '0')}';
        }
        return t;
      }

      final String startTimeHms = normalizeHms(startTime);
      final String endTimeHms = normalizeHms(endTime);

      // Ensure booking_date is YYYY-MM-DD
      final String bookingDate = widget.selectedDate.contains('T')
          ? widget.selectedDate.split('T')[0]
          : widget.selectedDate;
      debugPrint('🧾 Booking date: $bookingDate');

      // Resolve vendor_id from current user's profile (since we need user_profiles.id, not auth.users.id)
      String vendorId;
      try {
        // Get current user's profile ID from user_profiles table
        final userProfileResp = await supabase
            .from('user_profiles')
            .select('id')
            .eq('auth_user_id', user.id)
            .maybeSingle();

        if (userProfileResp != null) {
          vendorId = userProfileResp['id'] as String;
          debugPrint('🧾 ✅ Found current user profile ID: $vendorId');
        } else {
          // Create user profile if it doesn't exist
          debugPrint('🧾 Creating user profile for auth user: ${user.id}');
          final newProfileResp = await supabase
              .from('user_profiles')
              .insert({'auth_user_id': user.id, 'app_type': 'customer'})
              .select('id')
              .single();
          vendorId = newProfileResp['id'] as String;
          debugPrint('🧾 ✅ Created new user profile: $vendorId');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to resolve user profile ID: $e');
        // As a last resort, try to use any existing profile ID
        vendorId =
            '75029394-260f-491e-b337-8bc08aa834c0'; // Fallback to the profile we just created
      }
      debugPrint('🧾 Final vendor_id: $vendorId, user_id: ${user.id}');

      // Contact details (required NOT NULL columns)
      String contactName = _celebrationNameController.text.trim();
      if (contactName.isEmpty) {
        contactName =
            (user.userMetadata?['full_name']?.toString() ??
            user.email ??
            'Guest User');
        if (contactName.isEmpty) contactName = 'Guest User';
      }
      String contactPhone =
          (user.userMetadata?['phone']?.toString() ??
          user.phone ??
          '0000000000');
      if (contactPhone.isEmpty) contactPhone = '0000000000';
      String contactEmail =
          user.email ??
          (user.userMetadata?['email']?.toString() ?? 'guest@example.com');
      if (contactEmail.isEmpty) contactEmail = 'guest@example.com';
      debugPrint(
        '🧾 Contact name: $contactName, phone: $contactPhone, email: $contactEmail',
      );

      // Try to resolve a time_slot_id. Prefer the id provided in selection (if UUID), else lookup by screenId + times
      String? screenId =
          widget.selectionData['screenId'] as String? ??
          (selectedSlot is Map ? selectedSlot['screen_id'] : null);
      debugPrint(
        '🧾 Screen ID resolution: widget.screenId=${widget.selectionData['screenId']}, slot.screenId=${selectedSlot is Map ? selectedSlot['screen_id'] : null}, final=$screenId',
      );
      String? resolvedTimeSlotId;
      if (_looksLikeUuid(slotIdFromSelection)) {
        resolvedTimeSlotId = slotIdFromSelection;
        debugPrint(
          '🧾 Using provided time_slot_id from selection: $resolvedTimeSlotId',
        );
      } else if (screenId != null) {
        try {
          debugPrint(
            '🧾 Attempting time slot lookup with screen_id=$screenId, start_time=$startTimeHms, end_time=$endTimeHms',
          );
          final ts = await supabase
              .from('theater_time_slots')
              .select('id, start_time, end_time, theater_id')
              .eq('screen_id', screenId)
              .eq('start_time', startTimeHms)
              .eq('end_time', endTimeHms);

          debugPrint('🧾 Time slot lookup results: $ts');

          if (ts.isNotEmpty) {
            resolvedTimeSlotId = ts.first['id'] as String?;
            debugPrint(
              '🧾 ✅ Resolved time_slot_id via lookup: $resolvedTimeSlotId',
            );
          } else {
            // Try a broader search without exact time match
            debugPrint('🧾 No exact match found, trying broader search...');
            final broadSearch = await supabase
                .from('theater_time_slots')
                .select('id, start_time, end_time, theater_id, screen_id')
                .eq('screen_id', screenId);
            debugPrint(
              '🧾 Available time slots for screen $screenId: $broadSearch',
            );

            // Try to find closest time match in case of format issues
            if (broadSearch.isNotEmpty) {
              debugPrint('🧾 Attempting fuzzy time matching...');
              for (final slot in broadSearch) {
                final slotStart = slot['start_time'] as String?;
                final slotEnd = slot['end_time'] as String?;
                debugPrint(
                  '🧾 Comparing $slotStart-$slotEnd vs $startTimeHms-$endTimeHms',
                );

                // Check if times match (with potential format variations)
                if (slotStart != null && slotEnd != null) {
                  if (_timesMatch(slotStart, startTimeHms) &&
                      _timesMatch(slotEnd, endTimeHms)) {
                    resolvedTimeSlotId = slot['id'] as String?;
                    debugPrint(
                      '🧾 ✅ Resolved via fuzzy matching: $resolvedTimeSlotId',
                    );
                    break;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to resolve time_slot_id by lookup: $e');
        }
      } else {
        debugPrint('ℹ️ No screenId and no slot id; time_slot_id will be null');
      }

      // Extract occasion data
      final dynamic selectedOccasion = widget.selectionData['selectedOccasion'];
      String? occasionName;
      String? occasionId;

      if (selectedOccasion is OccasionModel) {
        occasionName = selectedOccasion.name;
        occasionId = selectedOccasion.id;
      } else if (selectedOccasion is Map<String, dynamic>) {
        occasionName =
            selectedOccasion['name']?.toString() ??
            selectedOccasion['title']?.toString() ??
            selectedOccasion['occasion']?.toString() ??
            selectedOccasion['label']?.toString();
        occasionId = selectedOccasion['id']?.toString();
      } else if (selectedOccasion is String) {
        occasionName = selectedOccasion;
      }

      debugPrint('🧾 Occasion data: name=$occasionName, id=$occasionId');

      // Insert into private_theater_bookings and get the booking id
      final bookingInsert = {
        'theater_id': widget.theaterId,
        'time_slot_id': resolvedTimeSlotId,
        'user_id': user.id,
        'booking_date': bookingDate,
        'start_time': startTimeHms,
        'end_time': endTimeHms,
        'total_amount': _totalAmount,
        'payment_status': 'paid', // Mark as paid since payment was successful
        'payment_id': paymentId,
        'booking_status': 'confirmed',
        'guest_count': _numberOfPeople,
        'special_requests':
            null, // Reset to null since we have proper occasion columns now
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'celebration_name': _celebrationNameController.text.trim().isNotEmpty
            ? _celebrationNameController.text.trim()
            : null,
        'number_of_people': _numberOfPeople,
        'vendor_id': vendorId,
        'screen_id': screenId,
        'occasion_name': occasionName,
        'occasion_id': occasionId,
      };
      debugPrint('🧾 Inserting booking: $bookingInsert');
      debugPrint('🔄 About to insert into private_theater_bookings table...');

      final inserted = await supabase
          .from('private_theater_bookings')
          .insert(bookingInsert)
          .select('id')
          .single();
      final String bookingId = inserted['id'] as String;
      debugPrint('✅ Booking inserted successfully with id: $bookingId');
      debugPrint('✅ Database insertion completed - booking saved!');

      // Attempt to mark slot as booked in theater_time_slot_bookings (optional; vendor RLS may block)
      if (resolvedTimeSlotId != null) {
        try {
          final slotRow = {
            'time_slot_id': resolvedTimeSlotId,
            'booked_date': bookingDate,
          };
          debugPrint('🧾 Inserting theater_time_slot_bookings: $slotRow');
          await supabase.from('theater_time_slot_bookings').insert(slotRow);
          debugPrint('✅ theater_time_slot_bookings inserted');
        } catch (e) {
          debugPrint(
            '⚠️ Failed to insert theater_time_slot_bookings (likely RLS vendor-only): $e',
          );
        }
      }

      // Build add-on booking rows from selected items
      final List<Map<String, dynamic>> addonRows = [];

      void addAddonRowFrom(Map<String, dynamic> item) {
        final String? addonIdRaw = item['id']?.toString();
        if (!_looksLikeUuid(addonIdRaw)) {
          debugPrint('ℹ️ Skipping addon without valid UUID id: $addonIdRaw');
          return;
        }
        final String addonId = addonIdRaw!;
        final double unitPrice = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        final int quantity = (item['quantity'] is int)
            ? item['quantity'] as int
            : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        final double totalPrice = unitPrice * quantity;
        addonRows.add({
          'booking_id': bookingId,
          'addon_id': addonId,
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_price': totalPrice,
        });
      }

      for (final item in _selectedAddOns.values) {
        addAddonRowFrom(item);
      }
      for (final item in _selectedSpecialServices.values) {
        addAddonRowFrom(item);
      }
      debugPrint('🧾 Prepared ${addonRows.length} addon rows');

      if (addonRows.isNotEmpty) {
        try {
          final insertedAddons = await supabase
              .from('private_theater_booking_addons')
              .insert(addonRows)
              .select('id');
          debugPrint('✅ Addons inserted count: ${insertedAddons.length}');
        } catch (e) {
          debugPrint('⚠️ Failed to insert addon rows: $e');
        }
      }

      debugPrint('🎉 Booking save flow completed');
      return bookingId;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving booking: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      // Log the specific error details for debugging
      if (e.toString().contains('column') &&
          e.toString().contains('does not exist')) {
        debugPrint('❌ Database schema error - column doesn\'t exist');
      } else if (e.toString().contains('null value')) {
        debugPrint(
          '❌ Database constraint error - null value in required field',
        );
      } else if (e.toString().contains('foreign key')) {
        debugPrint('❌ Database constraint error - foreign key violation');
      }

      // Re-throw the error so it can be handled by the payment success handler
      throw Exception('Database insertion failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🔄 TheaterCheckoutScreen building with $_numberOfPeople people, total: ₹${_totalAmount.toStringAsFixed(0)}',
    );
    final theaterAsync = ref.watch(theaterProvider(widget.theaterId));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Okra',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Details Header
                  _buildBookingDetailsSection(theaterAsync),

                  const SizedBox(height: 12),

                  // Interactive Bill Summary
                  _buildInteractiveBillSummary(),

                  const SizedBox(height: 12),

                  // Expandable Total Payable Amount
                  Container(
                    key: ValueKey('bill_summary_$_numberOfPeople'),
                    child: _buildTotalPayableAmount(),
                  ),
                ],
              ),
            ),
          ),

          // Book Now Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isProcessingPayment
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ],
                      )
                    : ValueListenableBuilder<int>(
                        valueListenable: _peopleCountNotifier,
                        builder: (context, peopleCount, child) {
                          return Text(
                            'Pay Advance (60%) - ₹${_advanceAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPayableAmount() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Green expandable button
          InkWell(
            onTap: () {
              setState(() {
                _isBillDetailsExpanded = !_isBillDetailsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Payable Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Okra',
                    ),
                  ),
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _peopleCountNotifier,
                        builder: (context, peopleCount, child) {
                          return Text(
                            '₹${_totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Okra',
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _isBillDetailsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable bill details
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isBillDetailsExpanded ? null : 0,
            child: _isBillDetailsExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: _buildExpandedBillDetails(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedBillDetails() {
    return Column(
      key: ValueKey('bill_details_$_numberOfPeople'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with savings badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bill Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Okra',
              ),
            ),
            if (_savings > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  'You save ₹${_savings.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                    fontFamily: 'Okra',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Theater slot price
        _buildPriceRow(
          'Theater Slot (${_getSelectedTimeSlotDisplay()})',
          _slotPrice,
          isSubtotal: false,
        ),

        // Extra person charges
        ValueListenableBuilder<int>(
          valueListenable: _peopleCountNotifier,
          builder: (context, peopleCount, child) {
            if (_extraPersonCharges > 0) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    'Extra Person Charges (${_numberOfPeople - _baseAllowedCapacity} × ₹${_extraChargePerPerson.toStringAsFixed(0)})',
                    _extraPersonCharges,
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Add-ons breakdown
        if (_addOnsPrice > 0) ...[
          const SizedBox(height: 8),
          _buildPriceRow('Add-ons & Extras', _addOnsPrice),
          const SizedBox(height: 4),
          // Individual add-ons
          if (widget.selectionData['selectedAddOns'] != null) ...[
            ..._buildAddOnBreakdown(),
          ],
          // Individual special services
          if (widget.selectionData['selectedSpecialServices'] != null) ...[
            ..._buildSpecialServiceBreakdown(),
          ],
        ],

        const SizedBox(height: 12),
        _buildDivider(),

        // Subtotal
        _buildPriceRow('Item Total', _subtotal, isSubtotal: true),

        const SizedBox(height: 8),

        // Service charges
        _buildPriceRow('Service Charge (2.5%)', _serviceCharge, isCharge: true),

        // Handling fee
        _buildPriceRow('Handling Fee', _handlingFee, isCharge: true),

        const SizedBox(height: 8),
        _buildDivider(),

        // GST
        _buildPriceRow('GST (18%)', _gstAmount, isTax: true),

        const SizedBox(height: 12),
        _buildDivider(thickness: 2),
        const SizedBox(height: 8),

        // Total Amount
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Okra',
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _peopleCountNotifier,
              builder: (context, peopleCount, child) {
                return Text(
                  '₹${_totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Okra',
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 12),
        _buildDivider(thickness: 1),
        const SizedBox(height: 12),

        // Advance Payment (60%)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Advance Payment (60%)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontFamily: 'Okra',
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _peopleCountNotifier,
              builder: (context, peopleCount, child) {
                return Text(
                  '₹${_advanceAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontFamily: 'Okra',
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Remaining Amount
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remaining Amount (Pay at venue)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _peopleCountNotifier,
              builder: (context, peopleCount, child) {
                return Text(
                  '₹${_remainingAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontFamily: 'Okra',
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Tax note
        Text(
          'Inclusive of all taxes • GST will be charged as applicable',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontFamily: 'Okra',
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isSubtotal = false,
    bool isCharge = false,
    bool isTax = false,
    bool isIndented = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 16.0 : 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: isSubtotal ? 15 : 14,
                fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.normal,
                color: isSubtotal ? Colors.black : Colors.grey[700],
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isSubtotal ? 15 : 14,
              fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.normal,
              color: isSubtotal
                  ? Color(0xff1C1C1C)
                  : isCharge || isTax
                  ? Colors.grey[600]
                  : Colors.grey[700],
              fontFamily: 'Okra',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider({double thickness = 1}) {
    return Divider(thickness: thickness, color: Colors.grey[200], height: 1);
  }

  // Enhanced booking details section
  Widget _buildBookingDetailsSection(AsyncValue theaterAsync) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Details',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),

          // Service Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: theaterAsync.when(
              data: (theater) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Theater Image
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[100],
                        ),
                        child: theater?.images.isNotEmpty == true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: theater!.images.first,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.movie_outlined,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.movie_outlined,
                                color: Colors.grey,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 12),

                      // Theater Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service details',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              theater?.name ?? 'Theater Booking',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Booking Info
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    theater?.address ?? 'Theater location',
                    color: const Color(0xFFE91E63),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    _formatDate(DateTime.parse(widget.selectedDate)),
                    color: const Color(0xFFE91E63),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time_outlined,
                    _getSelectedTimeSlotDisplay(),
                    color: const Color(0xFFE91E63),
                    showBadge: true,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.celebration_outlined,
                    _getSelectedOccasionDisplay(),
                    color: const Color(0xFFE91E63),
                  ),
                ],
              ),
              loading: () => const SizedBox(height: 120),
              error: (error, stackTrace) => const SizedBox(height: 120),
            ),
          ),

          const SizedBox(height: 20),

          // Celebration Name Input
          Text(
            'For whom this celebration is ?',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _celebrationNameController,
            decoration: InputDecoration(
              hintText: 'Type there name here...',
              hintStyle: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFFBBBBBB),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF1A1A1A),
            ),
          ),

          const SizedBox(height: 20),

          // Number of people
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Number of people',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'Base $_baseAllowedCapacity people, Max $_maxAllowedPeople people${_extraChargePerPerson > 0 ? ' (+₹${_extraChargePerPerson.toStringAsFixed(0)}/person)' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,

                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              _buildNumberSelector(),
            ],
          ),

          const SizedBox(height: 20),

          // Decoration question
          Text(
            'Do you want decoration',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _wantsDecoration = !_wantsDecoration;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _wantsDecoration ? 'yes' : 'no',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Icon(
                    _wantsDecoration
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF666666),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for the new UI
  Widget _buildInfoRow(
    IconData icon,
    String text, {
    Color? color,
    bool showBadge = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? const Color(0xFF666666)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
        ),
        if (showBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Most',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNumberSelector() {
    return Row(
      children: [
        _buildNumberButton('-', () {
          if (_numberOfPeople > 1) {
            setState(() {
              _numberOfPeople--;
              _peopleCountNotifier.value = _numberOfPeople;
              debugPrint('🎯 Decreased people count to: $_numberOfPeople');
            });
          }
        }),
        const SizedBox(width: 16),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              '$_numberOfPeople',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildNumberButton('+', () {
          if (_numberOfPeople < _maxAllowedPeople) {
            setState(() {
              _numberOfPeople++;
              _peopleCountNotifier.value = _numberOfPeople;
              debugPrint(
                '🎯 Increased people count to: $_numberOfPeople (max: $_maxAllowedPeople)',
              );
            });

            // Show info about extra charges if applicable
            if (_numberOfPeople > _baseAllowedCapacity &&
                _extraChargePerPerson > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Extra person added. Additional charge: ₹${_extraChargePerPerson.toStringAsFixed(0)}',
                    style: const TextStyle(fontFamily: 'Okra'),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            // Show message if trying to exceed capacity
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Maximum $_maxAllowedPeople people allowed for this theater',
                  style: const TextStyle(fontFamily: 'Okra'),
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }),
      ],
    );
  }

  Widget _buildNumberButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  String _getSelectedTimeSlotDisplay() {
    final dynamic selectedSlot = widget.selectionData['selectedTimeSlot'];

    // Debug logging
    debugPrint('🧾 _getSelectedTimeSlotDisplay - selectedSlot: $selectedSlot');

    // Handle Map type time slot
    if (selectedSlot is Map<String, dynamic>) {
      // Try to get formatted time display
      if (selectedSlot['start_time'] != null &&
          selectedSlot['end_time'] != null) {
        final start = selectedSlot['start_time'].toString();
        final end = selectedSlot['end_time'].toString();
        debugPrint('🧾 Found time slot: $start - $end');
        return '$start - $end';
      }

      // Fallback to id if available
      if (selectedSlot['id'] != null) {
        return selectedSlot['id'].toString();
      }
    }

    // Handle String type time slot
    if (selectedSlot is String) {
      return selectedSlot;
    }

    // Fallback to selectionData value
    final slotFromData = widget.selectionData['selectedTimeSlot'];
    if (slotFromData != null) {
      return slotFromData.toString();
    }

    // Log warning and return default
    debugPrint('🧾 WARNING: No time slot display found, using default');
    return 'Time Slot Not Selected';
  }

  String _getSelectedOccasionDisplay() {
    final dynamic selectedOccasion = widget.selectionData['selectedOccasion'];

    // Debug logging
    debugPrint(
      '🧾 _getSelectedOccasionDisplay - selectedOccasion: $selectedOccasion',
    );

    // Handle OccasionModel type
    if (selectedOccasion is OccasionModel) {
      debugPrint('🧾 Found occasion: ${selectedOccasion.name}');
      return selectedOccasion.name;
    }

    // Handle Map type occasion
    if (selectedOccasion is Map<String, dynamic>) {
      // Try common name fields
      final name =
          selectedOccasion['name'] ??
          selectedOccasion['title'] ??
          selectedOccasion['occasion'] ??
          selectedOccasion['label'];

      if (name != null) {
        debugPrint('🧾 Found occasion: $name');
        return name.toString();
      }

      // Fallback to id if available
      if (selectedOccasion['id'] != null) {
        return selectedOccasion['id'].toString();
      }
    }

    // Handle String type occasion
    if (selectedOccasion is String) {
      return selectedOccasion;
    }

    // Log warning and return default
    debugPrint('🧾 WARNING: No occasion display found, using default');
    return 'No Occasion Selected';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  // Helper method to build add-on breakdown
  List<Widget> _buildAddOnBreakdown() {
    List<Widget> addOnWidgets = [];

    for (var addOn in _selectedAddOns.values) {
      final name = addOn['name'] ?? 'Add-on';
      final price = (addOn['price'] ?? 0).toDouble();
      final quantity = addOn['quantity'] ?? 1;
      final totalPrice = price * quantity;
      final imageUrl =
          (addOn['image'] ??
                  addOn['thumbnail'] ??
                  addOn['icon'] ??
                  addOn['imgUrl'])
              as String?;

      addOnWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6.0, left: 8.0, right: 0.0),
          child: _buildBreakdownRowWithImage(
            name: name,
            unitPrice: price,
            quantity: quantity,
            totalPrice: totalPrice,
            imageUrl: imageUrl,
          ),
        ),
      );
    }

    return addOnWidgets;
  }

  // Helper method to build special service breakdown
  List<Widget> _buildSpecialServiceBreakdown() {
    List<Widget> serviceWidgets = [];

    for (var service in _selectedSpecialServices.values) {
      final name = service['name'] ?? 'Special Service';
      final price = (service['price'] ?? 0).toDouble();
      final quantity = service['quantity'] ?? 1;
      final totalPrice = price * quantity;
      final imageUrl =
          (service['image'] ??
                  service['thumbnail'] ??
                  service['icon'] ??
                  service['imgUrl'])
              as String?;

      serviceWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6.0, left: 8.0, right: 0.0),
          child: _buildBreakdownRowWithImage(
            name: name,
            unitPrice: price,
            quantity: quantity,
            totalPrice: totalPrice,
            imageUrl: imageUrl,
          ),
        ),
      );
    }

    return serviceWidgets;
  }

  // Compact row with optional image for bill breakdown
  Widget _buildBreakdownRowWithImage({
    required String name,
    required double unitPrice,
    required int quantity,
    required double totalPrice,
    String? imageUrl,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Image thumb or fallback dot
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[200],
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(
                    Icons.image_not_supported_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                )
              : const Icon(Icons.extension, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        // Name and xQty
        Expanded(
          child: Text(
            '$name${quantity > 1 ? ' (x$quantity)' : ''}',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF555555),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Amount
        Text(
          '₹${totalPrice.toStringAsFixed(0)}',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  // Interactive Bill Summary with management controls
  Widget _buildInteractiveBillSummary() {
    final hasItems =
        _selectedAddOns.isNotEmpty || _selectedSpecialServices.isNotEmpty;

    if (!hasItems) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Selected Items',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),

          // Add-ons section
          if (_selectedAddOns.isNotEmpty) ...[
            _buildItemSection(
              'Add-ons',
              _selectedAddOns,
              (itemId, increment) => _updateAddOnQuantity(itemId, increment),
              (itemId) => _removeAddOn(itemId),
            ),
          ],

          // Special services section
          if (_selectedSpecialServices.isNotEmpty) ...[
            _buildItemSection(
              'Special Services',
              _selectedSpecialServices,
              (itemId, increment) =>
                  _updateSpecialServiceQuantity(itemId, increment),
              (itemId) => _removeSpecialService(itemId),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildItemSection(
    String title,
    Map<String, Map<String, dynamic>> items,
    Function(String, bool) onQuantityChange,
    Function(String) onRemove,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF666666),
            ),
          ),
        ),
        ...items.entries.map((entry) {
          final itemId = entry.key;
          final item = entry.value;
          final name = item['name'] ?? 'Unknown Item';
          final price = (item['price'] ?? 0).toDouble();
          final quantity = item['quantity'] ?? 1;

          return _buildItemRow(
            name,
            price,
            quantity,
            () => onQuantityChange(itemId, false), // Decrement
            () => onQuantityChange(itemId, true), // Increment
            () => onRemove(itemId), // Remove
          );
        }),
      ],
    );
  }

  Widget _buildItemRow(
    String name,
    double price,
    int quantity,
    VoidCallback onDecrement,
    VoidCallback onIncrement,
    VoidCallback onRemove,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${price.toStringAsFixed(0)} each',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),

          // Quantity controls
          Row(
            children: [
              // Decrement button
              _buildQuantityButton(
                Icons.remove,
                onDecrement,
                enabled: quantity > 1,
              ),

              // Quantity display
              Container(
                width: 40,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Text(
                    '$quantity',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),

              // Increment button
              _buildQuantityButton(Icons.add, onIncrement, enabled: true),

              const SizedBox(width: 12),

              // Remove button
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red[600],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Total price for this item
          Text(
            '₹${(price * quantity).toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(
    IconData icon,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : Colors.grey[500],
        ),
      ),
    );
  }

  // Quantity management methods
  void _updateAddOnQuantity(String itemId, bool increment) {
    setState(() {
      if (_selectedAddOns.containsKey(itemId)) {
        final currentQuantity = _selectedAddOns[itemId]!['quantity'] ?? 1;
        if (increment) {
          _selectedAddOns[itemId]!['quantity'] = currentQuantity + 1;
        } else if (currentQuantity > 1) {
          _selectedAddOns[itemId]!['quantity'] = currentQuantity - 1;
        }
      }
    });
  }

  void _updateSpecialServiceQuantity(String itemId, bool increment) {
    setState(() {
      if (_selectedSpecialServices.containsKey(itemId)) {
        final currentQuantity =
            _selectedSpecialServices[itemId]!['quantity'] ?? 1;
        if (increment) {
          _selectedSpecialServices[itemId]!['quantity'] = currentQuantity + 1;
        } else if (currentQuantity > 1) {
          _selectedSpecialServices[itemId]!['quantity'] = currentQuantity - 1;
        }
      }
    });
  }

  void _removeAddOn(String itemId) {
    setState(() {
      _selectedAddOns.remove(itemId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add-on removed from cart',
          style: TextStyle(fontFamily: 'Okra'),
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeSpecialService(String itemId) {
    setState(() {
      _selectedSpecialServices.remove(itemId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Service removed from cart',
          style: TextStyle(fontFamily: 'Okra'),
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
