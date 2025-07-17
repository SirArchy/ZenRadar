import 'package:flutter/material.dart';
import '../models/matcha_product.dart';

class ProductFilters extends StatefulWidget {
  final ProductFilter filter;
  final Function(ProductFilter) onFilterChanged;
  final List<String> availableSites;
  final List<String> availableCategories;
  final Map<String, double> priceRange;
  final ScrollController? scrollController;
  final VoidCallback? onClose;

  const ProductFilters({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.availableSites,
    required this.availableCategories,
    required this.priceRange,
    this.scrollController,
    this.onClose,
  });

  @override
  State<ProductFilters> createState() => _ProductFiltersState();
}

class _ProductFiltersState extends State<ProductFilters> {
  late ProductFilter _currentFilter;
  late RangeValues _priceRangeValues;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _priceRangeValues = RangeValues(
      _currentFilter.minPrice ?? widget.priceRange['min']!,
      _currentFilter.maxPrice ?? widget.priceRange['max']!,
    );
  }

  void _updateFilter(ProductFilter newFilter) {
    setState(() {
      _currentFilter = newFilter;
    });
    widget.onFilterChanged(newFilter);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar for draggable sheet
          if (widget.scrollController != null)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          Row(
            children: [
              const Icon(Icons.filter_list),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close filters',
                )
              else
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear All',
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Site Filter
          _buildSiteFilter(isSmallScreen),
          const SizedBox(height: 16),

          // Category Filter
          if (widget.availableCategories.isNotEmpty) ...[
            _buildCategoryFilter(isSmallScreen),
            const SizedBox(height: 16),
          ],

          // Price Range Filter
          _buildPriceRangeFilter(isSmallScreen),
          const SizedBox(height: 16),

          // Discontinued Products Toggle
          _buildDiscontinuedToggle(isSmallScreen),

          // Clear all button at bottom for modal version
          if (widget.onClose != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearFilters,
                child: Text(
                  'Clear All Filters',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
              ),
            ),
          ],

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildSiteFilter(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Site',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _currentFilter.site,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
          ),
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.black,
          ),
          items: [
            ...widget.availableSites.map(
              (site) => DropdownMenuItem(
                value: site == 'All' ? null : site,
                child: Text(
                  site,
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
              ),
            ),
          ],
          onChanged: (value) {
            _updateFilter(_currentFilter.copyWith(site: value));
          },
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _currentFilter.category,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
          ),
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.black,
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                'All Categories',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
            ...widget.availableCategories.map(
              (category) => DropdownMenuItem(
                value: category,
                child: Text(
                  category,
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
              ),
            ),
          ],
          onChanged: (value) {
            _updateFilter(_currentFilter.copyWith(category: value));
          },
        ),
      ],
    );
  }

  Widget _buildPriceRangeFilter(bool isSmallScreen) {
    final minPrice = widget.priceRange['min']!;
    final maxPrice = widget.priceRange['max']!;

    if (minPrice >= maxPrice) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: _priceRangeValues,
          min: minPrice,
          max: maxPrice,
          divisions: 20,
          labels: RangeLabels(
            '\$${_priceRangeValues.start.round()}',
            '\$${_priceRangeValues.end.round()}',
          ),
          onChanged: (values) {
            setState(() {
              _priceRangeValues = values;
            });
          },
          onChangeEnd: (values) {
            _updateFilter(
              _currentFilter.copyWith(
                minPrice: values.start,
                maxPrice: values.end,
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('\$${_priceRangeValues.start.round()}'),
            Text('\$${_priceRangeValues.end.round()}'),
          ],
        ),
      ],
    );
  }

  Widget _buildDiscontinuedToggle(bool isSmallScreen) {
    return CheckboxListTile(
      title: Text(
        'Show discontinued products',
        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
      ),
      subtitle: Text(
        'Include products that are no longer available',
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
      value: _currentFilter.showDiscontinued,
      dense: isSmallScreen,
      contentPadding: EdgeInsets.zero,
      onChanged: (value) {
        _updateFilter(
          _currentFilter.copyWith(showDiscontinued: value ?? false),
        );
      },
    );
  }

  void _clearFilters() {
    final clearedFilter = ProductFilter();
    setState(() {
      _currentFilter = clearedFilter;
      _priceRangeValues = RangeValues(
        widget.priceRange['min']!,
        widget.priceRange['max']!,
      );
    });
    widget.onFilterChanged(clearedFilter);
  }
}
