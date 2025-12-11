import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';

import '../models/screen_package_model.dart';
import '../models/theater_screen_model.dart';
import '../models/time_slot_model.dart';
import '../models/addon_model.dart';
import '../providers/theater_screen_detail_providers.dart';

class SpecialServicesScreen extends ConsumerStatefulWidget {
  const SpecialServicesScreen({
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

  static const String routeName = '/special-services';

  @override
  ConsumerState<SpecialServicesScreen> createState() => _SpecialServicesScreenState();
}

class _SpecialServicesScreenState extends ConsumerState<SpecialServicesScreen> {
  final List<AddonModel> _selectedSpecialServices = [];
  double _totalSpecialServicesPrice = 0.0;

  @override
  Widget build(BuildContext context) {
    final specialServices = ref.watch(addonsByCategoryProvider(AddonCategoryParams(
      theaterId: widget.screen.theaterId,
      category: 'special service',
    )));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Special Services',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
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
            child: specialServices.when(
              data: (specialServicesList) {
                if (specialServicesList.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildSpecialServicesList(specialServicesList);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          ),

          // Bottom continue bar
          _buildBottomContinueBar(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildProgressDot(true, 'Add-ons'),
          _buildProgressLine(),
          _buildProgressDot(true, 'Extra Special'),
          _buildProgressLine(),
          _buildProgressDot(true, 'Special Services'),
          _buildProgressLine(),
          _buildProgressDot(false, 'Checkout'),
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
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'Okra',
              color: isActive ? AppTheme.primaryColor : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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

  Widget _buildSpecialServicesList(List<AddonModel> specialServices) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Services',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enhance your experience with our premium services',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: specialServices.length,
            itemBuilder: (context, index) {
              final service = specialServices[index];
              return _buildSpecialServiceCard(service);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialServiceCard(AddonModel service) {
    final isSelected = _selectedSpecialServices.contains(service);

    return InkWell(
      onTap: () {
        setState(() {
          final servicePriceWithTax = service.price * 1.0354; // Add 3.54% tax
          if (isSelected) {
            _selectedSpecialServices.remove(service);
            _totalSpecialServicesPrice -= servicePriceWithTax;
          } else {
            _selectedSpecialServices.add(service);
            _totalSpecialServicesPrice += servicePriceWithTax;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
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
            // Image Section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: service.hasImage
                      ? CachedNetworkImage(
                          imageUrl: service.imageUrl!,
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
                              Icons.room_service,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.room_service, color: Colors.grey, size: 40),
                        ),
                ),
              ),
            ),

            // Content Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      service.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      service.displayDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Okra',
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // Price and selection indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '₹${(service.price * 1.0354).round()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : null,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.room_service_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Special Services Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Proceed to checkout',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Okra',
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContinueBar() {
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
            if (_totalSpecialServicesPrice > 0)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedSpecialServices.length} Service${_selectedSpecialServices.length > 1 ? 's' : ''} Selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                    Text(
                      '₹${_totalSpecialServicesPrice.round()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ],
                ),
              )
            else
              const Expanded(
                child: Text(
                  'No services selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Okra',
                    color: Colors.grey,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: _proceedToCheckout,
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
                'Checkout',
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

  void _proceedToCheckout() {
    context.push(
      '/outside/${widget.screenId}/checkout',
      extra: {
        'screen': widget.screen,
        'selectedPackage': widget.selectedPackage,
        'selectedDate': widget.selectedDate,
        'timeSlot': widget.timeSlot,
        'screenId': widget.screenId,
        'selectedAddons': widget.selectedAddons,
        'totalAddonPrice': widget.totalAddonPrice,
        'selectedExtraSpecials': widget.selectedExtraSpecials,
        'totalExtraSpecialPrice': widget.totalExtraSpecialPrice,
        'selectedSpecialServices': _selectedSpecialServices,
        'totalSpecialServicesPrice': _totalSpecialServicesPrice,
      },
    );
  }
}