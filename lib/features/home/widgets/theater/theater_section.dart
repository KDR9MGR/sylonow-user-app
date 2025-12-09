import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/outside/models/theater_screen_model.dart';
import 'package:sylonow_user/features/outside/providers/theater_providers.dart';

/// Enhanced theater section widget that displays theater screens with auto-scrolling images
class TheaterSection extends ConsumerStatefulWidget {
  const TheaterSection({super.key});

  @override
  ConsumerState<TheaterSection> createState() => _TheaterSectionState();
}

class _TheaterSectionState extends ConsumerState<TheaterSection>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  int _currentIndex = 0;
  bool _isAutoPlaying = true;
  bool _isUserInteracting = false;
  Timer? _carouselTimer;

  // Image auto-scroll management
  final Map<String, int> _currentImageIndex = {};
  final Map<String, Timer?> _imageTimers = {};

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _currentIndex);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _startAutoPlay();
    _slideController.forward();
    _progressController.forward();
  }

  void _startAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _isAutoPlaying && !_isUserInteracting) {
        final screensAsync = ref.read(theaterScreensProvider);
        final screens = screensAsync.value ?? [];

        if (screens.isNotEmpty) {
          final nextIndex = (_currentIndex + 1) % screens.length;
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  void _resetProgress() {
    _progressController.reset();
    _progressController.forward();
  }

  void _handleUserInteraction() {
    setState(() {
      _isUserInteracting = true;
      _isAutoPlaying = false;
    });

    _carouselTimer?.cancel();

    // Resume auto-play after user interaction
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
          _isAutoPlaying = true;
        });
        _startAutoPlay();
      }
    });
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
    _handleUserInteraction();
  }

  void _startImageAutoScroll(String screenId, int imageCount) {
    if (imageCount <= 1) return; // No need to scroll if only one image

    // Cancel existing timer for this screen if any
    _imageTimers[screenId]?.cancel();

    // Initialize current index if not exists
    if (!_currentImageIndex.containsKey(screenId)) {
      _currentImageIndex[screenId] = 0;
    }

    // Start new timer for auto-scrolling images every 3 seconds
    _imageTimers[screenId] = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex[screenId] =
              (_currentImageIndex[screenId]! + 1) % imageCount;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();
    _carouselTimer?.cancel();
    // Cancel all image timers
    for (final timer in _imageTimers.values) {
      timer?.cancel();
    }
    _imageTimers.clear();
    super.dispose();
  }

  void _preloadImages(List<TheaterScreen> screens) {
    // Preload images for current and adjacent screens for smooth scrolling
    final indicesToPreload = <int>{};

    // Add current index
    indicesToPreload.add(_currentIndex);

    // Add previous and next indices (with wrap-around)
    if (screens.length > 1) {
      indicesToPreload.add((_currentIndex - 1 + screens.length) % screens.length);
      indicesToPreload.add((_currentIndex + 1) % screens.length);
    }

    for (final index in indicesToPreload) {
      final screen = screens[index];
      if (screen.images?.isNotEmpty == true) {
        for (final imageUrl in screen.images!) {
          if (imageUrl.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(imageUrl), context);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screensAsync = ref.watch(theaterScreensProvider);

    return screensAsync.when(
      data: (screens) {
        if (screens.isEmpty) {
          return const SizedBox.shrink();
        }

        // Start image auto-scroll for the current screen
        if (screens.isNotEmpty && screens[_currentIndex].images?.isNotEmpty == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startImageAutoScroll(
              screens[_currentIndex].id,
              screens[_currentIndex].images!.length,
            );
            // Preload images for smooth transitions
            _preloadImages(screens);
          });
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // Main theater card with enhanced UI and horizontal scrolling
              SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: screens.length,
                  padEnds: false,
                  pageSnapping: true,
                  onPageChanged: (index) {
                    if (index != _currentIndex) {
                      setState(() {
                        _currentIndex = index;
                      });
                      _resetProgress();
                      _slideController.reset();
                      _slideController.forward();
                    }
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () {
                          _handleUserInteraction();
                          // Navigate directly to theater screen detail screen
                          context.push(
                            '/theater-screen-detail',
                            extra: {
                              'screen': screens[index],
                            },
                          );
                        },
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomLeft: Radius.circular(24),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(24),
                                bottomLeft: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(24),
                                bottomLeft: Radius.circular(24),
                              ),
                              child: _buildTheaterCard(screens[index]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Enhanced dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  screens.length > 4 ? 4 : screens.length, // Limit to 4 dots
                  (index) => GestureDetector(
                    onTap: () => _jumpToPage(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? AppTheme.primaryColor
                            : Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildTheaterCard(TheaterScreen screen) {
    final images = screen.images ?? [];
    final hasImages = images.isNotEmpty;
    final currentImageIndexForScreen = _currentImageIndex[screen.id] ?? 0;
    final currentImage = hasImages ? images[currentImageIndexForScreen] : null;

    return Stack(
      children: [
        // Background image with enhanced animations
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_slideAnimation.value * 0.05),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: hasImages && currentImage != null
                    ? CachedNetworkImage(
                        imageUrl: currentImage,
                        fit: BoxFit.cover,
                        // Optimized caching configuration
                        memCacheWidth: 800, // Limit memory cache size
                        memCacheHeight: 400,
                        maxWidthDiskCache: 1200, // Limit disk cache size
                        maxHeightDiskCache: 600,
                        fadeInDuration: const Duration(milliseconds: 300),
                        fadeOutDuration: const Duration(milliseconds: 100),
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
                            child: Icon(Icons.movie, size: 48, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.3),
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.movie, size: 48, color: Colors.grey),
                        ),
                      ),
              ),
            );
          },
        ),

        // Multi-layer gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.8),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Animated overlay particles/effects
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value * 0.3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.5),
                      radius: 0.8,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Enhanced content overlay with animations
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - _slideAnimation.value) * 20),
                child: Opacity(
                  opacity: _slideAnimation.value,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Capacity info
                      if (screen.allowedCapacity != null)
                        Row(
                          children: [
                            _buildTag('${screen.allowedCapacity} Seats'),
                            const SizedBox(width: 8),
                            if (screen.amenities?.isNotEmpty == true)
                              _buildTag('Premium'),
                          ],
                        ),
                      const SizedBox(height: 8),

                      // Screen Name
                      Text(
                        screen.screenName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Okra',
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Description or subtitle
                      if (screen.description != null)
                        Text(
                          screen.description!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Okra',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 8),

                      // Price and CTA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            screen.hourlyRate > 0
                                ? 'Starts from ₹${screen.hourlyRate.round()}'
                                : 'View Prices',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Okra',
                            ),
                          ),
                          // Shimmering Book Now button
                          AnimatedBuilder(
                            animation: _shimmerAnimation,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                 color : Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Book Now',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Progress indicator and image indicators
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Progress bar for carousel
              Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1.5),
                  child: LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),

              // Image indicators (if multiple images)
              if (images.length > 1)
                Row(
                  children: List.generate(
                    images.length > 3 ? 3 : images.length,
                    (index) => Container(
                      margin: const EdgeInsets.only(left: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: currentImageIndexForScreen == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Okra',
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
