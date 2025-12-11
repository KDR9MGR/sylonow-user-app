import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/address/providers/address_providers.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';
import 'package:sylonow_user/features/theater/models/theater_model.dart';
import 'package:sylonow_user/features/theater/providers/theater_providers.dart';

class TheaterListScreen extends ConsumerStatefulWidget {
  static const String routeName = '/theater/list';

  final String selectedDate;

  const TheaterListScreen({super.key, required this.selectedDate});

  @override
  ConsumerState<TheaterListScreen> createState() => _TheaterListScreenState();
}

enum SortOption {
  nameAsc,
  nameDesc,
  ratingHigh,
  ratingLow,
  priceHigh,
  priceLow,
}

enum FilterOption {
  all,
  highRated, // rating >= 4.0
  budget, // hourly_rate <= 500
  premium, // hourly_rate > 1000
  verified, // is_verified = true
}

class _TheaterListScreenState extends ConsumerState<TheaterListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';
  DateTime? _selectedDate;
  String? _userCelebrationDate;
  bool _isLoadingCelebrationDate = true;
  
  // Sort and Filter state
  SortOption _currentSort = SortOption.nameAsc;
  FilterOption _currentFilter = FilterOption.all;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.selectedDate);
    _loadUserCelebrationDate();
  }

  Future<void> _loadUserCelebrationDate() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        setState(() {
          _isLoadingCelebrationDate = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('celebration_date')
          .eq('auth_user_id', user.id)
          .single();

      if (mounted) {
        final celebrationDate = response['celebration_date'] as String?;
        if (celebrationDate != null) {
          setState(() {
            _userCelebrationDate = celebrationDate;
            // Set selected date to celebration date if available
            _selectedDate = DateTime.parse(celebrationDate);
            _isLoadingCelebrationDate = false;
          });
        } else {
          setState(() {
            _isLoadingCelebrationDate = false;
          });
        }
      }
    } catch (e) {
      //('Error loading celebration date: $e');
      if (mounted) {
        setState(() {
          _isLoadingCelebrationDate = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theatersAsync = ref.watch(theatersProvider);

    return Scaffold(
      backgroundColor: Color(0xffF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section - Date Selection (like screenshot)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header Row with back button and location
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(0xffF5F6F8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer(
                              builder: (context, ref, child) {
                                final selectedAddress = ref.watch(selectedAddressProvider);
                                return Text(
                                  selectedAddress?.area ?? 'Current Location',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    fontFamily: 'Okra',
                                  ),
                                );
                              },
                            ),
                            Text(
                              _isLoadingCelebrationDate
                                  ? 'Loading...'
                                  : _formatDateSubtitle(_selectedDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'Okra',
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showDatePicker(),
                        child: const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Row - Sort, Filter
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.sort,
                          label: 'Sort',
                          onTap: () => _showSortOptions(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.tune,
                          label: 'Filter',
                          onTap: () => _showFilterOptions(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Theater List
            Expanded(
              child: theatersAsync.when(
                data: (theaters) {
                  // Apply search filter
                  var filteredTheaters = theaters.where((theater) {
                    return _searchQuery.isEmpty ||
                        (theater.name ?? '').toLowerCase().contains(
                          _searchQuery,
                        ) ||
                        (theater.city ?? '').toLowerCase().contains(
                          _searchQuery,
                        ) ||
                        (theater.address ?? '').toLowerCase().contains(
                          _searchQuery,
                        );
                  }).toList();

                  // Apply category filter
                  filteredTheaters = _applyFilter(filteredTheaters);
                  
                  // Apply sorting
                  filteredTheaters = _applySorting(filteredTheaters);

                  if (filteredTheaters.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTheaters.length,
                    itemBuilder: (context, index) {
                      final theater = filteredTheaters[index];
                      return _buildTheaterCard(theater);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
                error: (error, stackTrace) => _buildErrorState(error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'Okra',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTheaterCard(TheaterModel theater) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Add null safety check for theater.id
          final theaterId = theater.id ?? '';
          if (theaterId.isNotEmpty) {
            context.push(
              '/theater/$theaterId/screens',
              extra: {'selectedDate': _selectedDate!.toIso8601String()},
            );
          } else {
            // Show error if theater ID is invalid
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid theater selection. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theater Image
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: (theater.images ?? []).isNotEmpty
                  ? Container(
                      margin: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: (theater.images ?? []).first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.movie, color: Colors.grey, size: 48),
                      ),
                    ),
            ),

            // Theater Details
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theater Name and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          theater.name ?? 'Unknown Theater',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontFamily: 'Okra',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Price Section (similar to hotel card)
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Location and Rating Row
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${theater.city ?? 'Unknown City'}, ${theater.state ?? 'Unknown State'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontFamily: 'Okra',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Rating Section
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            (theater.rating ?? 4.2).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No theaters found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or date',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontFamily: 'Okra',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontFamily: 'Okra',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(theatersProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _formatDateSubtitle(DateTime date) {
    return DateFormat('EEEE, dd MMMM').format(date);
  }

  List<TheaterModel> _applyFilter(List<TheaterModel> theaters) {
    switch (_currentFilter) {
      case FilterOption.all:
        return theaters;
      case FilterOption.highRated:
        return theaters.where((theater) => (theater.rating ?? 0) >= 4.0).toList();
      case FilterOption.budget:
        return theaters.where((theater) => (theater.hourlyRate ?? 0) <= 500).toList();
      case FilterOption.premium:
        return theaters.where((theater) => (theater.hourlyRate ?? 0) > 1000).toList();
      case FilterOption.verified:
        return theaters.where((theater) => theater.isVerified == true).toList();
    }
  }

  List<TheaterModel> _applySorting(List<TheaterModel> theaters) {
    switch (_currentSort) {
      case SortOption.nameAsc:
        theaters.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        break;
      case SortOption.nameDesc:
        theaters.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
        break;
      case SortOption.ratingHigh:
        theaters.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case SortOption.ratingLow:
        theaters.sort((a, b) => (a.rating ?? 0).compareTo(b.rating ?? 0));
        break;
      case SortOption.priceHigh:
        theaters.sort((a, b) => (b.hourlyRate ?? 0).compareTo(a.hourlyRate ?? 0));
        break;
      case SortOption.priceLow:
        theaters.sort((a, b) => (a.hourlyRate ?? 0).compareTo(b.hourlyRate ?? 0));
        break;
    }
    return theaters;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption('Name (A-Z)', SortOption.nameAsc),
              _buildSortOption('Name (Z-A)', SortOption.nameDesc),
              _buildSortOption('Rating (High to Low)', SortOption.ratingHigh),
              _buildSortOption('Rating (Low to High)', SortOption.ratingLow),
              _buildSortOption('Price (High to Low)', SortOption.priceHigh),
              _buildSortOption('Price (Low to High)', SortOption.priceLow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, SortOption option) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Okra'),
      ),
      trailing: _currentSort == option 
          ? const Icon(Icons.check, color: AppTheme.primaryColor)
          : null,
      onTap: () {
        setState(() {
          _currentSort = option;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(height: 16),
              _buildFilterOption('All Theaters', FilterOption.all),
              _buildFilterOption('High Rated (4.0+)', FilterOption.highRated),
              _buildFilterOption('Budget (≤₹500/hr)', FilterOption.budget),
              _buildFilterOption('Premium (>₹1000/hr)', FilterOption.premium),
              _buildFilterOption('Verified Only', FilterOption.verified),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String title, FilterOption option) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Okra'),
      ),
      trailing: _currentFilter == option 
          ? const Icon(Icons.check, color: AppTheme.primaryColor)
          : null,
      onTap: () {
        setState(() {
          _currentFilter = option;
        });
        Navigator.pop(context);
      },
    );
  }
}
