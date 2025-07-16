import 'package:flutter/material.dart';
import '../models/matcha_product.dart';

class ProductFilters extends StatefulWidget {
  final ProductFilter filter;
  final Function(ProductFilter) onFilterChanged;
  final List<String> availableSites;
  final List<String> availableCategories;
  final Map<String, double> priceRange;

  const ProductFilters({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.availableSites,
    required this.availableCategories,
    required this.priceRange,
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
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 8),
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Site Filter
            _buildSiteFilter(),
            const SizedBox(height: 16),

            // Stock Status Filter
            _buildStockStatusFilter(),
            const SizedBox(height: 16),

            // Category Filter
            if (widget.availableCategories.isNotEmpty) ...[
              _buildCategoryFilter(),
              const SizedBox(height: 16),
            ],

            // Price Range Filter
            _buildPriceRangeFilter(),
            const SizedBox(height: 16),

            // Search Filter
            _buildSearchFilter(),
            const SizedBox(height: 16),

            // Discontinued Products Toggle
            _buildDiscontinuedToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Site', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _currentFilter.site,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Sites')),
            ...widget.availableSites.map(
              (site) => DropdownMenuItem(value: site, child: Text(site)),
            ),
          ],
          onChanged: (value) {
            _updateFilter(_currentFilter.copyWith(site: value));
          },
        ),
      ],
    );
  }

  Widget _buildStockStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Status',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool?>(
                title: const Text('All'),
                value: null,
                groupValue: _currentFilter.inStock,
                onChanged: (value) {
                  _updateFilter(_currentFilter.copyWith(inStock: value));
                },
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<bool?>(
                title: const Text('In Stock'),
                value: true,
                groupValue: _currentFilter.inStock,
                onChanged: (value) {
                  _updateFilter(_currentFilter.copyWith(inStock: value));
                },
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<bool?>(
                title: const Text('Out of Stock'),
                value: false,
                groupValue: _currentFilter.inStock,
                onChanged: (value) {
                  _updateFilter(_currentFilter.copyWith(inStock: value));
                },
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _currentFilter.category,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Categories')),
            ...widget.availableCategories.map(
              (category) =>
                  DropdownMenuItem(value: category, child: Text(category)),
            ),
          ],
          onChanged: (value) {
            _updateFilter(_currentFilter.copyWith(category: value));
          },
        ),
      ],
    );
  }

  Widget _buildPriceRangeFilter() {
    final minPrice = widget.priceRange['min']!;
    final maxPrice = widget.priceRange['max']!;

    if (minPrice >= maxPrice) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Range',
          style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildSearchFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _currentFilter.searchTerm,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Search products...',
            prefixIcon: Icon(Icons.search),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (value) {
            _updateFilter(
              _currentFilter.copyWith(searchTerm: value.isEmpty ? null : value),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDiscontinuedToggle() {
    return CheckboxListTile(
      title: const Text('Show discontinued products'),
      subtitle: const Text('Include products that are no longer available'),
      value: _currentFilter.showDiscontinued,
      onChanged: (value) {
        _updateFilter(
          _currentFilter.copyWith(showDiscontinued: value ?? false),
        );
      },
      dense: true,
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
