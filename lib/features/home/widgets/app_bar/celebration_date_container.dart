import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/providers/auth_providers.dart';

/// Container that displays the user's celebration date from user_profiles table
class CelebrationDateContainer extends ConsumerStatefulWidget {
  const CelebrationDateContainer({super.key});

  @override
  ConsumerState<CelebrationDateContainer> createState() => _CelebrationDateContainerState();
}

class _CelebrationDateContainerState extends ConsumerState<CelebrationDateContainer> {
  String? _celebrationDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCelebrationDate();
  }

  Future<void> _loadCelebrationDate() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('celebration_date')
          .eq('auth_user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _celebrationDate = response['celebration_date'] as String?;
        });
      }
    } catch (e) {
      //('Error loading celebration date: $e');
    }
  }

  String _getFormattedDate() {
    if (_celebrationDate == null) return 'Set Date';
    
    try {
      final date = DateTime.parse(_celebrationDate!);
      final now = DateTime.now();
      
      // If the date is in the past, show "Set Date" to encourage updating
      if (date.isBefore(now)) {
        return 'Set Date';
      }
      
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return 'Set Date';
    }
  }

  Future<void> _showDatePicker() async {
    final DateTime now = DateTime.now();
    DateTime initialDate = now;
    
    // If we have a stored celebration date, use it only if it's not in the past
    if (_celebrationDate != null) {
      try {
        final storedDate = DateTime.parse(_celebrationDate!);
        // Use the stored date only if it's today or in the future
        if (storedDate.isAfter(now) || storedDate.isAtSameMomentAs(now)) {
          initialDate = storedDate;
        }
      } catch (e) {
        //('Error parsing stored celebration date: $e');
        // Fall back to today's date
      }
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1683C9),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1683C9),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _updateCelebrationDate(picked);
    }
  }

  Future<void> _updateCelebrationDate(DateTime date) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final formattedDate = date.toIso8601String().split('T')[0];
      
      await Supabase.instance.client
          .from('user_profiles')
          .update({'celebration_date': formattedDate})
          .eq('auth_user_id', user.id);

      if (mounted) {
        setState(() {
          _celebrationDate = formattedDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      //('Error updating celebration date: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showDatePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            _isLoading
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _getFormattedDate(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Okra',
                    ),
                  ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}