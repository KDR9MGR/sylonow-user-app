class AddonModel {
  final String id;
  final String? theaterId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  final String? imageUrl;
  final bool isActive;
  final String? vendorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AddonModel({
    required this.id,
    this.theaterId,
    required this.name,
    this.description,
    required this.price,
    this.category,
    this.imageUrl,
    required this.isActive,
    this.vendorId,
    this.createdAt,
    this.updatedAt,
  });

  factory AddonModel.fromJson(Map<String, dynamic> json) {
    return AddonModel(
      id: json['id'] as String,
      theaterId: json['theater_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      vendorId: json['vendor_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'theater_id': theaterId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image_url': imageUrl,
      'is_active': isActive,
      'vendor_id': vendorId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AddonModel copyWith({
    String? id,
    String? theaterId,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isActive,
    String? vendorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddonModel(
      id: id ?? this.id,
      theaterId: theaterId ?? this.theaterId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods

  /// Calculate final price with transaction fee and rounding (same as theater time slots)
  /// No convenience fee is added for add-ons in detail screen
  double get finalPrice {
    // Same calculation as PriceCalculator.calculateTheaterCheckoutTotalWithTaxes
    const transactionFeeRate = 0.0354; // 3.54%
    final transactionFee = price * transactionFeeRate;
    final totalAmount = price + transactionFee;

    // Apply psychological rounding (prices ending in 49 or 99)
    return _applyFinalRounding(totalAmount);
  }

  /// Apply final rounding to ensure prices end with 49 or 99
  double _applyFinalRounding(double amount) {
    final rounded = amount.round();
    final lastDigit = rounded % 10;

    if (lastDigit <= 4) {
      // Round down to nearest 49
      return (rounded ~/ 10) * 10 + 49 - 10;
    } else if (lastDigit >= 5 && lastDigit <= 9) {
      // Round to nearest 49 or 99
      if (lastDigit <= 7) {
        return (rounded ~/ 10) * 10 + 49;
      } else {
        return (rounded ~/ 10) * 10 + 99;
      }
    }

    return rounded.toDouble();
  }

  String get formattedPrice => '₹${finalPrice.round()}';

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get displayName => name;

  String get displayDescription => description ?? 'Add-on for your package';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddonModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AddonModel(id: $id, name: $name, price: $price)';
  }
}
