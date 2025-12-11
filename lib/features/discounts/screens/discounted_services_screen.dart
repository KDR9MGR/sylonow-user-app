import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_calculator.dart';
import '../../home/models/service_listing_model.dart';
import '../../home/providers/home_providers.dart';

class DiscountedServicesScreen extends ConsumerWidget {
  const DiscountedServicesScreen({super.key});

  static const String routeName = '/discounted-services';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredServicesState = ref.watch(featuredServicesProvider);

    // Debug logging
    print('🔍 Discounted Services Screen - Build called');
    print('🔍 Services count: ${featuredServicesState.services.length}');
    print('🔍 Has more: ${featuredServicesState.hasMore}');
    print('🔍 Current page: ${featuredServicesState.page}');

    // Log each service
    for (var i = 0; i < featuredServicesState.services.length; i++) {
      final service = featuredServicesState.services[i];
      print('🔍 Service $i: ${service.name}');
      print('   - Original: ${service.displayOriginalPrice}');
      print('   - Offer: ${service.displayOfferPrice}');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Super Saver Deals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Okra',
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'DEALS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
      body: featuredServicesState.services.isEmpty
          ? _buildLoadingState()
          : _buildDiscountedServicesList(featuredServicesState.services),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscountedServicesList(List<ServiceListingModel> allServices) {
    print('🔍 _buildDiscountedServicesList called with ${allServices.length} services');

    // Filter services with ANY discount (not just 50%+)
    final discountedServices = allServices.where((service) {
      print('🔍 Checking service: ${service.name}');
      print('   - displayOfferPrice: ${service.displayOfferPrice}');
      print('   - displayOriginalPrice: ${service.displayOriginalPrice}');

      if (service.displayOfferPrice == null || service.displayOriginalPrice == null) {
        print('   ❌ Skipped - missing price data');
        return false;
      }
      final discountPercentage = _calculateDiscountPercentage(service);
      print('   - Discount: ${discountPercentage.toStringAsFixed(1)}%');
      final hasDiscount = discountPercentage > 0;
      print('   ${hasDiscount ? "✅" : "❌"} Include: $hasDiscount');
      return hasDiscount; // Show any service with discount
    }).toList();

    print('🔍 Filtered to ${discountedServices.length} discounted services');

    if (discountedServices.isEmpty) {
      print('🔍 No discounted services - showing empty state');
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${discountedServices.length} Amazing Deals Found!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Okra',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Limited time offers with amazing discounts',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Okra',
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        // Services Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.70,
            ),
            itemCount: discountedServices.length,
            itemBuilder: (context, index) {
              final service = discountedServices[index];
              return _buildDiscountedServiceCard(service);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountedServiceCard(ServiceListingModel service) {
    final discountPercentage = _calculateDiscountPercentage(service);
    
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          context.push(
            '/service/${service.id}',
            extra: {
              'serviceName': service.name,
              'price': service.displayOfferPrice != null
                  ? PriceCalculator.formatPriceAsInt(
                      PriceCalculator.calculateTotalPriceWithTaxes(
                        service.displayOfferPrice!,
                      ),
                    )
                  : service.displayOriginalPrice != null
                  ? PriceCalculator.formatPriceAsInt(
                      PriceCalculator.calculateTotalPriceWithTaxes(
                        service.displayOriginalPrice!,
                      ),
                    )
                  : null,
              'rating': (service.rating ?? 4.9).toStringAsFixed(1),
              'reviewCount': service.reviewsCount ?? 102,
            },
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Image with discount badge
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: service.image ?? '',
                        width: double.infinity,
                        height: double.infinity,
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
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Discount badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${discountPercentage.round()}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ),
                    ),
                    // Rating badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              (service.rating ?? 4.9).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Okra',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Service Details
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Name
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Price Section
                      if (service.displayOfferPrice != null && service.displayOriginalPrice != null) ...[
                        Row(
                          children: [
                            // Offer Price
                            Text(
                              PriceCalculator.formatPriceAsInt(
                                PriceCalculator.calculateTotalPriceWithTaxes(
                                  service.displayOfferPrice!,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Okra',
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Original Price (crossed out)
                        Text(
                          PriceCalculator.formatPriceAsInt(
                            PriceCalculator.calculateTotalPriceWithTaxes(
                              service.displayOriginalPrice!,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Okra',
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ] else if (service.displayOriginalPrice != null) ...[
                        Text(
                          PriceCalculator.formatPriceAsInt(
                            PriceCalculator.calculateTotalPriceWithTaxes(
                              service.displayOriginalPrice!,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Save amount
                      if (service.displayOfferPrice != null && service.displayOriginalPrice != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Save ${PriceCalculator.formatPriceAsInt((service.displayOriginalPrice! - service.displayOfferPrice!) * 1.18)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Okra',
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Deals Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for amazing discounts!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: 'Okra',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate discount percentage
  double _calculateDiscountPercentage(ServiceListingModel service) {
    if (service.displayOfferPrice == null || service.displayOriginalPrice == null) {
      return 0.0;
    }
    
    final originalPrice = service.displayOriginalPrice!;
    final offerPrice = service.displayOfferPrice!;
    
    if (originalPrice <= offerPrice) {
      return 0.0;
    }
    
    return ((originalPrice - offerPrice) / originalPrice) * 100;
  }
}