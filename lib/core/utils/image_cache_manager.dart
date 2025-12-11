import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Optimized image cache manager for better performance
class AppImageCacheManager {
  static final instance = CacheManager(
    Config(
      'app_image_cache',
      stalePeriod: const Duration(days: 7), // Keep images for 7 days
      maxNrOfCacheObjects: 200, // Max 200 cached images
      repo: JsonCacheInfoRepository(databaseName: 'app_image_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// Preload critical images to improve performance
  static Future<void> preloadCriticalImages(BuildContext context) async {
    final criticalImages = [
      'assets/images/splash_screen.jpg',
      'assets/images/sylonow_white_logo.png',
      'assets/images/app_icon.png',
    ];

    for (final imagePath in criticalImages) {
      try {
        await precacheImage(AssetImage(imagePath), context);
      } catch (e) {
        //('Failed to preload image: $imagePath - $e');
      }
    }
  }

  /// Optimized cached network image widget
  static Widget buildOptimizedNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: instance,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      placeholder: (context, url) => 
          placeholder ?? 
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          ),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Clear cache when needed
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }

  /// Get cache size info
  static Future<void> printCacheInfo() async {
    final files = await instance.getFileFromCache('');
    //('Image cache info: ${files?.file.lengthSync()} bytes');
  }
}

/// Optimized asset image widget with memory management
class OptimizedAssetImage extends StatelessWidget {
  const OptimizedAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      // Performance optimization: Set cache dimensions
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      // Use lower quality for better performance
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) {
        //('Failed to load asset image: $assetPath - $error');
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        );
      },
    );
  }
}