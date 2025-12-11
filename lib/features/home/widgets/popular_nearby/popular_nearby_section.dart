import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/core/utils/price_calculator.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/home/providers/home_providers.dart';
import 'package:sylonow_user/features/address/providers/address_providers.dart';

class PopularNearbySection extends ConsumerWidget {
  const PopularNearbySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: Row(
            children: [
              const Text(
                'Near By You',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Okra',
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  context.push('/nearby-services');
                },
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Radius-based Popular Nearby Services (20km from selected address)
        Consumer(
          builder: (context, ref, child) {
            // Debug: Watch the selected address to see when it changes
            final selectedAddress = ref.watch(selectedAddressProvider);
            //('🎯 PopularNearbySection: Building with address: ${selectedAddress?.address}');
            //('🎯 PopularNearbySection: Coordinates: (${selectedAddress?.latitude}, ${selectedAddress?.longitude})');

            final servicesAsync = ref.watch(popularNearbyServicesProvider);
            return servicesAsync.when(
              data: (services) {
                //('🎯 PopularNearbySection: Received ${services.length} services');
                if (services.isNotEmpty) {
                  //('🎯 First service: ${services.first.name}, distance: ${services.first.distanceKm} km, price: ${services.first.calculatedPrice}');
                }
                return services.isEmpty
                    ? _buildEmptyState()
                    : _buildServicesList(services, isLocationBased: true);
              },
              loading: () {
                //('🎯 PopularNearbySection: Loading services...');
                return _buildLoadingState();
              },
              error: (error, stack) {
                //('🎯 PopularNearbySection: Error loading services: $error');
                return _buildErrorState();
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildServicesList(
    List<ServiceListingModel> services, {
    bool isLocationBased = true,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: services.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(
          service,
          context,
          isLocationBased: isLocationBased,
        );
      },
    );
  }

  Widget _buildServiceCard(
    ServiceListingModel service,
    BuildContext context, {
    bool isLocationBased = false,
  }) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/service/${service.id}',
          extra: {
            'service': service, // Pass the entire service with calculated prices
            'serviceName': service.name,
            // RPC already includes location fees and taxes - use directly
            'price': service.displayOfferPrice != null
                ? PriceCalculator.formatPriceAsInt(service.displayOfferPrice!)
                : service.displayOriginalPrice != null
                ? PriceCalculator.formatPriceAsInt(service.displayOriginalPrice!)
                : null,
            'rating': (service.rating ?? 4.9).toStringAsFixed(1),
            'reviewCount': service.reviewsCount ?? 102,
          },
        );
      },
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD6D8DC), width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Image section - 99x99px with 16px border radius
            SizedBox(
              width: 120,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: service.image ?? '',
                  width: 99,
                  height: 99,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 99,
                    height: 99,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 99,
                    height: 99,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
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
            ),
            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Service title
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Color(0xFF333333),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description ??
                          'Beautiful engagement decoration service',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Okra',
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Distance indicator (if available)
                    if (service.distanceKm != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 10,
                            color: Color(0xFF999999),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${service.distanceKm!.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Okra',
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Price section
                    Row(
                      children: [
                        if (service.displayOfferPrice != null) ...[
                          Text(
                            // RPC already includes location fees and taxes - use directly
                            PriceCalculator.formatPriceAsInt(service.displayOfferPrice!),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Okra',
                              color: Color(0xFF333333),
                            ),
                          ),
                          if (service.displayOriginalPrice != null &&
                              service.displayOriginalPrice! >
                                  service.displayOfferPrice!) ...[
                            const SizedBox(width: 8),
                            Text(
                              // RPC already includes location fees and taxes - use directly
                              PriceCalculator.formatPriceAsInt(service.displayOriginalPrice!),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Okra',
                                color: Color(0xFF999999),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ] else if (service.displayOriginalPrice != null) ...[
                          Text(
                            // RPC already includes location fees and taxes - use directly
                            PriceCalculator.formatPriceAsInt(service.displayOriginalPrice!),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Okra',
                              color: Color(0xFF333333),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Price on request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Okra',
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Spacer(),
                    // Rating and description row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD700),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          (service.rating ?? 4.9).toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Color(0xFF333333),
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

  Widget _buildLoadingState() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildLoadingCard(context),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      height: 101,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6D8DC), width: 1.2),
      ),
      child: Row(
        children: [
          // Image placeholder
          Container(
            width: 99,
            height: 99,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
            ),
          ),
          // Content placeholder
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title placeholder
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Price placeholder
                  Container(
                    height: 16,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Rating and description placeholder
                  Row(
                    children: [
                      Container(
                        height: 12,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.location_searching, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No services found nearby',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try expanding your search radius or check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontFamily: 'Okra',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Unable to load popular services',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
          ),
        ],
      ),
    );
  }
}
