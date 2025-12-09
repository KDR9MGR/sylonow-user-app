import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
// removed unused dart:ui import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/welcome_providers.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../core/utils/price_rounding.dart';
import '../../../core/widgets/custom_shimmer.dart';
import '../../booking/screens/checkout_screen.dart';
import '../../address/providers/address_providers.dart';
import '../../home/models/service_listing_model.dart';
import '../../home/models/vendor_model.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../reviews/screens/reviews_screen.dart';
import '../../wishlist/providers/wishlist_providers.dart';
// Removed unused vendor model import

// Provider to fetch individual service details with location-based pricing
final serviceDetailProvider =
    FutureProvider.family.autoDispose<ServiceListingModel?, String>((ref, serviceId) async {
      try {
        debugPrint('🔄 Fetching service details for ID: $serviceId');
        final repository = ref.watch(homeRepositoryProvider);
        final selectedAddress = ref.watch(selectedAddressProvider);

        final service = await repository.getServiceById(serviceId);

        if (service != null) {
          debugPrint('✅ Service loaded successfully:');
          debugPrint('  - Name: ${service.name}');
          debugPrint('  - Image: ${service.image}');
          debugPrint('  - Photos count: ${service.photos?.length ?? 0}');
          debugPrint('  - Category: ${service.category}');
          debugPrint('  - Original Price: ${service.originalPrice}');
          debugPrint('  - Offer Price: ${service.offerPrice}');
          debugPrint('  - Free Service KM: ${service.freeServiceKm}');
          debugPrint('  - Extra Charges Per KM: ${service.extraChargesPerKm}');
          debugPrint('  - Service Location: (${service.latitude}, ${service.longitude})');

          // Apply location-based pricing if user has selected an address
          if (selectedAddress != null &&
              selectedAddress.latitude != null &&
              selectedAddress.longitude != null) {
            debugPrint('🧮 Calculating location-based pricing...');
            debugPrint('  - User location: (${selectedAddress.latitude}, ${selectedAddress.longitude})');

            final serviceWithLocation = service.copyWithLocationData(
              userLat: selectedAddress.latitude,
              userLon: selectedAddress.longitude,
            );

            debugPrint('  - Distance: ${serviceWithLocation.distanceKm} km');
            debugPrint('  - Calculated Price: ${serviceWithLocation.calculatedPrice}');
            debugPrint('  - Adjusted Offer Price: ${serviceWithLocation.adjustedOfferPrice}');
            debugPrint('  - Display Offer Price: ${serviceWithLocation.displayOfferPrice}');
            debugPrint('  - Is Price Adjusted: ${serviceWithLocation.isPriceAdjusted}');

            return serviceWithLocation;
          }
        } else {
          debugPrint('❌ Service not found for ID: $serviceId');
        }

        return service;
      } catch (e, stackTrace) {
        debugPrint('❌ Error fetching service details for ID: $serviceId');
        debugPrint('Error: $e');
        debugPrint('StackTrace: $stackTrace');
        rethrow;
      }
    });

// Parameters class for related services provider
class RelatedServicesParams {
  final String serviceId;
  final String? category;

  const RelatedServicesParams({required this.serviceId, this.category});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelatedServicesParams &&
          runtimeType == other.runtimeType &&
          serviceId == other.serviceId &&
          category == other.category;

  @override
  int get hashCode => serviceId.hashCode ^ category.hashCode;
}

// Provider to fetch related services with location-based filtering (20km radius)
final relatedServicesProvider =
    FutureProvider.family.autoDispose<List<ServiceListingModel>, RelatedServicesParams>((
      ref,
      params,
    ) async {
      try {
        debugPrint('🔄 Fetching related services for:');
        debugPrint('  - Service ID: ${params.serviceId}');
        debugPrint('  - Category: ${params.category}');

        final repository = ref.watch(homeRepositoryProvider);

        // Watch selected address for location-based filtering (20km radius like popular nearby)
        final selectedAddress = ref.watch(selectedAddressProvider);
        final userLat = selectedAddress?.latitude;
        final userLon = selectedAddress?.longitude;

        debugPrint('📍 Related Services: User location: ($userLat, $userLon)');
        debugPrint('📍 Selected address: ${selectedAddress?.address}');

        // Fetch related services (repository will handle location filtering if coordinates provided)
        final relatedServices = await repository.getRelatedServices(
          currentServiceId: params.serviceId,
          category: params.category,
        );

        // If user has location, apply client-side filtering for 20km radius and add location data
        if (userLat != null && userLon != null && relatedServices.isNotEmpty) {
          debugPrint('📍 Applying 20km radius filter and location data to ${relatedServices.length} services');

          final servicesWithLocation = relatedServices
              .map((service) => service.copyWithLocationData(
                    userLat: userLat,
                    userLon: userLon,
                  ))
              .where((service) => service.distanceKm != null && service.distanceKm! <= 20.0) // 20km radius
              .toList();

          debugPrint('📍 ${servicesWithLocation.length} services within 20km radius');

          // Sort by distance (nearest first)
          servicesWithLocation.sort((a, b) {
            final distA = a.distanceKm ?? double.infinity;
            final distB = b.distanceKm ?? double.infinity;
            return distA.compareTo(distB);
          });

          return servicesWithLocation;
        }

        debugPrint('✅ Related services loaded: ${relatedServices.length} items (no location filtering)');
        for (var service in relatedServices.take(3)) {
          debugPrint('  - ${service.name} (${service.id})');
        }

        return relatedServices;
      } catch (e, stackTrace) {
        debugPrint('❌ Error fetching related services:');
        debugPrint('  - Service ID: ${params.serviceId}');
        debugPrint('  - Category: ${params.category}');
        debugPrint('  - Error: $e');
        debugPrint('  - StackTrace: $stackTrace');
        rethrow;
      }
    });

// Model for service addons
class ServiceAddon {
  final String id;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final bool isCustomizable;
  final String? customizationInputType;
  final double discountPrice;

  const ServiceAddon({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.isCustomizable = false,
    this.customizationInputType,
    required this.discountPrice,
  });

  factory ServiceAddon.fromJson(Map<String, dynamic> json) {
    final originalPrice = json['original_price'] != null
        ? (json['original_price'] as num).toDouble()
        : null;
    final discountPrice =
        (json['discount_price'] as num?)?.toDouble() ?? originalPrice ?? 1.0;

    // Try image_url first (from repository), then images array (from direct DB)
    String? imageUrl;
    if (json['image_url'] != null) {
      imageUrl = json['image_url'] as String?;
    } else if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      imageUrl = (json['images'] as List)[0] as String?;
    }

    return ServiceAddon(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: discountPrice > 0 ? discountPrice : originalPrice ?? 0.0,
      originalPrice: originalPrice,
      imageUrl: imageUrl,
      isCustomizable: json['is_customizable'] as bool? ?? false,
      customizationInputType: json['customization_input_type'] as String?,
      discountPrice: discountPrice,
    );
  }
}

// Provider to fetch service addons
final serviceAddonsProvider = FutureProvider.family<List<ServiceAddon>, String>(
  (ref, vendorId) async {
    try {
      debugPrint('🔄 Fetching service addons for vendor ID: $vendorId');

      final repository = ref.watch(homeRepositoryProvider);
      final response = await repository.getServiceAddons(vendorId);

      final addons = response
          .map((json) => ServiceAddon.fromJson(json))
          .toList();

      debugPrint('✅ Service addons loaded: ${addons.length} items');
      for (var addon in addons.take(3)) {
        debugPrint('  - ${addon.name} (₹${addon.price})');
      }

      return addons;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching service addons:');
      debugPrint('  - Vendor ID: $vendorId');
      debugPrint('  - Error: $e');
      debugPrint('  - StackTrace: $stackTrace');
      return []; // Return empty list instead of throwing error
    }
  },
);

class ServiceDetailScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final String? serviceName;
  final String? price;
  final String? rating;
  final int? reviewCount;
  final ServiceListingModel? service; // Pre-calculated service passed from previous screen

  const ServiceDetailScreen({
    super.key,
    required this.serviceId,
    this.serviceName,
    this.price,
    this.rating,
    this.reviewCount,
    this.service, // Optional: if provided, skip fetching from DB
  });

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  // Track added addons with their custom text and character count
  final Map<String, Map<String, dynamic>> _addedAddons = {};

  // Placeholder for when no images are available
  final String _placeholderImage =
      'https://via.placeholder.com/400x300/f0f0f0/999999?text=No+Image';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If service was passed from previous screen, use it directly
    if (widget.service != null) {
      debugPrint('✅ Using pre-calculated service from navigation');
      debugPrint('  - Service: ${widget.service!.name}');
      debugPrint('  - Offer Price: ${widget.service!.offerPrice}');
      debugPrint('  - Display Offer Price: ${widget.service!.displayOfferPrice}');
      debugPrint('  - Calculated Price: ${widget.service!.calculatedPrice}');
      debugPrint('  - Distance: ${widget.service!.distanceKm} km');

      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildServiceDetail(widget.service!),
      );
    }

    // Otherwise fetch from database (fallback for direct navigation)
    debugPrint('⚠️ Service not passed, fetching from database...');
    final serviceDetailAsync = ref.watch(
      serviceDetailProvider(widget.serviceId),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: serviceDetailAsync.when(
        loading: () => const _LoadingScreen(),
        error: (error, stack) {
          // Enhanced error logging
          debugPrint('ServiceDetailScreen Error: $error');
          debugPrint('ServiceId: ${widget.serviceId}');
          return _ErrorScreen(
            error: error.toString(),
            onRetry: () => ref.refresh(serviceDetailProvider(widget.serviceId)),
          );
        },
        data: (service) {
          if (service == null) {
            debugPrint('❌ Service data is null for ID: ${widget.serviceId}');
            return _ErrorScreen(
              error: 'Service not found',
              onRetry: () =>
                  ref.refresh(serviceDetailProvider(widget.serviceId)),
            );
          }

          debugPrint(
            '✅ Service detail screen rendering with service: ${service.name}',
          );

          return _buildServiceDetail(service);
        },
      ),
    );
  }

  Widget _buildServiceDetail(ServiceListingModel service) {
    // Log service data usage
    debugPrint('🏗️ Building service detail for: ${service.name}');
    debugPrint('  - Has photos: ${service.photos?.isNotEmpty == true}');
    debugPrint('  - Has image: ${service.image?.isNotEmpty ?? false}');
    debugPrint(
      '  - Has pricing: original=${service.originalPrice}, offer=${service.offerPrice}, display=${service.displayOfferPrice}',
    );
    debugPrint('  - Distance: ${service.distanceKm} km');
    debugPrint('  - Calculated Price: ${service.calculatedPrice}');

    // Use fetched service data with fallbacks for backward compatibility
    final serviceName = service.name.isNotEmpty
        ? service.name
        : (widget.serviceName ?? 'Service');
    final serviceDescription = service.description?.isNotEmpty == true
        ? service.description!
        : 'A beautiful service designed to make your celebration special.';
    final serviceRating =
        service.rating?.toStringAsFixed(1) ?? widget.rating ?? '4.9';
    final reviewCount = service.reviewsCount ?? widget.reviewCount ?? 0;
    final originalPrice = service.displayOriginalPrice ?? service.originalPrice;
    final offerPrice = service.displayOfferPrice ?? service.offerPrice;
    final promotionalTag = service.promotionalTag;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(service, serviceName),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServiceInfo(
                  service,
                  serviceName,
                  originalPrice,
                  offerPrice,
                  serviceRating,
                  reviewCount,
                  promotionalTag,
                ),
                Container(height: 10, color: Colors.grey[200]),
                _buildAddonsSection(service),
                _buildRelatedServices(service),
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBookingBar(service, serviceName),
    );
  }

  Widget _buildSliverAppBar(ServiceListingModel service, String serviceName) {
    // Create image list from service photos array, or fallback to cover photo, or placeholder
    List<String> imageList = [];

    if (service.photos != null && service.photos!.isNotEmpty) {
      // Filter out null or empty image URLs from photos array
      imageList = service.photos!
          .where((photo) => photo.isNotEmpty && photo.trim().isNotEmpty)
          .toList();
    }

    // If no valid photos, try cover photo
    if (imageList.isEmpty &&
        service.image?.isNotEmpty == true &&
        service.image!.trim().isNotEmpty) {
      imageList = [service.image!];
    }

    // If still no images, use placeholder
    if (imageList.isEmpty) {
      imageList = [_placeholderImage];
    }
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.share, color: Colors.black),
            onPressed: () {
              _shareService(serviceName);
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemCount: imageList.length,
              itemBuilder: (context, index) {
                final imageUrl = imageList[index];
                final isNetworkImage = imageUrl.startsWith('http');

                debugPrint(
                  'Loading main image $index: $imageUrl (isNetwork: $isNetworkImage)',
                );

                return Hero(
                  tag: 'service_detail_${widget.serviceId}',
                  child: Container(
                    child: isNetworkImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.pink,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              debugPrint(
                                'Main image load error for $url: $error',
                              );
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 50,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Image failed to load',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : imageUrl == _placeholderImage
                        ? Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No image available',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
            // Image indicators
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...imageList.take(4).toList().asMap().entries.map((entry) {
                    return Container(
                      width: 60,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentImageIndex == entry.key
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: imageList[entry.key].startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: imageList[entry.key],
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                    'Thumbnail image error for ${imageList[entry.key]}: $error',
                                  );
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 16,
                                    ),
                                  );
                                },
                              )
                            : imageList[entry.key] == _placeholderImage
                            ? Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              )
                            : Image.asset(
                                imageList[entry.key],
                                fit: BoxFit.cover,
                              ),
                      ),
                    );
                  }),
                  if (imageList.length > 4)
                    Container(
                      width: 60,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '+${imageList.length - 4}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceInfo(
    ServiceListingModel service,
    String serviceName,
    double? originalPrice,
    double? offerPrice,
    String rating,
    int reviewCount,
    String? promotionalTag,
  ) {
    final description = service.description ?? 'A beautiful service designed to make your celebration special.';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  serviceName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Okra',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, child) {
                  final isInWishlistAsync = ref.watch(
                    isServiceInWishlistProvider(widget.serviceId),
                  );

                  return isInWishlistAsync.when(
                    data: (isInWishlist) => Container(
                      padding: isInWishlist
                          ? const EdgeInsets.all(0)
                          : const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(wishlistNotifierProvider.notifier)
                              .toggleWishlist(widget.serviceId);
                        },
                        child: isInWishlist
                            ? Lottie.asset(
                                'assets/animations/like.json',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                repeat: false,
                              )
                            : Icon(
                                Icons.favorite_border,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                      ),
                    ),
                    loading: () => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                    ),
                    error: (error, stack) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price and discount tag section
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildPriceSectionHorizontal(originalPrice, offerPrice),
              const SizedBox(width: 12),
              if (offerPrice != null &&
                  originalPrice != null &&
                  offerPrice < originalPrice)
                _buildDiscountTag(originalPrice, offerPrice, promotionalTag),
            ],
          ),
          const SizedBox(height: 4),
          // Rating section
          Row(
            children: [
              Icon(Icons.star, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text(
                rating,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($reviewCount)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),

          // Description section with Read More
          const SizedBox(height: 16),
          _ExpandableDescription(description: description),
        ],
      ),
    );
  }

  Widget _buildPriceSectionHorizontal(
    double? originalPrice,
    double? offerPrice,
  ) {
    if (offerPrice != null &&
        originalPrice != null &&
        offerPrice < originalPrice) {
      // Calculate tax-inclusive prices
      final taxInclusiveOfferPrice =
          PriceCalculator.calculateTotalPriceWithTaxes(offerPrice);
      final taxInclusiveOriginalPrice =
          PriceCalculator.calculateTotalPriceWithTaxes(originalPrice);

      // Show discounted price horizontally with tax-inclusive amounts
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                PriceCalculator.formatPriceAsInt(taxInclusiveOfferPrice),
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: AppTheme.primaryColor,
                  fontFamily: 'Okra',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                PriceCalculator.formatPriceAsInt(taxInclusiveOriginalPrice),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                  fontFamily: 'Okra',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'All taxes included',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w500,
              fontFamily: 'Okra',
            ),
          ),
        ],
      );
    } else if (originalPrice != null) {
      // Calculate tax-inclusive price for regular pricing
      final taxInclusivePrice = PriceCalculator.calculateTotalPriceWithTaxes(
        originalPrice,
      );

      // Show regular price with tax-inclusive amount
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PriceCalculator.formatPriceAsInt(taxInclusivePrice),
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              color: AppTheme.primaryColor,
              fontFamily: 'Okra',
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'All taxes included',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w500,
              fontFamily: 'Okra',
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDiscountTag(
    double? originalPrice,
    double? offerPrice,
    String? promotionalTag,
  ) {
    if (offerPrice != null &&
        originalPrice != null &&
        offerPrice < originalPrice) {
      // Calculate savings based on tax-inclusive prices
      final taxInclusiveOriginalPrice =
          PriceCalculator.calculateTotalPriceWithTaxes(originalPrice);
      final taxInclusiveOfferPrice =
          PriceCalculator.calculateTotalPriceWithTaxes(offerPrice);
      final savings = (taxInclusiveOriginalPrice - taxInclusiveOfferPrice)
          .round();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Save ₹${_formatNumberWithCommas(savings)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Okra',
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPriceSection(double? originalPrice, double? offerPrice) {
    if (offerPrice != null &&
        originalPrice != null &&
        offerPrice < originalPrice) {
      // Show discounted price
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                PriceCalculator.formatPriceAsInt(
                  PriceCalculator.calculateTotalPriceWithTaxes(offerPrice),
                ),
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: AppTheme.primaryColor,
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                PriceCalculator.formatPriceAsInt(
                  PriceCalculator.calculateTotalPriceWithTaxes(originalPrice),
                ),
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Save ₹${_formatNumberWithCommas((PriceCalculator.calculateTotalPriceWithTaxes(originalPrice) - PriceCalculator.calculateTotalPriceWithTaxes(offerPrice)).round())}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      );
    } else if (originalPrice != null) {
      // Show regular price
      return Text(
        PriceCalculator.formatPriceAsInt(
          PriceCalculator.calculateTotalPriceWithTaxes(originalPrice),
        ),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
          fontFamily: 'Okra',
        ),
      );
    } else {
      // Show fallback price
      return Text(
        widget.price != null
            ? _formatPriceToRupees(widget.price!)
            : 'Price on request',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
          fontFamily: 'Okra',
        ),
      );
    }
  }

  Widget _buildDescription(String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey[700],
              fontFamily: 'Okra',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonsSection(ServiceListingModel service) {
    return Consumer(
      builder: (context, ref, child) {
        final serviceAddonsAsync = ref.watch(
          serviceAddonsProvider(service.vendorId!),
        );

        return serviceAddonsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: Colors.pink)),
          ),
          error: (error, stack) {
            debugPrint('Addons error: $error');
            return const SizedBox.shrink(); // Hide section on error
          },
          data: (addons) {
            if (addons.isEmpty) {
              return const SizedBox.shrink(); // Hide section if no addons
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Special Touch-ups',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: addons.length,
                      itemBuilder: (context, index) {
                        final addon = addons[index];
                        return Container(
                          width: 158,
                          margin: EdgeInsets.only(
                            right: index < addons.length - 1 ? 16 : 0,
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
        );
      },
    );
  }

  Widget _buildAddonCard(ServiceAddon addon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Container(
            height: 157,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: addon.imageUrl != null && addon.imageUrl!.isNotEmpty
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
                        child: Icon(Icons.image, color: Colors.grey, size: 40),
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
                    addon.name,
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
                  if (addon.description != null &&
                      addon.description!.isNotEmpty)
                    Text(
                      addon.description!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Okra',
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  // Price and Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (addon.originalPrice != null &&
                              addon.originalPrice! > addon.price)
                            FutureBuilder<double>(
                              future: PriceCalculator.calculateCheckoutTotalWithTaxesRPC(
                                addon.originalPrice!,
                                vendorHasGst: false, // Add-ons don't have GST
                              ),
                              builder: (context, snapshot) {
                                final price = snapshot.data ?? 
                                    PriceCalculator.calculateCheckoutTotalWithTaxes(
                                      addon.originalPrice!, vendorHasGst: false);
                                return Text(
                                  PriceCalculator.formatPriceAsInt(price),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Okra',
                                    color: Color(0xFF858585),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                );
                              },
                            ),
                          FutureBuilder<double>(
                            future: PriceCalculator.calculateCheckoutTotalWithTaxesRPC(
                              addon.price,
                              vendorHasGst: false, // Add-ons don't have GST
                            ),
                            builder: (context, snapshot) {
                              final price = snapshot.data ?? 
                                  PriceCalculator.calculateCheckoutTotalWithTaxes(
                                    addon.price, vendorHasGst: false);
                              return Text(
                                PriceCalculator.formatPriceAsInt(price),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Okra',
                                  color: Color(0xFF171717),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      _buildAddonButton(addon),
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

  Widget _buildAddonButton(ServiceAddon addon) {
    final bool isAdded = _addedAddons.containsKey(addon.id);

    if (isAdded) {
      final addonData = _addedAddons[addon.id]!;
      final int characterCount = addonData['characterCount'] as int;

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2156D5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: InkWell(
          onTap: () {
            // Handle edit addon functionality
            _handleAddonEdit(addon);
          },
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '$characterCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2156D5)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: InkWell(
          onTap: () {
            // Handle add addon functionality
            _handleAddonAdd(addon);
          },
          borderRadius: BorderRadius.circular(5),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Add',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Okra',
                color: Color(0xFF2156D5),
              ),
            ),
          ),
        ),
      );
    }
  }

  void _handleAddonAdd(ServiceAddon addon) {
    debugPrint('Adding addon: ${addon.name} (₹${addon.price})');

    // Only show customization dialog for customizable addons
    if (addon.isCustomizable) {
      _showCustomizationDialog(addon, isEdit: false);
    } else {
      // For non-customizable addons, add directly without popup
      _addNonCustomizableAddon(addon);
    }
  }

  void _handleAddonEdit(ServiceAddon addon) {
    debugPrint('Editing addon: ${addon.name}');

    // Show customization dialog with existing data for editing
    _showCustomizationDialog(addon, isEdit: true);
  }

  void _addNonCustomizableAddon(ServiceAddon addon) {
    debugPrint('Adding non-customizable addon: ${addon.name}');

    // Calculate total price including transaction fee (same as what user sees in UI)
    final totalPriceWithFeesRaw = addon.price + (addon.price * 0.0354);
    // Apply rounding to ensure add-on prices end with 49 or 99
    final totalPriceWithFees = PriceRounding.applyFinalRounding(totalPriceWithFeesRaw);

    // Store addon data with default values
    setState(() {
      _addedAddons[addon.id] = {
        'name': addon.name,
        'price': addon.price,
        'customText': '',
        'characterCount': 1, // Default count for non-customizable
        'totalPrice': totalPriceWithFees, // Include transaction fee like UI shows
        'isCustomizable': addon.isCustomizable,
        'addon': addon, // Keep the addon object for reference if needed
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${addon.name} added for ₹${addon.price.toStringAsFixed(2)}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addRegularAddon(ServiceAddon addon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${addon.name} added to your selection'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCustomizationDialog(ServiceAddon addon, {bool isEdit = false}) {
    final TextEditingController controller = TextEditingController();
    double calculatedPrice = 0.0; // Start with 0 until user enters text

    // If editing, pre-fill with existing data
    if (isEdit && _addedAddons.containsKey(addon.id)) {
      final existingData = _addedAddons[addon.id]!;
      controller.text = existingData['customText'] as String;
      calculatedPrice =
          ((existingData['characterCount'] as int) * addon.discountPrice) +
          ((existingData['characterCount'] as int) * addon.discountPrice) *
              0.0354;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(
                  maxHeight: 600,
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      isEdit ? 'Edit ${addon.name}' : 'Customize ${addon.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Addon Image
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child:
                                      addon.imageUrl != null &&
                                          addon.imageUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: addon.imageUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.pink,
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
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
                            ),
                            if (addon.description != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  addon.description!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontFamily: 'Okra',
                                  ),
                                ),
                              ),
                            Text(
                              'Enter name to customize:',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Okra',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              keyboardType: TextInputType.text,
                              onChanged: (value) {
                                setState(() {
                                  // Always calculate based on character count with taxes (no convenience fee)
                                  final characterCount = value.length;
                                  final basePrice = characterCount * addon.discountPrice;
                                  // Add transaction fee (3.54%) but no convenience fee for add-ons
                                  final basePriceWithFeesRaw = basePrice + (basePrice * 0.0354);
                                  // Apply rounding to ensure add-on prices end with 49 or 99
                                  calculatedPrice = PriceRounding.applyFinalRounding(basePriceWithFeesRaw);
                                });
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2156D5),
                                  ),
                                ),
                                hintText: 'Enter name (e.g., "Sa")',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Price (${controller.text.length} characters):',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                  Text(
                                    '₹${calculatedPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2156D5),
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (controller.text.trim().isNotEmpty) {
                              Navigator.of(context).pop();
                              _addCustomizedAddon(
                                addon,
                                controller.text.trim(),
                                calculatedPrice,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2156D5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isEdit ? 'Update' : 'Add to Cart',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addCustomizedAddon(
    ServiceAddon addon,
    String customValue,
    double totalPrice,
  ) {
    final bool isEdit = _addedAddons.containsKey(addon.id);

    debugPrint(
      '${isEdit ? 'Updating' : 'Adding'} customized addon: ${addon.name}',
    );
    debugPrint('Custom value: $customValue');
    debugPrint('Total price: ₹$totalPrice');

    // Store/Update addon data
    setState(() {
      _addedAddons[addon.id] = {
        'name': addon.name,
        'price': addon.price,
        'customText': customValue,
        'characterCount': customValue.length,
        'totalPrice': totalPrice,
        'isCustomizable': addon.isCustomizable,
        'addon': addon, // Keep the addon object for reference if needed
      };
    });

    String message =
        '${addon.name} ("$customValue" - ${customValue.length} chars) ${isEdit ? 'updated' : 'added'} for ₹${totalPrice.toStringAsFixed(2)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildRelatedServices(ServiceListingModel currentService) {
    return Consumer(
      builder: (context, ref, child) {
        final relatedServicesAsync = ref.watch(
          relatedServicesProvider(
            RelatedServicesParams(
              serviceId: widget.serviceId,
              category: currentService.category,
            ),
          ),
        );

        return relatedServicesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You might like / More like this',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Okra',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const RelatedServicesShimmer(),
              ],
            ),
          ),
          error: (error, stack) {
            debugPrint('Related services error: $error');
            debugPrint('Service category: ${currentService.category}');
            debugPrint('Current service ID: ${widget.serviceId}');
            // Show error state instead of hiding
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You might like / More like this',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Unable to load related services',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Okra'),
                    ),
                  ),
                ],
              ),
            );
          },
          data: (relatedServices) {
            debugPrint(
              'Related services loaded: ${relatedServices.length} items',
            );
            if (relatedServices.isEmpty) {
              // Show message instead of hiding section
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You might like / More like this',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Okra',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No related services found',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You might like / More like this',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: relatedServices.length > 4
                        ? 4
                        : relatedServices.length,
                    itemBuilder: (context, index) {
                      final service = relatedServices[index];
                      final price = service.offerPrice != null
                          ? PriceCalculator.formatPriceAsInt(
                              PriceCalculator.calculateTotalPriceWithTaxes(
                                service.offerPrice!,
                              ),
                            )
                          : service.originalPrice != null
                          ? PriceCalculator.formatPriceAsInt(
                              PriceCalculator.calculateTotalPriceWithTaxes(
                                service.originalPrice!,
                              ),
                            )
                          : 'Price on request';

                      return GestureDetector(
                        onTap: () {
                          // Navigate to related service detail
                          context.push(
                            '/service/${service.id}',
                            extra: {
                              'serviceName': service.name,
                              'price': price,
                              'rating': (service.rating ?? 0.0).toStringAsFixed(
                                1,
                              ),
                              'reviewCount': service.reviewsCount ?? 0,
                            },
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildRelatedServiceImage(service),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        service.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Okra',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      //Description 
                                      Text(
                                        service.description!,
                                        
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          fontFamily: 'Okra',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Price section with offer and original price
                                          Row(
                                            children: [
                                              Text(
                                                price,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                  fontFamily: 'Okra',
                                                ),
                                              ),
                                              // Show original price with strikethrough if there's an offer
                                              if ((service.offerPrice != null &&
                                                   service.originalPrice != null &&
                                                   service.offerPrice! < service.originalPrice!) ||
                                                  (service.displayOfferPrice != null &&
                                                   service.displayOriginalPrice != null &&
                                                   service.displayOfferPrice! < service.displayOriginalPrice!)) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  PriceCalculator.formatPriceAsInt(
                                                    PriceCalculator.calculateTotalPriceWithTaxes(
                                                      service.displayOriginalPrice ?? service.originalPrice!,
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[600],
                                                    fontFamily: 'Okra',
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationColor: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.orange,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${(service.rating ?? 0.0).toStringAsFixed(1)} (${service.reviewsCount ?? 0})',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontFamily: 'Okra',
                                                ),
                                              ),
                                            ],
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
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRelatedServiceImage(ServiceListingModel service) {
    // Get the best available image URL
    String imageUrl = '';

    // Try photos array first, then cover photo, then placeholder
    if (service.photos != null && service.photos!.isNotEmpty) {
      final validPhotos = service.photos!
          .where((photo) => photo.isNotEmpty && photo.trim().isNotEmpty)
          .toList();
      if (validPhotos.isNotEmpty) {
        imageUrl = validPhotos.first;
      }
    }

    if (imageUrl.isEmpty &&
        service.image?.isNotEmpty == true &&
        service.image!.trim().isNotEmpty) {
      imageUrl = service.image!;
    }

    if (imageUrl.isEmpty) {
      imageUrl = _placeholderImage;
    }

    debugPrint('Related service image for ${service.name}: $imageUrl');

    if (imageUrl == _placeholderImage) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, color: Colors.grey, size: 24),
              SizedBox(height: 4),
              Text(
                'No image',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(color: Colors.pink, strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('Related service image error for ${service.name}: $error');
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                SizedBox(height: 4),
                Text(
                  'No image',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBookingBar(
    ServiceListingModel service,
    String serviceName,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<VendorModel?>(
              future: _fetchVendor(service.vendorId),
              builder: (context, snapshot) {
                final isOnline = snapshot.data?.isOnline ?? false;
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final vendor = snapshot.data;

                // If vendor data is still loading
                if (isLoading) {
                  return ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // If vendor is null (not found/accessible) or offline, show disabled button
                if (vendor == null) {
                  return ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Vendor Not Available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Okra',
                      ),
                    ),
                  );
                }

                if (!isOnline) {
                  return ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Vendor Currently Offline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Okra',
                      ),
                    ),
                  );
                }

                // Vendor is online, show active booking button
                return ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/service/${service.id}/booking',
                      extra: {'service': service, 'addedAddons': _addedAddons},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
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

  Future<VendorModel?> _fetchVendor(String? vendorId) async {
    if (vendorId == null || vendorId.isEmpty) {
      debugPrint('🔍 ServiceDetailScreen: Vendor ID is null or empty');
      return null;
    }

    try {
      debugPrint('🔍 ServiceDetailScreen: Fetching vendor with ID: $vendorId');
      final repo = ref.read(homeRepositoryProvider);
      final vendor = await repo.getVendorById(vendorId);

      if (vendor == null) {
        debugPrint(
          '🔍 ServiceDetailScreen: Vendor not found or not accessible (ID: $vendorId)',
        );
        debugPrint(
          '🔍 ServiceDetailScreen: This could be due to RLS policies or vendor being inactive',
        );
      } else {
        debugPrint(
          '🔍 ServiceDetailScreen: Successfully fetched vendor: ${vendor.businessName}',
        );
      }

      return vendor;
    } catch (e, stackTrace) {
      debugPrint('❌ ServiceDetailScreen: Error fetching vendor $vendorId: $e');
      debugPrint('❌ ServiceDetailScreen: Stack trace: $stackTrace');
      return null;
    }
  }

  void _showBookingBottomSheet(
    ServiceListingModel service,
    String serviceName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) =>
          CustomizationBottomSheet(service: service, addedAddons: _addedAddons),
    );
  }

  // Helper method to format price to rupees
  String _formatPriceToRupees(String price) {
    // Convert dollar prices to rupees (assuming $1 = ₹84 approximately)
    if (price.startsWith('\$')) {
      final dollarAmount = double.tryParse(price.substring(1)) ?? 0;
      final rupeeAmount = (dollarAmount * 84).round();
      return '₹${_formatNumberWithCommas(rupeeAmount)}';
    }
    // If already in rupees, return as is
    if (price.startsWith('₹')) {
      return price;
    }
    // Default case
    return '₹$price';
  }

  // Helper method to format numbers with commas
  String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // Share service functionality with real service data
  void _shareService(String serviceName) {
    final serviceDetailAsync = ref.read(
      serviceDetailProvider(widget.serviceId),
    );

    serviceDetailAsync.whenData((service) {
      String priceText = 'Price on request';

      if (service != null) {
        if (service.offerPrice != null) {
          final taxInclusiveOfferPrice =
              PriceCalculator.calculateTotalPriceWithTaxes(service.offerPrice!);
          priceText = PriceCalculator.formatPriceAsInt(taxInclusiveOfferPrice);
          if (service.originalPrice != null &&
              service.originalPrice! > service.offerPrice!) {
            final taxInclusiveOriginalPrice =
                PriceCalculator.calculateTotalPriceWithTaxes(
                  service.originalPrice!,
                );
            final savings = (taxInclusiveOriginalPrice - taxInclusiveOfferPrice)
                .round();
            priceText += ' (Save ₹${_formatNumberWithCommas(savings)})';
          }
        } else if (service.originalPrice != null) {
          final taxInclusivePrice =
              PriceCalculator.calculateTotalPriceWithTaxes(
                service.originalPrice!,
              );
          priceText = PriceCalculator.formatPriceAsInt(taxInclusivePrice);
        }
      }

      final ratingText =
          service?.rating?.toStringAsFixed(1) ?? widget.rating ?? '4.9';
      final reviewCountText = service?.reviewsCount ?? widget.reviewCount ?? 0;
      final categoryText = service?.category ?? '';
      final promotionalTag = service?.promotionalTag;

      final shareText =
          '''
🎉 Check out this amazing ${categoryText.isNotEmpty ? categoryText.toLowerCase() : 'service'} on Sylonow!

$serviceName
Price: $priceText${promotionalTag != null ? ' • $promotionalTag' : ''}
Rating: $ratingText ⭐ ($reviewCountText reviews)

Book now and make your celebration special!

Download Sylonow app: https://sylonow.com
''';

      Share.share(
        shareText,
        subject: 'Amazing $serviceName service on Sylonow',
      );
    });
  }

  // Navigate to reviews screen
  void _navigateToReviews() {
    final serviceName = widget.serviceName ?? 'Service';
    final rating = widget.rating ?? '4.9';
    final reviewCount = widget.reviewCount ?? 0;

    context.push(
      ReviewsScreen.routeName,
      extra: {
        'serviceId': widget.serviceId,
        'serviceName': serviceName,
        'averageRating': double.tryParse(rating) ?? 4.9,
        'totalReviews': reviewCount,
      },
    );
  }
}

// Customization Bottom Sheet Widget
class CustomizationBottomSheet extends ConsumerStatefulWidget {
  final ServiceListingModel service;
  final Map<String, Map<String, dynamic>> addedAddons;

  const CustomizationBottomSheet({
    super.key,
    required this.service,
    this.addedAddons = const {},
  });

  @override
  ConsumerState<CustomizationBottomSheet> createState() =>
      _CustomizationBottomSheetState();
}

class _CustomizationBottomSheetState
    extends ConsumerState<CustomizationBottomSheet> {
  String selectedVenueType = 'Option';
  String selectedDate = 'Select Date';
  String selectedTime = 'Select Time';
  String selectedEnvironment = 'Option';
  List<String> selectedAddOns = [];
  final TextEditingController commentsController = TextEditingController();

  // Image upload related state
  XFile? selectedPlaceImage;
  bool isUploadingImage = false;
  final ImageUploadService _imageUploadService = ImageUploadService();

  // Dynamic lists based on service data
  late List<String> venueTypes;
  late List<String> serviceEnvironments;
  late List<Map<String, dynamic>> availableAddOns;
  List<String> timeSlots = [];

  // Vendor availability state
  VendorModel? _vendor;
  bool _isVendorOnline = false;
  String? _vendorStartTime; // HH:mm
  String? _vendorCloseTime; // HH:mm
  int _advanceBookingHours = 2;

  @override
  void initState() {
    super.initState();
    _initializeOptionsFromService();
    _loadUserProfileAndSetDate()
        .then((_) {
          return _loadWelcomePreferences();
        })
        .then((_) {
          // Ensure selected values are valid after loading preferences
          _validateSelectedValues();
        });
    _loadVendorAndBuildTimeSlots();
  }

  void _validateSelectedValues() {
    final availableDates = _getNextSevenDays();

    // Validate selected date
    if (!availableDates.contains(selectedDate)) {
      setState(() {
        selectedDate = 'Select Date';
      });
    }

    // Validate selected time
    if (!timeSlots.contains(selectedTime)) {
      setState(() {
        selectedTime = 'Select Time';
      });
    }

    // Validate selected venue type
    if (!venueTypes.contains(selectedVenueType)) {
      setState(() {
        selectedVenueType = 'Option';
      });
    }

    // Validate selected environment
    if (!serviceEnvironments.contains(selectedEnvironment)) {
      setState(() {
        selectedEnvironment = 'Option';
      });
    }
  }

  void _initializeOptionsFromService() {
    // Initialize venue types from service data or fallback to defaults
    venueTypes = widget.service.venueTypes?.isNotEmpty == true
        ? widget.service.venueTypes!
        : ['Home', 'Community Hall', 'Restaurant', 'Park'];

    // Initialize service environments
    serviceEnvironments = widget.service.serviceEnvironment?.isNotEmpty == true
        ? widget.service.serviceEnvironment!
              .map((env) => env.toUpperCase())
              .toList()
        : ['INDOOR', 'OUTDOOR'];

    // Initialize add-ons from service data
    availableAddOns = widget.service.addOns ?? [];

    debugPrint('🎨 Bottom sheet initialized with:');
    debugPrint('  - Venue types: $venueTypes');
    debugPrint('  - Service environments: $serviceEnvironments');
    debugPrint('  - Available add-ons: ${availableAddOns.length}');
  }

  Future<void> _loadVendorAndBuildTimeSlots() async {
    try {
      debugPrint('🕒 ===== STARTING VENDOR LOAD =====');
      final repo = ref.read(homeRepositoryProvider);
      final vendorId = widget.service.vendorId;
      debugPrint('🕒 Service vendor ID: $vendorId');
      debugPrint('🕒 Service ID: ${widget.service.id}');
      debugPrint('🕒 Service name: ${widget.service.name}');

      if (vendorId == null) {
        debugPrint('❌ Vendor ID is null for service ${widget.service.id}');
        setState(() {
          timeSlots = [];
        });
        return;
      }

      debugPrint('🕒 Calling repo.getVendorById($vendorId)');
      final vendor = await repo.getVendorById(vendorId);
      debugPrint('🕒 Repository returned vendor: $vendor');

      _vendor = vendor;
      _isVendorOnline = vendor?.isOnline ?? false;
      _vendorStartTime = vendor?.startTime; // expected HH:mm or HH:mm:ss
      _vendorCloseTime = vendor?.closeTime; // expected HH:mm or HH:mm:ss

      debugPrint('🕒 ===== VENDOR DEBUG INFO =====');
      debugPrint('🕒 Vendor ID: $vendorId');
      debugPrint('🕒 Vendor from DB: $vendor');
      debugPrint('🕒 Raw isOnline value: ${vendor?.isOnline}');
      debugPrint('🕒 Parsed _isVendorOnline: $_isVendorOnline');
      debugPrint(
        '🕒 Business hours: ${_vendorStartTime ?? 'null'} to ${_vendorCloseTime ?? 'null'}',
      );
      debugPrint(
        '🕒 Advance booking hours: ${vendor?.advanceBookingHours ?? 'null'}',
      );
      debugPrint('🕒 ===============================');

      // Determine advance booking hours: try from service.bookingNotice (parse hours), else vendor setting, else default 2
      _advanceBookingHours =
          _parseAdvanceBookingFromService(widget.service.bookingNotice) ??
          (vendor?.advanceBookingHours ?? 2);

      // Force state update and rebuild time slots
      setState(() {});
      _rebuildTimeSlotsForSelectedDate();
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load vendor/time slots: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() {
        timeSlots = [];
      });
    }
  }

  int? _parseAdvanceBookingFromService(String? bookingNotice) {
    if (bookingNotice == null) return null;
    final match = RegExp(
      r'(\d+)\s*hour',
      caseSensitive: false,
    ).firstMatch(bookingNotice);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  void _rebuildTimeSlotsForSelectedDate() {
    debugPrint('🕒 _rebuildTimeSlotsForSelectedDate called');
    debugPrint('🕒 Vendor online: $_isVendorOnline');
    debugPrint(
      '🕒 Start time: $_vendorStartTime, Close time: $_vendorCloseTime',
    );
    debugPrint('🕒 Selected date: $selectedDate');

    // If vendor is offline, do not show time slots
    if (!_isVendorOnline) {
      debugPrint('🕒 Vendor is offline, clearing time slots');
      setState(() {
        timeSlots = [];
      });
      return;
    }

    // Require vendor business hours
    if (_vendorStartTime == null || _vendorCloseTime == null) {
      debugPrint('🕒 Vendor has no business hours set, clearing time slots');
      setState(() {
        timeSlots = [];
      });
      return;
    }

    // Parse selected date
    DateTime? date;
    try {
      if (selectedDate != 'Select Date') {
        final parts = selectedDate.split('/'); // dd/MM/yyyy
        date = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}

    date ??= DateTime.now();

    // Build DateTime for start and end using vendor hours (HH:mm)
    DateTime? startDateTime = _combineDateWithHm(date, _vendorStartTime!);
    DateTime? endDateTime = _combineDateWithHm(date, _vendorCloseTime!);
    if (startDateTime == null || endDateTime == null) {
      setState(() {
        timeSlots = [];
      });
      return;
    }

    // Respect advance booking time relative to now; if minStart is beyond vendor close today, allow next day slots
    final now = DateTime.now();
    final minStart = now.add(Duration(hours: _advanceBookingHours));
    if (minStart.isAfter(DateTime(date.year, date.month, date.day, 23, 59))) {
      // If viewing today and minStart pushes booking to future day, shift to next day business hours
      final nextDay = DateTime(
        date.year,
        date.month,
        date.day,
      ).add(const Duration(days: 1));
      startDateTime = _combineDateWithHm(nextDay, _vendorStartTime!);
      endDateTime = _combineDateWithHm(nextDay, _vendorCloseTime!);
      if (startDateTime == null || endDateTime == null) {
        setState(() {
          timeSlots = [];
        });
        return;
      }
    } else if (minStart.isAfter(startDateTime)) {
      startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        minStart.hour,
        0,
      );
    }

    // Ensure start < end
    final sdt = startDateTime;
    final edt = endDateTime;
    if (!(sdt.isBefore(edt))) {
      setState(() {
        timeSlots = [];
      });
      return;
    }

    // Generate hourly start times between startDateTime and endDateTime (inclusive of start, exclusive of end)
    final slots = <String>[];
    final formatter = DateFormat('hh:mm a');
    DateTime cursor = DateTime(sdt.year, sdt.month, sdt.day, sdt.hour, 0);
    debugPrint(
      '🕒 Generating time slots from ${formatter.format(sdt)} to ${formatter.format(edt)}',
    );
    debugPrint('🕒 Current time: ${formatter.format(now)}');

    while (cursor.isBefore(edt)) {
      // Only future times if date is today
      if (cursor.isAfter(now)) {
        slots.add(formatter.format(cursor));
        debugPrint('🕒 Added time slot: ${formatter.format(cursor)}');
      } else {
        debugPrint('🕒 Skipped past time slot: ${formatter.format(cursor)}');
      }
      cursor = cursor.add(const Duration(hours: 1));
    }

    debugPrint('🕒 Generated ${slots.length} time slots: $slots');
    setState(() {
      timeSlots = slots;
      if (!timeSlots.contains(selectedTime)) {
        selectedTime = 'Select Time';
      }
    });
  }

  DateTime? _combineDateWithHm(DateTime date, String hm) {
    try {
      final parts = hm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      // Handle both HH:mm and HH:mm:ss formats from database
      return DateTime(date.year, date.month, date.day, h, m);
    } catch (e) {
      debugPrint('❌ Error parsing time format "$hm": $e');
      return null;
    }
  }

  Future<void> _loadUserProfileAndSetDate() async {
    try {
      // Load user profile to get celebration date
      final userProfile = await ref.read(currentUserProfileProvider.future);

      if (userProfile?.celebrationDate != null && mounted) {
        final celebrationDate = userProfile!.celebrationDate!;
        final formattedCelebrationDate = DateFormat(
          'dd/MM/yyyy',
        ).format(celebrationDate);
        final availableDates = _getNextSevenDays();

        // Auto-select celebration date if it exists in available dates
        if (availableDates.contains(formattedCelebrationDate)) {
          setState(() {
            selectedDate = formattedCelebrationDate;
          });
          debugPrint('🎉 Auto-selected user celebration date: $selectedDate');
        } else {
          debugPrint(
            '🎉 User celebration date $formattedCelebrationDate not in available dates, keeping default',
          );
        }

        // Auto-select celebration time if available
        if (userProfile.celebrationTime != null) {
          final celebrationTime = userProfile.celebrationTime!;
          // Parse celebration time string (assuming format like "14:30" or "02:30 PM")
          try {
            DateTime timeOfDay;
            if (celebrationTime.contains('AM') ||
                celebrationTime.contains('PM')) {
              // Handle 12-hour format
              timeOfDay = DateFormat('hh:mm a').parse(celebrationTime);
            } else {
              // Handle 24-hour format
              final timeParts = celebrationTime.split(':');
              timeOfDay = DateTime(
                2000,
                1,
                1,
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
            }

            // Find matching time slot based on celebration time
            final celebrationHour = timeOfDay.hour;
            String? matchingTimeSlot;

            for (final slot in timeSlots) {
              final slotParts = slot.split(' ');
              if (slotParts.length >= 2) {
                final timeStr = '${slotParts[0]} ${slotParts[1]}';
                try {
                  final slotTime = DateFormat('hh:mm a').parse(timeStr);
                  if (slotTime.hour == celebrationHour) {
                    matchingTimeSlot = slot;
                    break;
                  }
                } catch (_) {}
              }
            }

            if (matchingTimeSlot != null && mounted) {
              setState(() {
                selectedTime = matchingTimeSlot!;
              });
              debugPrint(
                '🎉 Auto-selected user celebration time: $selectedTime',
              );
            }
          } catch (e) {
            debugPrint('Error parsing celebration time: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile for auto-date selection: $e');
    }
  }

  Future<void> _loadWelcomePreferences() async {
    try {
      final welcomeService = ref.read(welcomePreferencesServiceProvider);

      // Load saved celebration date and time (only if not already set from user profile)
      if (selectedDate == 'Select Date') {
        final savedDate = await welcomeService.getCelebrationDate();
        if (savedDate != null && mounted) {
          final formattedSavedDate = DateFormat('dd/MM/yyyy').format(savedDate);
          final availableDates = _getNextSevenDays();

          // Only set the saved date if it exists in the available dates
          if (availableDates.contains(formattedSavedDate)) {
            setState(() {
              selectedDate = formattedSavedDate;
            });
            debugPrint('🎯 Loaded saved celebration date: $selectedDate');
          } else {
            debugPrint(
              '🎯 Saved date $formattedSavedDate not in available dates, keeping default',
            );
          }
        }
      }

      if (selectedTime == 'Select Time') {
        final savedTime = await welcomeService.getCelebrationTime();
        if (savedTime != null && mounted) {
          // Find the closest time slot that matches the saved time
          final savedHour = savedTime.hour;
          String? matchingTimeSlot;

          for (final slot in timeSlots) {
            final startHour = int.tryParse(slot.split('-')[0].split(':')[0]);
            if (startHour != null &&
                savedHour >= startHour &&
                savedHour < startHour + 2) {
              matchingTimeSlot = slot;
              break;
            }
          }

          if (matchingTimeSlot != null) {
            setState(() {
              selectedTime = matchingTimeSlot!;
            });
            debugPrint(
              '🎯 Loaded saved celebration time: $selectedTime (from ${savedTime.hour}:${savedTime.minute})',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading welcome preferences: $e');
    }
  }

  @override
  void dispose() {
    commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Customise / Requirements',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Service Info Section
                  _buildServiceInfoCard(),
                  const SizedBox(height: 24),

                  // Venue Type Section
                  _buildSectionTitle('Venue type'),
                  const SizedBox(height: 12),
                  ...venueTypes.map(
                    (venue) => _buildRadioOption(
                      venue,
                      selectedVenueType,
                      (value) => setState(() => selectedVenueType = value),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Service Environment Section (if available)
                  if (serviceEnvironments.isNotEmpty) ...[
                    _buildSectionTitle('Service environment'),
                    const SizedBox(height: 12),
                    ...serviceEnvironments.map(
                      (env) => _buildRadioOption(
                        env,
                        selectedEnvironment,
                        (value) => setState(() => selectedEnvironment = value),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Add-ons Section (if available)
                  if (availableAddOns.isNotEmpty) ...[
                    _buildSectionTitle('Add-ons (optional)'),
                    const SizedBox(height: 12),
                    _buildAddOnsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Time Slot and Date Section
                  _buildSectionTitle('Time slot and Date'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          selectedDate,
                          'Select Date',
                          _getNextSevenDays(),
                          (value) {
                            setState(() => selectedDate = value);
                            _rebuildTimeSlotsForSelectedDate();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          selectedTime,
                          'Select Time',
                          timeSlots,
                          (value) => setState(() => selectedTime = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Inclusions Section (if available)
                  if (widget.service.inclusions?.isNotEmpty == true) ...[
                    _buildSectionTitle('What\'s included'),
                    const SizedBox(height: 12),
                    _buildInclusionsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Place Image Upload Section
                  _buildSectionTitle('Upload place image (optional)'),
                  const SizedBox(height: 8),
                  Text(
                    'Help us understand your decoration requirements by uploading an image of the place',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildImageUploadSection(),
                  const SizedBox(height: 24),

                  // Additional Comments Section
                  // _buildSectionTitle('Additional comments'),
                  // const SizedBox(height: 12),
                  // Container(
                  //   decoration: BoxDecoration(
                  //     border: Border.all(color: Colors.grey[300]!),
                  //     borderRadius: BorderRadius.circular(8),
                  //   ),
                  //   child: TextField(
                  //     controller: commentsController,
                  //     maxLines: 4,
                  //     decoration: InputDecoration(
                  //       hintText:
                  //           widget.service.customizationNote?.isNotEmpty == true
                  //           ? widget.service.customizationNote!
                  //           : 'Add comment (optional)',
                  //       hintStyle: const TextStyle(
                  //         color: Colors.grey,
                  //         fontFamily: 'Okra',
                  //       ),
                  //       border: InputBorder.none,
                  //       contentPadding: const EdgeInsets.all(16),
                  //     ),
                  //     style: const TextStyle(fontFamily: 'Okra'),
                  //   ),
                  // ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Continue Button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _validateAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Okra',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Service Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
          if (widget.service.setupTime?.isNotEmpty == true ||
              widget.service.bookingNotice?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            if (widget.service.setupTime?.isNotEmpty == true)
              _buildInfoRow('Setup Time', widget.service.setupTime!),
            if (widget.service.bookingNotice?.isNotEmpty == true)
              _buildInfoRow('Advance Booking', widget.service.bookingNotice!),
          ],
          if (widget.service.customizationAvailable == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Customization available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontFamily: 'Okra',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOnsSection() {
    return Column(
      children: availableAddOns.map((addon) {
        final addonName = addon['name']?.toString() ?? 'Add-on';
        final addonPrice = addon['price']?.toString() ?? '';
        final isSelected = selectedAddOns.contains(addonName);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedAddOns.remove(addonName);
              } else {
                selectedAddOns.add(addonName);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    addonName,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Okra',
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (addonPrice.isNotEmpty)
                  Text(
                    '+₹$addonPrice',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInclusionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.service.inclusions!.map((inclusion) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inclusion,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Okra',
        color: Colors.black87,
      ),
    );
  }

  Widget _buildRadioOption(
    String option,
    String selectedValue,
    Function(String) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedValue == option
                      ? AppTheme.primaryColor
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: selectedValue == option
                    ? AppTheme.primaryColor
                    : Colors.transparent,
              ),
              child: selectedValue == option
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              option,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Okra',
                color: selectedValue == option
                    ? AppTheme.primaryColor
                    : Colors.black87,
                fontWeight: selectedValue == option
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String selectedValue,
    String hint,
    List<String> items,
    Function(String) onChanged,
  ) {
    // Ensure the selected value exists in the items list
    final validSelectedValue = items.contains(selectedValue)
        ? selectedValue
        : null;

    final isTimeSlotDropdown = hint == 'Select Time';
    final isEmpty = items.isEmpty;

    // Show helpful message when time slots are not available
    String displayHint = hint;
    if (isTimeSlotDropdown && isEmpty) {
      debugPrint('🕒 ===== DROPDOWN DEBUG =====');
      debugPrint('🕒 _vendor: $_vendor');
      debugPrint('🕒 _isVendorOnline: $_isVendorOnline');
      debugPrint('🕒 _vendorStartTime: $_vendorStartTime');
      debugPrint('🕒 _vendorCloseTime: $_vendorCloseTime');
      debugPrint('🕒 timeSlots.length: ${timeSlots.length}');
      debugPrint('🕒 ==========================');

      // Check if vendor data is still loading
      if (_vendor == null) {
        displayHint = 'Loading vendor information...';
      } else if (!_isVendorOnline) {
        displayHint = 'Vendor offline - no times available';
      } else if (_vendorStartTime == null || _vendorCloseTime == null) {
        displayHint = 'No business hours set';
      } else {
        displayHint = 'No available times for selected date';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isEmpty && isTimeSlotDropdown
              ? Colors.red[300]!
              : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isEmpty && isTimeSlotDropdown ? Colors.red[50] : Colors.white,
      ),
      child: isEmpty && isTimeSlotDropdown
          ? Text(
              displayHint,
              style: TextStyle(
                color: Colors.red[600],
                fontFamily: 'Okra',
                fontSize: 14,
              ),
            )
          : DropdownButton<String>(
              value: validSelectedValue,
              hint: Text(
                displayHint,
                style: const TextStyle(color: Colors.grey, fontFamily: 'Okra'),
              ),
              isExpanded: true,
              underline: const SizedBox(),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(fontFamily: 'Okra'),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
    );
  }

  List<String> _getNextSevenDays() {
    final now = DateTime.now();
    // If vendor is offline, start from tomorrow (index 1), otherwise from today (index 0)
    final startIndex = _isVendorOnline ? 0 : 1;
    return List.generate(7, (index) {
      final date = now.add(Duration(days: index + startIndex));
      return '${date.day}/${date.month}/${date.year}';
    });
  }

  Widget _buildImageUploadSection() {
    return Container(
      child: selectedPlaceImage != null
          ? _buildSelectedImageWidget()
          : _buildImageSelectionWidget(),
    );
  }

  Widget _buildImageSelectionWidget() {
    return GestureDetector(
      onTap: isUploadingImage ? null : _selectImage,
      child: DottedBorder(
        options: RectDottedBorderOptions(
          color: Colors.grey[400]!,
          strokeWidth: 1.5,
          dashPattern: const [6, 3], // Dotted line style
        ),
        child: SizedBox(
          width: double.infinity,
          height: 200,

          child: Center(
            child: isUploadingImage
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 10),
                      Text(
                        'Processing image...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 40,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Upload an image',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey[700],
                          fontFamily: 'Okra',
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Supported: JPG, PNG (max 10MB)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImageWidget() {
    return Container(
      height: 200,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(selectedPlaceImage!.path),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedPlaceImage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Image selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Okra',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectImage() async {
    try {
      setState(() {
        isUploadingImage = true;
      });

      // Show image source selection dialog
      final ImageSource? source = await _imageUploadService
          .showImageSourceDialog(context);
      if (source == null) {
        setState(() {
          isUploadingImage = false;
        });
        return;
      }

      // Pick image
      final XFile? pickedImage = await _imageUploadService.pickImage(
        source: source,
      );
      if (pickedImage == null) {
        setState(() {
          isUploadingImage = false;
        });
        return;
      }

      // Validate image
      if (!_imageUploadService.validateImageFile(pickedImage)) {
        setState(() {
          isUploadingImage = false;
        });
        _showError('Please select a valid image file (JPG, PNG, WebP)');
        return;
      }

      setState(() {
        selectedPlaceImage = pickedImage;
        isUploadingImage = false;
      });

      debugPrint('✅ Image selected: ${pickedImage.path}');
    } catch (e) {
      setState(() {
        isUploadingImage = false;
      });
      debugPrint('❌ Error selecting image: $e');
      _showError('Failed to select image. Please try again.');
    }
  }

  void _validateAndContinue() {
    // Validate venue type selection
    if (selectedVenueType == 'Option') {
      _showError('Please select a venue type');
      return;
    }

    // Validate service environment if available
    if (serviceEnvironments.isNotEmpty && selectedEnvironment == 'Option') {
      _showError('Please select a service environment');
      return;
    }

    // Validate date selection
    if (selectedDate == 'Select Date') {
      _showError('Please select a date');
      return;
    }

    // Validate time selection
    if (selectedTime == 'Select Time') {
      _showError('Please select a time');
      return;
    }

    // Validate service essential fields
    if (widget.service.id.isEmpty) {
      debugPrint('❌ Service ID is empty');
      _showError('Invalid service. Please try again.');
      return;
    }

    if (widget.service.name.isEmpty) {
      debugPrint('❌ Service name is empty');
      _showError('Service information incomplete. Please try again.');
      return;
    }

    // Check pricing information
    if (widget.service.originalPrice == null &&
        widget.service.offerPrice == null) {
      debugPrint('⚠️ Service has no pricing information');
    }

    // Create comprehensive customization data
    final customizationData = {
      'venueType': selectedVenueType,
      'serviceEnvironment': serviceEnvironments.isNotEmpty
          ? selectedEnvironment
          : null,
      'date': selectedDate,
      'time': selectedTime,
      'addOns': selectedAddOns,
      'comments': commentsController.text.trim(),
      'setupTime': widget.service.setupTime,
      'bookingNotice': widget.service.bookingNotice,
      'placeImage': selectedPlaceImage, // Add the selected image
    };

    debugPrint('✅ Navigating to checkout with enhanced data:');
    debugPrint('  - Service: ${widget.service.name} (${widget.service.id})');
    debugPrint('  - Venue: $selectedVenueType');
    debugPrint('  - Environment: $selectedEnvironment');
    debugPrint('  - Date & Time: $selectedDate at $selectedTime');
    debugPrint('  - Simple Add-ons: $selectedAddOns');
    debugPrint('  - Complex Add-ons: ${widget.addedAddons.keys.toList()}');
    debugPrint(
      '  - Comments: ${commentsController.text.isNotEmpty ? "Added" : "None"}',
    );
    debugPrint(
      '  - Place Image: ${selectedPlaceImage != null ? "Selected" : "None"}',
    );

    try {
      // Close bottom sheet first
      Navigator.of(context).pop();

      // Combine both types of add-ons for checkout
      final combinedAddOns = <String, Map<String, dynamic>>{};

      // Add complex customizable add-ons from main screen
      combinedAddOns.addAll(widget.addedAddons);

      // Add simple add-ons from customization bottom sheet
      for (int i = 0; i < selectedAddOns.length; i++) {
        final addonName = selectedAddOns[i];
        final addonId =
            'simple_addon_$i'; // Generate unique ID for simple add-ons

        // Find the add-on details from service data
        final addonDetails = availableAddOns.firstWhere(
          (addon) => addon['name'] == addonName,
          orElse: () => <String, dynamic>{},
        );

        final addonPrice =
            double.tryParse(addonDetails['price']?.toString() ?? '0') ?? 0.0;

        combinedAddOns[addonId] = {
          'name': addonName,
          'price': addonPrice,
          'totalPrice': addonPrice,
          'characterCount': 1, // Default for simple add-ons
          'customText': '', // No customization for simple add-ons
          'isCustomizable': false,
        };
      }

      debugPrint(
        '  - Combined Add-ons for checkout: ${combinedAddOns.keys.toList()}',
      );
      debugPrint('  - Total add-ons count: ${combinedAddOns.length}');

      // Navigate to checkout with enhanced data including separate date and time parameters
      context.push(
        CheckoutScreen.routeName,
        extra: {
          'service': widget.service, // Pass the service with calculated pricing from bottom sheet
          'customization': customizationData,
          'selectedDate': selectedDate,
          'selectedTimeSlot':
              null, // Theater time slots not used for regular services
          'selectedScreen': null,
          'selectedAddressId': null,
          'selectedAddOns': combinedAddOns.isNotEmpty ? combinedAddOns : null,
        },
      );
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      _showError('Unable to proceed to checkout. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Related Services Shimmer Widget
class RelatedServicesShimmer extends StatelessWidget {
  const RelatedServicesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pink,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Loading screen widget with shimmer effect
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Shimmer App Bar
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: ShimmerEffect(
                width: double.infinity,
                height: 300,
                borderRadius: BorderRadius.zero,
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => context.pop(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service title shimmer
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerEffect(
                              width: 200,
                              height: 28,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(height: 12),
                            ShimmerEffect(
                              width: 150,
                              height: 24,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                      // Favorite button shimmer
                      ShimmerEffect(
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Rating section shimmer
                  Row(
                    children: [
                      ShimmerEffect(
                        width: 120,
                        height: 20,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(width: 12),
                      ShimmerEffect(
                        width: 80,
                        height: 20,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Description shimmer
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerEffect(
                        width: double.infinity,
                        height: 16,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 8),
                      ShimmerEffect(
                        width: double.infinity,
                        height: 16,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 8),
                      ShimmerEffect(
                        width: 200,
                        height: 16,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Related services section shimmer
                  ShimmerEffect(
                    width: 180,
                    height: 24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 16),
                  const RelatedServicesShimmer(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom bar shimmer
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            ShimmerEffect(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ShimmerEffect(
                width: double.infinity,
                height: 48,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Error screen widget
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Unable to load service',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and try again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable description widget that shows 5 lines by default with Read More option
class _ExpandableDescription extends StatefulWidget {
  final String description;

  const _ExpandableDescription({required this.description});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.grey[700],
            fontFamily: 'Okra',
          ),
          maxLines: _isExpanded ? null : 5,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.description.length > 200) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Read less' : 'Read more',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
