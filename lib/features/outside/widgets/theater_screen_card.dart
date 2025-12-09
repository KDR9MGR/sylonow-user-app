import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/theater_screen_model.dart';
import '../screens/theater_screen_detail_screen.dart';

class TheaterScreenCard extends StatelessWidget {
  const TheaterScreenCard({
    super.key,
    required this.screen,
    this.selectedAddress,
  });

  final TheaterScreen screen;
  final dynamic selectedAddress;

  @override
  Widget build(BuildContext context) {
    // Use basePrice from time slots (actual selling price shown in green tag)
    // Use comparePrice for the strikethrough original price
    final actualPrice = screen.basePrice ?? screen.hourlyRate;
    final compareAtPrice = screen.comparePrice;
    final discountAmount = compareAtPrice != null && compareAtPrice > actualPrice
        ? (compareAtPrice - actualPrice)
        : 0.0;

    return GestureDetector(
      onTap: () {
        // Navigate to theater screen detail
        context.push(TheaterScreenDetailScreen.routeName, extra: {
          'screen': screen,
          'selectedDate': DateTime.now().toIso8601String().split('T')[0],
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            _buildImageSection(),

            // Content Section
            _buildContentSection(
              actualPrice,
              compareAtPrice,
              discountAmount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Expanded(
      flex: 7,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFD4D4D4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Image
              SizedBox.expand(
                child: screen.images?.isNotEmpty == true
                    ? Image.network(
                        screen.images!.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFD4D4D4),
                            child: Icon(
                              Icons.movie,
                              size: 32,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      )
                    : Icon(Icons.movie, size: 32, color: Colors.grey[600]),
              ),
              // Black to transparent gradient (bottom to top)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Theater name overlay (bottom, over gradient)
              if (screen.theaterName != null && screen.theaterName!.isNotEmpty)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          screen.theaterName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection(
    double actualPrice,
    double? compareAtPrice,
    double discountAmount,
  ) {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPricingSection(actualPrice, compareAtPrice),
            if (discountAmount > 0) ...[
              const SizedBox(height: 2),
              _buildDiscountSection(discountAmount),
            ],
            _buildScreenDetailsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection(double actualPrice, double? compareAtPrice) {
    final hasDiscount = compareAtPrice != null && compareAtPrice > actualPrice;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Green Price Tag (actual selling price)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF33872E),
            borderRadius: BorderRadius.circular(4),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF04401A), width: 2),
              right: BorderSide(color: Color(0xFF04401A), width: 2),
            ),
          ),
          child: Text(
            '₹${actualPrice.round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'Okra',
            ),
          ),
        ),
        // Only show compare price if there's a discount
        if (hasDiscount) ...[
          const SizedBox(width: 4),
          // Compare Price (Strikethrough)
          Text(
            '₹${compareAtPrice!.round()}',
            style: const TextStyle(
              color: Color(0xFF505661),
              fontSize: 12,
              fontWeight: FontWeight.normal,
              fontFamily: 'Okra',
              decoration: TextDecoration.lineThrough,
              decorationColor: Color(0xFF505661),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiscountSection(double discountAmount) {
    return Row(
      children: [
        // Discount Amount
        Text(
          '₹${discountAmount.round()} OFF',
          style: const TextStyle(
            color: Color(0xFF33872E),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            fontFamily: 'Okra',
          ),
        ),
        const SizedBox(width: 4),
        // Decorative Dashed Line
        Expanded(
          child: SizedBox(
            height: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dashWidth = 4.0;
                const dashSpace = 4.0;
                final dashCount =
                    (constraints.constrainWidth() / (dashWidth + dashSpace))
                        .floor();
                return Row(
                  children: List.generate(dashCount, (index) {
                    return Container(
                      width: dashWidth,
                      height: 1,
                      margin: EdgeInsets.only(
                        right: index < dashCount - 1 ? dashSpace : 0,
                      ),
                      color: Colors.grey[400],
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenDetailsSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Name
          Text(
            screen.screenName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Capacity and Distance Info
          Row(
            children: [
              // Capacity
              Icon(Icons.event_seat, color: Colors.grey[600], size: 10),
              const SizedBox(width: 4),
              Text(
                '${screen.allowedCapacity} Seats',
                style: const TextStyle(
                  color: Color(0xFF666E7B),
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Okra',
                ),
              ),
              // Distance (if available)
              if (screen.distanceKm != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.location_on, color: Colors.grey[600], size: 10),
                const SizedBox(width: 2),
                Text(
                  '${screen.distanceKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Color(0xFF666E7B),
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                    fontFamily: 'Okra',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
