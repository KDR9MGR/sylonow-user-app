import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';

import '../models/screen_package_model.dart';
import '../models/theater_screen_model.dart';
import '../models/time_slot_model.dart';
import '../models/addon_model.dart';
import '../providers/theater_screen_detail_providers.dart';
import '../widgets/package_addons_list.dart';
import '../widgets/screen_packages_section.dart';

class TheaterScreenDetailScreen extends ConsumerStatefulWidget {
  const TheaterScreenDetailScreen({
    super.key,
    required this.screen,
    this.selectedDate,
  });

  final TheaterScreen screen;
  final String? selectedDate;

  static const String routeName = '/theater-screen-detail';

  @override
  ConsumerState<TheaterScreenDetailScreen> createState() =>
      _TheaterScreenDetailScreenState();
}

class _TheaterScreenDetailScreenState
    extends ConsumerState<TheaterScreenDetailScreen> {
  late DateTime _selectedDate;
  TimeSlotModel? _selectedTimeSlot;
  ScreenPackageModel? _selectedPackage;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  final List<AddonModel> _selectedAddons = [];
  double _totalAddonPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate != null
        ? DateTime.parse(widget.selectedDate!)
        : DateTime.now();

    // Listen to scroll events to show/hide app bar title
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    // Show app bar title when screen name is not visible (scrolled past ~200px)
    const double triggerOffset = 200.0;
    final bool shouldShowTitle =
        _scrollController.hasClients &&
        _scrollController.offset > triggerOffset;

    if (shouldShowTitle != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = shouldShowTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = ref.watch(
      timeSlotsByScreenProvider(
        TimeSlotParams(
          screenId: widget.screen.id,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        ),
      ),
    );

    // Calculate time slots count for subtitle
    final timeSlotsCount = timeSlots.when(
      data: (slots) => slots.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
                  _buildScreenHeader(),
                  _buildDateSelector(),
                  _buildAddonsSection(),
                  _buildTimeSlotSection(timeSlots),
                  _buildPackagesSection(),
                  _buildScreenDetails(),
                  _buildAmenities(),
                  const SizedBox(height: 100), // Space for bottom bar
                ]),
              ),
            ],
          ),
          // Floating app bar
          _buildFloatingAppBar(timeSlotsCount),
        ],
      ),
      bottomNavigationBar: _buildBottomBookingBar(),
    );
  }

  Widget _buildFloatingAppBar(int timeSlotsCount) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).padding.top + kToolbarHeight,
        decoration: BoxDecoration(
          color: _showAppBarTitle ? Colors.white : Colors.transparent,
          boxShadow: _showAppBarTitle
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Back button
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _showAppBarTitle
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: _showAppBarTitle ? Colors.black87 : Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),

                // Title section
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _showAppBarTitle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.screen.screenName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                          ),
                        ),
                        if (timeSlotsCount > 0)
                          Text(
                            '$timeSlotsCount Time Slots',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              fontFamily: 'Okra',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Favorite button
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _showAppBarTitle
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.favorite_border,
                      color: _showAppBarTitle ? Colors.black87 : Colors.white,
                    ),
                    onPressed: () {
                      // TODO: Add to wishlist functionality
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenHeader() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          // Background Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: widget.screen.images?.isNotEmpty == true
                ? Image.network(
                    widget.screen.images!.first,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage();
                    },
                  )
                : _buildPlaceholderImage(),
          ),
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
          // Screen Info Overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.screen.screenName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Okra',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event_seat,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.screen.allowedCapacity ?? widget.screen.capacity} Seats',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontFamily: 'Okra',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '4.8', // TODO: Get actual rating
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
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
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[300],
      child: const Icon(Icons.theaters, size: 64, color: Colors.grey),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Date',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7, // Show next 7 days
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected =
                    DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(_selectedDate);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTimeSlot = null; // Reset selected time slot
                    });
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Okra',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotSection(AsyncValue<List<TimeSlotModel>> timeSlots) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Time Slots',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 12),
          timeSlots.when(
            data: (slots) {
              if (slots.isEmpty) {
                return _buildEmptyTimeSlots();
              }
              return _buildTimeSlotGrid(slots);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (error, stack) => _buildErrorTimeSlots(error.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotGrid(List<TimeSlotModel> slots) {
    final now = DateTime.now();
    final currentTime = TimeOfDay.now();
    final isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(now);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = _selectedTimeSlot?.id == slot.id;
        final isPast = isToday && _isTimePast(slot.startTime, currentTime);
        final isBooked = slot.isBooked;

        return GestureDetector(
          onTap: () {
            if (!isPast && !isBooked) {
              setState(() {
                _selectedTimeSlot = isSelected ? null : slot;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isBooked
                  ? Colors.grey[200]
                  : isSelected
                  ? AppTheme.primaryColor
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBooked
                    ? Colors.grey[300]!
                    : isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey[300]!,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}',
                  style: TextStyle(
                    color: isBooked
                        ? Colors.grey[500]
                        : isSelected
                        ? Colors.white
                        : isPast
                        ? Colors.grey[400]
                        : Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                  ),
                ),
                Text(
                  '₹${slot.basePrice.round()}',
                  style: TextStyle(
                    color: isBooked
                        ? Colors.grey[500]
                        : isSelected
                        ? Colors.white
                        : isPast
                        ? Colors.grey[400]
                        : AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                  ),
                ),
                if (isBooked)
                  Text(
                    'Booked',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 8,
                      fontFamily: 'Okra',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTimeSlots() {
    return SizedBox(
      height: 100,
      child: const Center(
        child: Text(
          'No time slots available for this date',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontFamily: 'Okra',
          ),
        ),
      ),
    );
  }

  Widget _buildErrorTimeSlots(String error) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          'Error loading time slots: $error',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 14,
            fontFamily: 'Okra',
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesSection() {
    return ScreenPackagesSection(
      screenId: widget.screen.id,
      onPackageSelected: (package) {
        setState(() {
          _selectedPackage = package;
        });
        // Show package details or add to booking
        _showPackageDetails(package);
      },
    );
  }

  void _showPackageDetails(ScreenPackageModel package) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Package details content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Package header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            package.packageName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            package.formattedPrice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Package image
                    if (package.hasImage)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[100],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            package.packageImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.card_giftcard,
                                size: 64,
                                color: Colors.grey[400],
                              );
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Package description
                    if (package.packageDescription != null) ...[
                      const Text(
                        'Package Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Okra',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        package.packageDescription!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                          fontFamily: 'Okra',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Package addons
                    if (package.addonIds.isNotEmpty) ...[
                      PackageAddonsList(package: package),
                    ],
                  ],
                ),
              ),
            ),

            // Add to booking button
            Container(
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
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Add package to booking (you can implement this logic)
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add to Booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screen Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.screen.description != null) ...[
            Text(
              widget.screen.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
                fontFamily: 'Okra',
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              _buildDetailItem(
                icon: Icons.event_seat,
                label: 'Capacity',
                value:
                    '${widget.screen.allowedCapacity ?? widget.screen.capacity} Seats',
              ),
              const SizedBox(width: 24),
              _buildDetailItem(
                icon: Icons.monitor,
                label: 'Screen',
                value: 'Screen ${widget.screen.screenNumber}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenities() {
    if (widget.screen.amenities?.isEmpty ?? true) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amenities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.screen.amenities!.map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  amenity,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBookingBar() {
    if (_selectedTimeSlot == null) {
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
        child: const Text(
          'Select a time slot to continue booking',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontFamily: 'Okra',
          ),
        ),
      );
    }

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
                    '${_formatTime(_selectedTimeSlot!.startTime)} - ${_formatTime(_selectedTimeSlot!.endTime)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                  Text(
                    '₹${(_selectedTimeSlot!.basePrice + _totalAddonPrice).round()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontFamily: 'Okra',
                    ),
                  ),
                  if (_totalAddonPrice > 0)
                    Text(
                      'Base: ₹${_selectedTimeSlot!.basePrice.round()} + Add-ons: ₹${_totalAddonPrice.round()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontFamily: 'Okra',
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _proceedToBooking,
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
              child: const Text(
                'Book Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
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

  bool _isTimePast(String timeString, TimeOfDay currentTime) {
    final slotTime = TimeOfDay.fromDateTime(
      DateTime.parse('2000-01-01 $timeString'),
    );
    return slotTime.hour < currentTime.hour ||
        (slotTime.hour == currentTime.hour &&
            slotTime.minute <= currentTime.minute);
  }

  void _proceedToBooking() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      // Redirect to login
      context.push('/login');
      return;
    }

    // Navigate to extra special screen
    context.push(
      '/outside/${widget.screen.id}/extra-special',
      extra: {
        'screen': widget.screen,
        'selectedPackage': _selectedPackage,
        'selectedDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'timeSlot': _selectedTimeSlot,
        'screenId': widget.screen.id,
        'selectedAddons': _selectedAddons,
        'totalAddonPrice': _totalAddonPrice.isFinite ? _totalAddonPrice : 0.0,
      },
    );
  }

  Widget _buildAddonsSection() {
    // Fetch only Gift category add-ons by theater_id
    final giftAddons = ref.watch(
      addonsByCategoryProvider(
        AddonCategoryParams(
          theaterId: widget.screen.theaterId,
          category: 'Gift',
        ),
      ),
    );

    return giftAddons.when(
      data: (giftList) {
        if (giftList.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Add-ons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  itemCount: giftList.length,
                  itemBuilder: (context, index) {
                    final addon = giftList[index];
                    return Container(
                      width: 180,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      child: _buildAddonCard(addon),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _buildAddonsLoading(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildAddonsLoading() {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: const Center(child: CircularProgressIndicator(color: Colors.pink)),
    );
  }

  Widget _buildAddonCard(AddonModel addon) {
    final isSelected = _selectedAddons.contains(addon);

    return GestureDetector(
      onTap: () {
        setState(() {
          final addonPriceWithTax = addon.price * 1.0354; // Add 3.54% tax
          if (isSelected) {
            _selectedAddons.remove(addon);
            _totalAddonPrice -= addonPriceWithTax;
          } else {
            _selectedAddons.add(addon);
            _totalAddonPrice += addonPriceWithTax;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              height: 157,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: addon.hasImage
                    ? CachedNetworkImage(
                        imageUrl: addon.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.pink,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      addon.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      addon.displayDescription,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Okra',
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Price Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${(addon.price * 1.0354).round()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                            color: Color(0xFF171717),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isSelected ? 'Added' : 'Add',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
