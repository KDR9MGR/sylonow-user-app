import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../../../core/providers/welcome_providers.dart';

/// New welcome overlay that shows user's celebration plan from user_profiles table
class UserCelebrationOverlay extends ConsumerStatefulWidget {
  const UserCelebrationOverlay({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<UserCelebrationOverlay> createState() =>
      _UserCelebrationOverlayState();
}

class _UserCelebrationOverlayState extends ConsumerState<UserCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  String? _fullName;
  String? _occasionName;
  String? _celebrationDate;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadUserCelebrationData();
  }

  void _initializeAnimation() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimationController.forward();
  }

  Future<void> _loadUserCelebrationData() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('''
            full_name,
            celebration_date,
            categories (
              name
            )
          ''')
          .eq('auth_user_id', user.id)
          .single();

      if (mounted) {
        final celebrationDateStr = response['celebration_date'] as String?;

        // Save celebration date to SharedPreferences for booking screen
        if (celebrationDateStr != null) {
          try {
            final celebrationDate = DateTime.parse(celebrationDateStr);
            final welcomeService = ref.read(welcomePreferencesServiceProvider);

            // Save the celebration date and wait for it to complete
            await welcomeService.saveCelebrationPreferences(
              celebrationDate: celebrationDate,
            );

            // Verify the save was successful
            final savedDate = await welcomeService.getCelebrationDate();
            if (savedDate != null) {
              //('✅ Celebration date saved and verified: $celebrationDateStr');
            } else {
              //('⚠️ Celebration date save verification failed');
            }
          } catch (e) {
            //('⚠️ Error saving celebration date to preferences: $e');
          }
        }

        setState(() {
          _fullName = response['full_name'] as String?;
          _celebrationDate = celebrationDateStr;
          _occasionName = response['categories']?['name'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      //('Error loading user celebration data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    super.dispose();
  }

  String _getFormattedDate(String? dateString) {
    if (dateString == null) return 'your special day';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return 'your special day';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final displayName = _fullName ?? 'there';
    final displayOccasion = _occasionName ?? 'celebration';
    final displayDate = _getFormattedDate(_celebrationDate);

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCelebrationCard(
                  displayName,
                  displayOccasion,
                  displayDate,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCelebrationCard(
    String fullName,
    String occasion,
    String date,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final maxWidth = screenWidth > 400 ? 380.0 : screenWidth * 0.9;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: 380,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1683C9), Color(0xFF0C4366)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main celebration message
            Text(
              "Hey $fullName! 👋",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Okra',
              ),
            ),
            const SizedBox(height: 16),

            Text(
              "Let's plan your $occasion on $date",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'Okra',
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF1683C9)),
                iconAlignment: IconAlignment.end,
                label: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Color(0xFF1683C9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                  ),
                ),
                onPressed: widget.onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1683C9),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom clipper for top semi-circular shape
class TopSemiCircularClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top left
    path.moveTo(0, 0);

    // Go to top right
    path.lineTo(size.width, 0);

    // Go down on the right side
    path.lineTo(size.width, size.height * 0.7);

    // Create a curved bottom using quadratic bezier curve
    path.quadraticBezierTo(
      size.width * 0.5, // Control point X (center)
      size.height, // Control point Y (bottom)
      0, // End point X (left)
      size.height * 0.7, // End point Y
    );

    // Close the path back to start
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
