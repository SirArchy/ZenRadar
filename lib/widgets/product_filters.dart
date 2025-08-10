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
  bool _isSiteFilterExpanded = false; // Add state for expandable site filter

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _priceRangeValues = RangeValues(
      _currentFilter.minPrice ?? widget.priceRange['min']!,
      _currentFilter.maxPrice ?? widget.priceRange['max']!,
    );
    // Auto-expand if sites are already selected
    _isSiteFilterExpanded = _currentFilter.sites?.isNotEmpty ?? false;
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
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
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
    final selectedSites = _currentFilter.sites ?? <String>[];
    final availableSitesWithoutAll =
        widget.availableSites.where((site) => site != 'All').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sites',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            const Spacer(),
            if (selectedSites.isNotEmpty)
              TextButton(
                onPressed: () {
                  _updateFilter(_currentFilter.copyWith(sites: <String>[]));
                },
                child: Text(
                  'Clear',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Summary when collapsed or detailed view when expanded
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Header with summary and expand/collapse button
              InkWell(
                onTap: () {
                  setState(() {
                    _isSiteFilterExpanded = !_isSiteFilterExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedSites.isEmpty
                              ? 'All sites'
                              : selectedSites.length ==
                                  availableSitesWithoutAll.length
                              ? 'All sites (${selectedSites.length})'
                              : '${selectedSites.length} of ${availableSitesWithoutAll.length} sites',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight:
                                selectedSites.isNotEmpty
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        _isSiteFilterExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (_isSiteFilterExpanded) ...[
                const Divider(height: 1),
                // Select All / None toggle
                CheckboxListTile(
                  title: Text(
                    selectedSites.length == availableSitesWithoutAll.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value:
                      selectedSites.length == availableSitesWithoutAll.length,
                  tristate: true,
                  onChanged: (value) {
                    if (selectedSites.length ==
                        availableSitesWithoutAll.length) {
                      // Deselect all
                      _updateFilter(_currentFilter.copyWith(sites: <String>[]));
                    } else {
                      // Select all
                      _updateFilter(
                        _currentFilter.copyWith(
                          sites: List<String>.from(availableSitesWithoutAll),
                        ),
                      );
                    }
                  },
                  dense: isSmallScreen,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                const Divider(height: 1),
                // Individual site checkboxes
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                  ), // Limit height
                  child: SingleChildScrollView(
                    child: Column(
                      children:
                          availableSitesWithoutAll
                              .map(
                                (site) => CheckboxListTile(
                                  title: Text(
                                    site,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                  ),
                                  value: selectedSites.contains(site),
                                  onChanged: (isChecked) {
                                    final newSelectedSites = List<String>.from(
                                      selectedSites,
                                    );
                                    if (isChecked == true) {
                                      newSelectedSites.add(site);
                                    } else {
                                      newSelectedSites.remove(site);
                                    }
                                    _updateFilter(
                                      _currentFilter.copyWith(
                                        sites: newSelectedSites,
                                      ),
                                    );
                                  },
                                  dense: isSmallScreen,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Show selected sites as chips when collapsed
        if (!_isSiteFilterExpanded && selectedSites.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children:
                selectedSites
                    .take(3)
                    .map(
                      (site) => Chip(
                        label: Text(
                          site,
                          style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          final newSelectedSites = List<String>.from(
                            selectedSites,
                          );
                          newSelectedSites.remove(site);
                          _updateFilter(
                            _currentFilter.copyWith(sites: newSelectedSites),
                          );
                        },
                      ),
                    )
                    .toList()
                  ..addAll(
                    selectedSites.length > 3
                        ? [
                          Chip(
                            label: Text(
                              '+${selectedSites.length - 3} more',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ]
                        : [],
                  ),
          ),
        ],
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
          value:
              _currentFilter.category?.isEmpty == true
                  ? null
                  : _currentFilter.category,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
          ),
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Theme.of(context).colorScheme.onSurface,
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
    // Preserve the stock filter (inStock) while clearing other filters
    final clearedFilter = ProductFilter(
      inStock: _currentFilter.inStock, // Preserve stock filter from home screen
      showDiscontinued:
          _currentFilter.showDiscontinued, // Preserve this as well
    );
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
