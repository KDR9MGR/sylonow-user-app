import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/outside/models/addon_model.dart';
import 'package:sylonow_user/features/outside/providers/outside_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OutsideAddonsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/outside/addons';

  final String screenId;
  final String selectedDate;
  final Map<String, dynamic> selectionData;

  const OutsideAddonsScreen({
    super.key,
    required this.screenId,
    required this.selectedDate,
    required this.selectionData,
  });

  @override
  ConsumerState<OutsideAddonsScreen> createState() =>
      _OutsideAddonsScreenState();
}

class _OutsideAddonsScreenState extends ConsumerState<OutsideAddonsScreen> {
  final Map<String, int> selectedAddons = {};

  @override
  Widget build(BuildContext context) {
    final addOnsAsync = ref.watch(addOnsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add-ons & Extras',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Okra',
              ),
            ),
            if (selectedAddons.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getTotalSelectedCount()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enhance your experience',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Okra',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add extra services and amenities to make your celebration even better',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Okra',
                  ),
                ),
                if (selectedAddons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_getTotalSelectedCount()} add-ons selected • ₹${_getTotalPrice().round()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Add-ons List
          Expanded(
            child: addOnsAsync.when(
              data: (addOns) {
                final activeAddOns = addOns.where((addon) => addon.isActive).toList();
                
                if (activeAddOns.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_box_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No add-ons available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group addons by category
                final Map<String, List<AddonModel>> categorizedAddons = {};
                for (final addon in activeAddOns) {
                  final category = addon.category ?? 'Other';
                  if (!categorizedAddons.containsKey(category)) {
                    categorizedAddons[category] = [];
                  }
                  categorizedAddons[category]!.add(addon);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categorizedAddons.length,
                  itemBuilder: (context, categoryIndex) {
                    final category = categorizedAddons.keys.elementAt(categoryIndex);
                    final categoryAddons = categorizedAddons[category]!;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Header
                        if (categorizedAddons.length > 1) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getCategoryDisplayName(category),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontFamily: 'Okra',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${categoryAddons.length} items',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Addons in this category
                        ...categoryAddons.map((addon) => _buildAddonCard(addon)),
                        
                        if (categoryIndex < categorizedAddons.length - 1)
                          const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load add-ons',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Okra',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Continue Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Skip Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _continueToCheckout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Continue Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _continueToCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      selectedAddons.isEmpty 
                          ? 'Continue' 
                          : 'Continue (₹${_getTotalPrice().round()})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Okra',
                      ),
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

  Widget _buildAddonCard(AddonModel addon) {
    final quantity = selectedAddons[addon.id] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: quantity > 0 ? AppTheme.primaryColor : Colors.grey[200]!,
          width: quantity > 0 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: quantity > 0 
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Addon Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: addon.imageUrl != null && addon.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: addon.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Icon(
                        _getCategoryIcon(addon.category ?? ''),
                        size: 30,
                        color: Colors.grey,
                      ),
                      errorWidget: (context, url, error) => Icon(
                        _getCategoryIcon(addon.category ?? ''),
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Icon(
                    _getCategoryIcon(addon.category ?? ''),
                    size: 30,
                    color: Colors.grey,
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // Addon Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addon.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontFamily: 'Okra',
                  ),
                ),
                
                if (addon.description != null && addon.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    addon.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Text(
                      addon.formattedPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                    
                    if (addon.category?.isNotEmpty == true) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getCategoryDisplayName(addon.category ?? ''),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                            fontFamily: 'Okra',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Quantity Controls
          if (quantity == 0)
            GestureDetector(
              onTap: () => _updateQuantity(addon.id, 1),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: () => _updateQuantity(addon.id, quantity - 1),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.black87,
                      size: 16,
                    ),
                  ),
                ),
                
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    quantity.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
                
                GestureDetector(
                  onTap: () => _updateQuantity(addon.id, quantity + 1),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _updateQuantity(String addonId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        selectedAddons.remove(addonId);
      } else {
        selectedAddons[addonId] = newQuantity;
      }
    });
  }

  int _getTotalSelectedCount() {
    return selectedAddons.values.fold(0, (sum, quantity) => sum + quantity);
  }

  double _getTotalPrice() {
    final addOnsAsync = ref.read(addOnsProvider);
    return addOnsAsync.when(
      data: (addOns) {
        double total = 0;
        for (final entry in selectedAddons.entries) {
          final addon = addOns.firstWhere(
            (a) => a.id == entry.key,
            orElse: () => AddonModel(
              id: '',
              name: '',
              price: 0,
              isActive: false,
              category: '',
            ),
          );
          total += addon.price * entry.value;
        }
        return total;
      },
      loading: () => 0,
      error: (_, __) => 0,
    );
  }

  void _continueToCheckout() {
    // Prepare selected addons data
    final selectedAddonsData = <Map<String, dynamic>>[];

    for (final entry in selectedAddons.entries) {
      final addonId = entry.key;
      final quantity = entry.value;

      selectedAddonsData.add({
        'id': addonId,
        'quantity': quantity,
      });
    }

    // Navigate to checkout screen
    context.push(
      '/outside/${widget.screenId}/checkout',
      extra: {
        ...widget.selectionData,
        'selectedAddons': selectedAddonsData,
        'totalAddonsPrice': _getTotalPrice(),
        'selectedDate': widget.selectedDate,
        'screenId': widget.screenId,
      },
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return 'Food & Beverages';
      case 'decorations':
        return 'Decorations';
      case 'entertainment':
        return 'Entertainment';
      case 'photography':
        return 'Photography';
      case 'special_services':
        return 'Special Services';
      case 'gifts':
        return 'Gifts & Treats';
      case 'cake':
        return 'Cakes';
      case 'flowers':
        return 'Flowers';
      default:
        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1)}'
                : word)
            .join(' ');
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'decorations':
        return Icons.celebration;
      case 'entertainment':
        return Icons.music_note;
      case 'photography':
        return Icons.photo_camera;
      case 'special_services':
        return Icons.room_service;
      case 'gifts':
        return Icons.card_giftcard;
      case 'cake':
        return Icons.cake;
      case 'flowers':
        return Icons.local_florist;
      default:
        return Icons.add_box;
    }
  }
}