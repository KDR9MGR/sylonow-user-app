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

class ExtraSpecialScreen extends ConsumerStatefulWidget {
  const ExtraSpecialScreen({
    super.key,
    required this.screen,
    required this.selectedPackage,
    required this.selectedDate,
    required this.timeSlot,
    required this.screenId,
    required this.selectedAddons,
    required this.totalAddonPrice,
  });

  final TheaterScreen screen;
  final ScreenPackageModel? selectedPackage;
  final String selectedDate;
  final TimeSlotModel timeSlot;
  final String screenId;
  final List<AddonModel> selectedAddons;
  final double totalAddonPrice;

  static const String routeName = '/extra-special';

  @override
  ConsumerState<ExtraSpecialScreen> createState() => _ExtraSpecialScreenState();
}

class _ExtraSpecialScreenState extends ConsumerState<ExtraSpecialScreen> {
  final List<AddonModel> _selectedExtraSpecials = [];
  double _totalExtraSpecialPrice = 0.0;

  @override
  Widget build(BuildContext context) {
    final extraSpecials = ref.watch(addonsByCategoryProvider(AddonCategoryParams(
      theaterId: widget.screen.theaterId,
      category: 'extra special service',
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
          'Extra Special',
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
            child: extraSpecials.when(
              data: (extraSpecialsList) {
                if (extraSpecialsList.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildExtraSpecialsList(extraSpecialsList);
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
          _buildProgressDot(false, 'Special Services'),
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

  Widget _buildExtraSpecialsList(List<AddonModel> extraSpecials) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make Your Experience Extra Special',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add these premium experiences to make your visit unforgettable',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: extraSpecials.length,
            itemBuilder: (context, index) {
              final extraSpecial = extraSpecials[index];
              return _buildExtraSpecialCard(extraSpecial);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSpecialCard(AddonModel extraSpecial) {
    final isSelected = _selectedExtraSpecials.contains(extraSpecial);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: InkWell(
        onTap: () {
          setState(() {
            final extraSpecialPriceWithTax = extraSpecial.price * 1.0354; // Add 3.54% tax
            if (isSelected) {
              _selectedExtraSpecials.remove(extraSpecial);
              _totalExtraSpecialPrice -= extraSpecialPriceWithTax;
            } else {
              _selectedExtraSpecials.add(extraSpecial);
              _totalExtraSpecialPrice += extraSpecialPriceWithTax;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: extraSpecial.hasImage
                      ? CachedNetworkImage(
                          imageUrl: extraSpecial.imageUrl!,
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
                              Icons.star,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.star, color: Colors.grey, size: 30),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extraSpecial.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      extraSpecial.displayDescription,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Okra',
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${(extraSpecial.price * 1.0354).round()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Okra',
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
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
            Icons.star_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Extra Special Items Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Skip to the next step to continue',
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
            'Error Loading Extra Specials',
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
            if (_totalExtraSpecialPrice > 0)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedExtraSpecials.length} Extra Special${_selectedExtraSpecials.length > 1 ? 's' : ''} Selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                    Text(
                      '₹${_totalExtraSpecialPrice.round()}',
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
                  'No extra specials selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Okra',
                    color: Colors.grey,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: _proceedToSpecialServices,
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
                'Continue',
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

  void _proceedToSpecialServices() {
    context.push(
      '/outside/${widget.screenId}/special-services',
      extra: {
        'screen': widget.screen,
        'selectedPackage': widget.selectedPackage,
        'selectedDate': widget.selectedDate,
        'timeSlot': widget.timeSlot,
        'screenId': widget.screenId,
        'selectedAddons': widget.selectedAddons,
        'totalAddonPrice': widget.totalAddonPrice,
        'selectedExtraSpecials': _selectedExtraSpecials,
        'totalExtraSpecialPrice': _totalExtraSpecialPrice,
      },
    );
  }
}