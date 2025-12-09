/// Utility class for applying consistent price rounding logic across the app
/// This ensures all prices end with either 49 or 99
class PriceRounding {
  /// Applies final rounding logic to ensure prices end with 49 or 99
  ///
  /// Rules:
  /// - Last digits 00-10 → round DOWN to end with 99 of previous hundred
  /// - Last digits 11-49 → round to 49
  /// - Last digits 50-60 → round DOWN to 49
  /// - Last digits 61-99 → round to 99
  ///
  /// Examples:
  /// - 510 → 499
  /// - 523 → 549
  /// - 560 → 549
  /// - 678 → 699
  static double applyFinalRounding(double amount) {
    // Get the last two digits
    final lastTwo = amount.toInt() % 100;

    // RULE 1: Last digits 00-10 → round DOWN to end with 99 of previous hundred
    if (lastTwo >= 0 && lastTwo <= 10) {
      return amount - (lastTwo + 1);
    }

    // RULE 2: Last digits 50-60 → round DOWN to 49
    if (lastTwo >= 50 && lastTwo <= 60) {
      final subtract = lastTwo - 49;
      return amount - subtract;
    }

    // RULE 3: Last digits 11-49 → round to 49
    if (lastTwo >= 11 && lastTwo <= 49) {
      return amount - lastTwo + 49;
    }

    // RULE 4: Last digits 61-99 → round to 99
    if (lastTwo >= 61 && lastTwo <= 99) {
      return amount - lastTwo + 99;
    }

    return amount;
  }

  /// Rounds a nullable price, returns null if input is null
  static double? applyFinalRoundingNullable(double? amount) {
    if (amount == null) return null;
    return applyFinalRounding(amount);
  }

  /// Formats a price with currency symbol and proper rounding
  static String formatPrice(double amount, {String currencySymbol = '₹'}) {
    final rounded = applyFinalRounding(amount);
    return '$currencySymbol${rounded.toStringAsFixed(2)}';
  }

  /// Formats a nullable price with currency symbol and proper rounding
  static String? formatPriceNullable(double? amount, {String currencySymbol = '₹'}) {
    if (amount == null) return null;
    return formatPrice(amount, currencySymbol: currencySymbol);
  }
}
