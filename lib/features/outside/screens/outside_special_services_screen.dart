import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/outside/models/addon_model.dart';
import 'package:sylonow_user/features/outside/providers/theater_screen_detail_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OutsideSpecialServicesScreen extends ConsumerStatefulWidget {
  static const String routeName = '/outside/special-services';

  final String screenId;
  final String selectedDate;
  final Map<String, dynamic> selectionData;

  const OutsideSpecialServicesScreen({
    super.key,
    required this.screenId,
    required this.selectedDate,
    required this.selectionData,
  });

  @override
  ConsumerState<OutsideSpecialServicesScreen> createState() =>
      _OutsideSpecialServicesScreenState();
}

class _OutsideSpecialServicesScreenState extends ConsumerState<OutsideSpecialServicesScreen> {
  final Map<String, int> selectedServices = {};

  @override
  Widget build(BuildContext context) {
    // Get theater information from selectionData to filter add-ons by theater
    final screen = widget.selectionData['screen'];
    final theaterId = screen != null ? screen.theaterId : null;

    // Fetch special service add-ons by theater and category 'special service'
    final addOnsAsync = theaterId != null
        ? ref.watch(addonsByCategoryProvider(AddonCategoryParams(
            theaterId: theaterId,
            category: 'special service',
          )))
        : const AsyncValue<List<AddonModel>>.data([]);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Extra Special Services',
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
          // Header Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make it extra special',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Okra',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add special services and gifts to make your celebration memorable',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Okra',
                  ),
                ),
                if (selectedServices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${selectedServices.length} services selected',
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

          // Services List
          Expanded(
            child: addOnsAsync.when(
              data: (addOns) {
                // Add-ons are already filtered by category 'special service' from provider
                final specialServices = addOns;
                
                if (specialServices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.card_giftcard_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No special services available',
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

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: specialServices.length,
                  itemBuilder: (context, index) {
                    final service = specialServices[index];
                    final quantity = selectedServices[service.id] ?? 0;
                    
                    return _buildServiceCard(service, quantity);
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
                      'Failed to load special services',
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
                    onPressed: _continueToAddons,
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
                    onPressed: _continueToAddons,
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
                      selectedServices.isEmpty ? 'Continue' : 'Continue (${selectedServices.length})',
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

  Widget _buildServiceCard(AddonModel service, int quantity) {
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
          // Service Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: service.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(
                        Icons.card_giftcard,
                        size: 30,
                        color: Colors.grey,
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.card_giftcard,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.card_giftcard,
                    size: 30,
                    color: Colors.grey,
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // Service Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontFamily: 'Okra',
                  ),
                ),
                
                if (service.description != null && service.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 8),
                
                Flexible(
                  child: Row(
                    children: [
                      Text(
                        '₹${service.price.round()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontFamily: 'Okra',
                        ),
                      ),

                      if (service.category?.isNotEmpty == true) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              service.category!.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[700],
                                fontFamily: 'Okra',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),

          // Quantity Controls
          if (quantity == 0)
            GestureDetector(
              onTap: () => _updateQuantity(service.id, 1),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _updateQuantity(service.id, quantity - 1),
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
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    quantity.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
                
                GestureDetector(
                  onTap: () => _updateQuantity(service.id, quantity + 1),
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

  void _updateQuantity(String serviceId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        selectedServices.remove(serviceId);
      } else {
        selectedServices[serviceId] = newQuantity;
      }
    });
  }

  void _continueToAddons() {
    // Prepare selected special services data
    final selectedSpecialServices = <Map<String, dynamic>>[];
    
    for (final entry in selectedServices.entries) {
      final serviceId = entry.key;
      final quantity = entry.value;
      
      selectedSpecialServices.add({
        'id': serviceId,
        'quantity': quantity,
      });
    }

    // Navigate to addons screen
    context.push(
      '/outside/${widget.screenId}/addons',
      extra: {
        ...widget.selectionData,
        'selectedSpecialServices': selectedSpecialServices,
        'selectedDate': widget.selectedDate,
        'screenId': widget.screenId,
      },
    );
  }
}