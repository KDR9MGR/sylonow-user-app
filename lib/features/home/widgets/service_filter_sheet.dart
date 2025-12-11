import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../models/filter_model.dart';

class ServiceFilterSheet extends ConsumerStatefulWidget {
  final ServiceFilter initialFilter;
  final String decorationType; // 'inside' or 'outside'
  final Function(ServiceFilter) onApplyFilter;

  const ServiceFilterSheet({
    super.key,
    required this.initialFilter,
    required this.decorationType,
    required this.onApplyFilter,
  });

  @override
  ConsumerState<ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends ConsumerState<ServiceFilterSheet> {
  late ServiceFilter _filter;
  int _selectedTabIndex = 0;

  // Filter categories based on decoration type
  List<String> _availableCategories = [];
  late List<String> _availableVenueTypes;
  late List<String> _availableThemes;
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _initializeCategories();
    _loadCategoriesFromSupabase();
  }

  void _initializeCategories() {
    if (widget.decorationType == 'inside') {
      _availableVenueTypes = [
        'Home',
        'Banquet Hall',
        'Hotel Room',
        'Conference Room',
        'Private Hall',
        'Apartment',
      ];
      _availableThemes = [
        'Romantic',
        'Birthday Theme',
        'Corporate',
        'Traditional',
        'Modern',
        'Vintage',
        'Kids Theme',
        'Elegant',
      ];
    } else {
      _availableVenueTypes = [
        'Garden',
        'Terrace',
        'Poolside',
        'Lawn',
        'Beach',
        'Farmhouse',
        'Open Ground',
        'Rooftop',
      ];
      _availableThemes = [
        'Natural',
        'Bohemian',
        'Rustic',
        'Garden Party',
        'Beach Theme',
        'Outdoor Wedding',
        'Festival',
        'Country Style',
      ];
    }
  }

  Future<void> _loadCategoriesFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('name');

      if (mounted) {
        setState(() {
          _availableCategories = (response as List)
              .map((category) => category['name'] as String)
              .toList();
          _loadingCategories = false;
        });
      }
    } catch (e) {
      //('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _loadingCategories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filter Services',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Okra',
              ),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Clear All',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Sort', 'Categories', 'Price', 'Features'];
    
    return SizedBox(
      height: 50,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSortTab();
      case 1:
        return _buildCategoriesTab();
      case 2:
        return _buildPriceTab();
      case 3:
        return _buildFeaturesTab();
      default:
        return _buildSortTab();
    }
  }

  Widget _buildSortTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort By',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          ...SortOption.values.map((option) => _buildSortOption(option)),
        ],
      ),
    );
  }

  Widget _buildSortOption(SortOption option) {
    final isSelected = _filter.sortBy == option;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _filter = _filter.copyWith(sortBy: option)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Radio<SortOption>(
                value: option,
                groupValue: _filter.sortBy,
                onChanged: (value) => setState(() => _filter = _filter.copyWith(sortBy: value!)),
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                option.displayName,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadingCategories
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                )
              : _buildFilterSection('Categories', _availableCategories, _filter.categories, (categories) {
                  setState(() => _filter = _filter.copyWith(categories: categories));
                }),
          const SizedBox(height: 24),
          _buildFilterSection('Venue Types', _availableVenueTypes, _filter.venueTypes, (venueTypes) {
            setState(() => _filter = _filter.copyWith(venueTypes: venueTypes));
          }),
          const SizedBox(height: 24),
          _buildFilterSection('Themes', _availableThemes, _filter.themeTags, (themes) {
            setState(() => _filter = _filter.copyWith(themeTags: themes));
          }),
        ],
      ),
    );
  }

  Widget _buildPriceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '₹${_filter.minPrice.toInt()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
              const Spacer(),
              Text(
                '₹${_filter.maxPrice.toInt()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: RangeValues(_filter.minPrice, _filter.maxPrice),
            min: 0,
            max: 50000,
            divisions: 100,
            activeColor: AppTheme.primaryColor,
            onChanged: (values) {
              setState(() {
                _filter = _filter.copyWith(
                  minPrice: values.start,
                  maxPrice: values.end,
                );
              });
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Minimum Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [1.0, 2.0, 3.0, 4.0, 4.5].map((rating) {
              final isSelected = _filter.minRating == rating;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$rating'),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => setState(() => _filter = _filter.copyWith(minRating: rating)),
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                  fontFamily: 'Okra',
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            'Featured Services Only',
            'Show only premium/featured services',
            _filter.onlyFeatured,
            (value) => setState(() => _filter = _filter.copyWith(onlyFeatured: value)),
          ),
          _buildSwitchTile(
            'Has Special Offers',
            'Services with discounts and deals',
            _filter.hasOffers,
            (value) => setState(() => _filter = _filter.copyWith(hasOffers: value)),
          ),
          _buildSwitchTile(
            'Customization Available',
            'Services that can be customized',
            _filter.customizationAvailable,
            (value) => setState(() => _filter = _filter.copyWith(customizationAvailable: value)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Distance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Within ${_filter.maxDistanceKm.toInt()} km',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
            ),
          ),
          Slider(
            value: _filter.maxDistanceKm,
            min: 1,
            max: 40,
            divisions: 39,
            activeColor: AppTheme.primaryColor,
            onChanged: (value) => setState(() => _filter = _filter.copyWith(maxDistanceKm: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    List<String> selectedOptions,
    Function(List<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedOptions.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                final newList = List<String>.from(selectedOptions);
                if (selected) {
                  newList.add(option);
                } else {
                  newList.remove(option);
                }
                onChanged(newList);
              },
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
                fontFamily: 'Okra',
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'Okra',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _clearFilters,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                widget.onApplyFilter(_filter);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filter = const ServiceFilter();
    });
  }
}