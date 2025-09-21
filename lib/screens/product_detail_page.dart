// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../models/price_history.dart';
import '../models/stock_history.dart';
import '../services/database_service.dart';
import '../services/currency_converter_service.dart';
import '../services/settings_service.dart';
import '../services/backend_service.dart';
import '../services/subscription_service.dart';
import '../widgets/improved_price_chart.dart';
import '../widgets/improved_stock_chart.dart';
import '../widgets/product_detail_card.dart';
import 'subscription_upgrade_screen.dart';

class ProductDetailPage extends StatefulWidget {
  final MatchaProduct product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final CurrencyConverterService _currencyConverter =
      CurrencyConverterService();
  PriceAnalytics? _priceAnalytics;
  StockAnalytics? _stockAnalytics;
  bool _isLoading = true;
  String _selectedTimeRange = 'month'; // day, week, month, all
  DateTime? _selectedDay;
  String? _selectedCurrency; // Currency for price display
  double? _convertedPrice;
  double? _convertedLowestPrice;
  double? _convertedHighestPrice;
  double? _convertedAveragePrice;
  bool _isFavorite = false;
  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _isPremium = false;

  static const currencies = [
    {'code': 'EUR', 'name': 'Euro (€)', 'symbol': '€'},
    {'code': 'USD', 'name': 'US Dollar (\$)', 'symbol': '\$'},
    {'code': 'JPY', 'name': 'Japanese Yen (¥)', 'symbol': '¥'},
    {'code': 'GBP', 'name': 'British Pound (£)', 'symbol': '£'},
    {'code': 'CHF', 'name': 'Swiss Franc (CHF)', 'symbol': 'CHF'},
    {'code': 'CAD', 'name': 'Canadian Dollar (CAD)', 'symbol': 'CAD'},
    {'code': 'AUD', 'name': 'Australian Dollar (AUD)', 'symbol': 'AUD'},
  ];

  final dynamic _db = DatabaseService.platformService;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Listen to subscription service changes
    SubscriptionService.instance.addListener(_onSubscriptionChanged);
    // Don't call async methods here that might access inherited widgets
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize data loading here where inherited widgets are available
    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadUserSettings();
      _loadPriceHistory();
      _loadFavoriteStatus();
      _loadSubscriptionStatus();
    }
  }

  @override
  void dispose() {
    // Remove subscription service listener
    SubscriptionService.instance.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  /// Handle subscription service changes (debug mode toggle)
  void _onSubscriptionChanged() {
    if (mounted) {
      // Reload subscription status
      _loadSubscriptionStatus();
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        // Handle "Original" currency preference
        if (settings.preferredCurrency == 'Original') {
          _selectedCurrency = widget.product.currency ?? 'EUR';
        } else {
          // Use user's preferred currency, fallback to product currency, then EUR
          _selectedCurrency =
              settings.preferredCurrency.isNotEmpty
                  ? settings.preferredCurrency
                  : (widget.product.currency ?? 'EUR');
        }
      });

      // Debug info
      debugPrint('Product currency: ${widget.product.currency}');
      debugPrint('Product price: ${widget.product.price}');
      debugPrint('Product priceValue: ${widget.product.priceValue}');
      debugPrint('User preferred currency: ${settings.preferredCurrency}');
      debugPrint('Selected currency: $_selectedCurrency');

      _convertAllPrices();
    } catch (e) {
      // Fallback to product currency or EUR if settings fail to load
      setState(() {
        _selectedCurrency = widget.product.currency ?? 'EUR';
      });
      _convertAllPrices();
    }
  }

  Future<void> _loadPriceHistory() async {
    setState(() => _isLoading = true);

    try {
      debugPrint(
        '🔍 Loading price and stock history for product: ${widget.product.id}',
      );
      debugPrint(
        '📋 Product details: ${widget.product.name} - ${widget.product.site}',
      );

      final analytics = await _db.getPriceAnalyticsForProduct(
        widget.product.id,
      );
      debugPrint(
        '💰 Price analytics loaded: ${analytics.totalDataPoints} data points',
      );
      if (analytics.totalDataPoints > 0) {
        debugPrint(
          '💰 Price range: ${analytics.lowestPrice} - ${analytics.highestPrice} ${widget.product.currency}',
        );
      }

      final stockAnalytics = await _db.getStockAnalyticsForProduct(
        widget.product.id,
      );
      debugPrint(
        '📈 Stock analytics loaded: ${stockAnalytics.statusPoints.length} status points',
      );

      setState(() {
        _priceAnalytics = analytics;
        _stockAnalytics = stockAnalytics;
        _isLoading = false;
      });

      // Convert prices after loading analytics
      _convertAllPrices();
    } catch (e) {
      debugPrint('❌ Error loading analytics for ${widget.product.id}: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final tier = await SubscriptionService.instance.getCurrentTier();
      final isPremium = await SubscriptionService.instance.isPremiumUser();

      setState(() {
        _currentTier = tier;
        _isPremium = isPremium;
        // For free users, default to 'day' since it's the only available option
        if (!isPremium && _selectedTimeRange != 'day') {
          _selectedTimeRange = 'day';
        }
      });
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
    }
  }

  Future<void> _convertAllPrices() async {
    if (_selectedCurrency == null) return;

    final fromCurrency = widget.product.currency ?? 'EUR';
    final toCurrency = _selectedCurrency!;

    // Skip conversion if currencies are the same
    if (fromCurrency == toCurrency) {
      setState(() {
        _convertedPrice = widget.product.priceValue;
        // Also skip analytics conversion if same currency
        if (_priceAnalytics != null) {
          _convertedLowestPrice = _priceAnalytics!.lowestPrice;
          _convertedHighestPrice = _priceAnalytics!.highestPrice;
          _convertedAveragePrice = _priceAnalytics!.averagePrice;
        }
      });
      return;
    }

    // Convert current price
    if (widget.product.priceValue != null) {
      debugPrint(
        'Converting price: ${widget.product.priceValue} from $fromCurrency to $toCurrency',
      );
      final converted = await _currencyConverter.convert(
        fromCurrency,
        toCurrency,
        widget.product.priceValue!,
      );
      debugPrint('Converted price result: $converted');
      setState(() {
        _convertedPrice = converted;
      });
    }

    // Convert analytics prices if available
    if (_priceAnalytics != null) {
      // Skip conversion if currencies are the same
      if (fromCurrency == toCurrency) {
        setState(() {
          _convertedLowestPrice = _priceAnalytics!.lowestPrice;
          _convertedHighestPrice = _priceAnalytics!.highestPrice;
          _convertedAveragePrice = _priceAnalytics!.averagePrice;
        });
        return;
      }

      double? convertedLowest, convertedHighest, convertedAverage;

      if (_priceAnalytics!.lowestPrice != null) {
        convertedLowest = await _currencyConverter.convert(
          fromCurrency,
          toCurrency,
          _priceAnalytics!.lowestPrice!,
        );
      }

      if (_priceAnalytics!.highestPrice != null) {
        convertedHighest = await _currencyConverter.convert(
          fromCurrency,
          toCurrency,
          _priceAnalytics!.highestPrice!,
        );
      }

      if (_priceAnalytics!.averagePrice != null) {
        convertedAverage = await _currencyConverter.convert(
          fromCurrency,
          toCurrency,
          _priceAnalytics!.averagePrice!,
        );
      }

      setState(() {
        _convertedLowestPrice = convertedLowest;
        _convertedHighestPrice = convertedHighest;
        _convertedAveragePrice = convertedAverage;
      });
    }
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final favorites =
          await DatabaseService.platformService.getFavoriteProductIds();
      setState(() {
        _isFavorite = favorites.contains(widget.product.id);
      });
    } catch (e) {
      print('Error loading favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final result = await BackendService.instance.updateFavorite(
        productId: widget.product.id,
        isFavorite: !_isFavorite,
      );

      if (!result.success) {
        // Handle other errors
        _showErrorSnackBar(result.error ?? 'Failed to update favorite');
        return;
      }

      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite
                  ? '📱 Added to favorites - you\'ll get notifications when it\'s back in stock!'
                  : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorite: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<PriceHistory> get _filteredHistory {
    if (_priceAnalytics == null) return [];

    switch (_selectedTimeRange) {
      case 'day':
        return _priceAnalytics!.dailyAggregatedHistory.where((h) {
          return h.date.isAfter(
            DateTime.now().subtract(const Duration(days: 7)),
          );
        }).toList();
      case 'week':
        return _priceAnalytics!.weeklyAggregatedHistory.where((h) {
          return h.date.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          );
        }).toList();
      case 'month':
        return _priceAnalytics!.monthlyAggregatedHistory.where((h) {
          return h.date.isAfter(
            DateTime.now().subtract(const Duration(days: 365)),
          );
        }).toList();
      default:
        return _priceAnalytics!.dailyAggregatedHistory;
    }
  }

  /// Get the current display currency code
  String get _currentCurrency {
    return _selectedCurrency ?? widget.product.currency ?? 'EUR';
  }

  /// Get the currency symbol for display
  String get _currentCurrencySymbol {
    final currency = currencies.firstWhere(
      (c) => c['code'] == _currentCurrency,
      orElse: () => {'symbol': _currentCurrency},
    );
    return currency['symbol'] as String;
  }

  /// Get the original product currency symbol
  String _getOriginalCurrencySymbol() {
    final productCurrency = widget.product.currency ?? 'EUR';
    final currency = currencies.firstWhere(
      (c) => c['code'] == productCurrency,
      orElse: () => {'symbol': productCurrency},
    );
    return currency['symbol'] as String;
  }

  /// Format a price value with the current currency symbol
  String _formatPrice(double? price) {
    if (price == null) return '-';
    return '${price.toStringAsFixed(2)}$_currentCurrencySymbol';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name, style: const TextStyle(fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.currency_exchange),
                SizedBox(width: 4),
                Text(
                  _currentCurrency,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            tooltip: 'Select Currency',
            onSelected: (String currency) {
              setState(() {
                _selectedCurrency = currency;
              });
              _convertAllPrices();
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    'Select Currency',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                PopupMenuDivider(),
                ...currencies.map((currency) {
                  final isSelected = _currentCurrency == currency['code'];
                  return PopupMenuItem<String>(
                    value: currency['code'] as String,
                    child: Row(
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        else
                          SizedBox(width: 24),
                        SizedBox(width: 8),
                        Text(currency['name'] as String),
                      ],
                    ),
                  );
                }),
              ];
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHeader(),
                      const SizedBox(height: 24),
                      _buildPriceOverview(),
                      const SizedBox(height: 24),
                      _buildPriceChart(),
                      const SizedBox(height: 24),
                      _buildStockChart(),
                      const SizedBox(height: 16),
                      _buildSubscriptionInfoBanner(),
                      const SizedBox(height: 24),
                      _buildProductDetails(),
                      const SizedBox(height: 48), // Extra bottom padding
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProductHeader() {
    return ProductDetailCard(
      product: widget.product,
      onTap: () => _launchUrl(widget.product.url),
      preferredCurrency: _selectedCurrency,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      hideLastChecked: false,
    );
  }

  Widget _buildPriceOverview() {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price Analytics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildLoadingStatCard()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildLoadingStatCard()),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildLoadingStatCard()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildLoadingStatCard()),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_priceAnalytics == null || _priceAnalytics!.totalDataPoints == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.trending_up,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(75),
              ),
              const SizedBox(height: 8),
              Text(
                'No Price History Available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Price tracking will begin with the next scan',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Current',
                    _convertedPrice != null
                        ? _formatPrice(_convertedPrice)
                        : '-',
                    Icons.attach_money,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Lowest',
                    _convertedLowestPrice != null
                        ? '${_convertedLowestPrice!.toStringAsFixed(2)}$_currentCurrencySymbol'
                        : _formatPrice(_priceAnalytics!.lowestPrice),
                    Icons.trending_down,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Highest',
                    _convertedHighestPrice != null
                        ? '${_convertedHighestPrice!.toStringAsFixed(2)}$_currentCurrencySymbol'
                        : _formatPrice(_priceAnalytics!.highestPrice),
                    Icons.trending_up,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Average',
                    _convertedAveragePrice != null
                        ? '${_convertedAveragePrice!.toStringAsFixed(2)}$_currentCurrencySymbol'
                        : _formatPrice(_priceAnalytics!.averagePrice),
                    Icons.analytics,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStatCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Price History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  _buildHistoryAccessBadge(),
                  const Spacer(),
                  // Loading placeholder for time range selector
                  Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading price history...',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_priceAnalytics == null || _filteredHistory.isEmpty) {
      // Let the ImprovedPriceChart handle empty state with current price display
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Price History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  _buildHistoryAccessBadge(),
                  const Spacer(),
                  PopupMenuButton<String>(
                    initialValue: _selectedTimeRange,
                    onSelected: (value) {
                      setState(() {
                        _selectedTimeRange = value;
                      });
                    },
                    itemBuilder:
                        (context) =>
                            _isPremium
                                ? [
                                  const PopupMenuItem(
                                    value: 'day',
                                    child: Text('7 Days'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'week',
                                    child: Text('1 Month'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'month',
                                    child: Text('1 Year'),
                                  ),
                                ]
                                : [
                                  const PopupMenuItem(
                                    value: 'day',
                                    child: Text('7 Days'),
                                  ),
                                ],
                    child: Chip(
                      label: Text(_getTimeRangeLabel()),
                      avatar: const Icon(Icons.access_time, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Use the improved price chart with current price display for empty state
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ImprovedPriceChart(
                  key: ValueKey(_selectedTimeRange),
                  priceHistory: _filteredHistory,
                  currencySymbol: _currentCurrencySymbol,
                  timeRange: _selectedTimeRange,
                  product:
                      widget
                          .product, // This enables current price display when no history
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Price History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 8),
                _buildHistoryAccessBadge(),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: _selectedTimeRange,
                  onSelected: (value) {
                    setState(() {
                      _selectedTimeRange = value;
                    });
                  },
                  itemBuilder:
                      (context) =>
                          _isPremium
                              ? [
                                const PopupMenuItem(
                                  value: 'day',
                                  child: Text('7 Days'),
                                ),
                                const PopupMenuItem(
                                  value: 'week',
                                  child: Text('1 Month'),
                                ),
                                const PopupMenuItem(
                                  value: 'month',
                                  child: Text('1 Year'),
                                ),
                              ]
                              : [
                                const PopupMenuItem(
                                  value: 'day',
                                  child: Text('7 Days'),
                                ),
                              ],
                  child: Chip(
                    label: Text(_getTimeRangeLabel()),
                    avatar: const Icon(Icons.access_time, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Use the improved price chart with loading animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ImprovedPriceChart(
                key: ValueKey(_selectedTimeRange),
                priceHistory: _filteredHistory,
                currencySymbol: _currentCurrencySymbol,
                timeRange: _selectedTimeRange,
                product:
                    widget.product, // Pass the product for current price access
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Site', widget.product.site),
            _buildDetailRow('Category', widget.product.category ?? 'Unknown'),
            _buildDetailRow(
              'Current Price',
              _convertedPrice != null
                  ? '${_convertedPrice!.toStringAsFixed(2)}$_currentCurrencySymbol'
                  : widget.product.priceValue != null
                  ? '${widget.product.priceValue!.toStringAsFixed(2)}${_getOriginalCurrencySymbol()}'
                  : (widget.product.price ?? 'N/A'),
            ),
            if (widget.product.weight != null)
              _buildDetailRow('Weight', '${widget.product.weight}g'),
            if (widget.product.currency != null)
              _buildDetailRow('Original Currency', widget.product.currency!),
            _buildDetailRow(
              'First Seen',
              DateFormat('MMM dd, yyyy HH:mm').format(widget.product.firstSeen),
            ),
            _buildDetailRow(
              'Last Checked',
              DateFormat(
                'MMM dd, yyyy HH:mm',
              ).format(widget.product.lastChecked),
            ),
            if (_priceAnalytics != null && _priceAnalytics!.totalDataPoints > 0)
              _buildDetailRow(
                'Price Data Points',
                '${_priceAnalytics!.totalDataPoints}',
              ),
            if (widget.product.description != null) ...[
              const SizedBox(height: 8),
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.description!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChart() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final stockAnalytics = _stockAnalytics;
    if (stockAnalytics == null || stockAnalytics.statusPoints.isEmpty) {
      // Let the ImprovedStockChart handle empty state display
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock History',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Flexible(
                    child: PopupMenuButton<String>(
                      initialValue: _selectedTimeRange,
                      onSelected: (value) {
                        setState(() {
                          _selectedTimeRange = value;
                          if (value == 'day') {
                            _selectedDay = DateTime.now();
                          } else {
                            _selectedDay = null;
                          }
                        });
                      },
                      itemBuilder:
                          (context) =>
                              _isPremium
                                  ? [
                                    const PopupMenuItem(
                                      value: 'day',
                                      child: Text('Today'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'week',
                                      child: Text('This Week'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'month',
                                      child: Text('This Month'),
                                    ),
                                  ]
                                  : [
                                    const PopupMenuItem(
                                      value: 'day',
                                      child: Text('Last 7 Days'),
                                    ),
                                  ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(100),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getTimeRangeLabel(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Use ImprovedStockChart with empty stock points - it will handle the empty state
              ImprovedStockChart(
                stockPoints:
                    const [], // Empty list will show appropriate empty state
                timeRange: _selectedTimeRange,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stock History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: PopupMenuButton<String>(
                    initialValue: _selectedTimeRange,
                    onSelected: (value) {
                      setState(() {
                        _selectedTimeRange = value;
                        if (value == 'day') {
                          _selectedDay = DateTime.now();
                        } else {
                          _selectedDay = null;
                        }
                      });
                    },
                    itemBuilder:
                        (context) =>
                            _isPremium
                                ? [
                                  const PopupMenuItem(
                                    value: 'day',
                                    child: Text('Today'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'week',
                                    child: Text('This Week'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'month',
                                    child: Text('This Month'),
                                  ),
                                ]
                                : [
                                  const PopupMenuItem(
                                    value: 'day',
                                    child: Text('Last 7 Days'),
                                  ),
                                ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(100),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeRangeLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stock Status Summary
            Row(
              children: [
                Expanded(
                  child: _buildStockStat(
                    'Availability',
                    '${stockAnalytics.availabilityPercentage.toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStockStat(
                    'Volatility',
                    stockAnalytics.isVolatileStock ? 'High' : 'Stable',
                    stockAnalytics.isVolatileStock ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStockStat(
                    'Trend',
                    stockAnalytics.currentTrend,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chart or Grid based on time range
            if (_selectedTimeRange == 'day' && _selectedDay != null)
              FutureBuilder<List<StockStatusPoint>>(
                future: _getStockHistoryForDay(_selectedDay!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Text('Failed to load daily stock data'),
                    );
                  }

                  return ImprovedStockGrid(
                    stockPoints: snapshot.data!,
                    selectedDay: _selectedDay!,
                  );
                },
              )
            else
              ImprovedStockChart(
                stockPoints: _getFilteredStockPoints(),
                timeRange: _selectedTimeRange,
              ),

            // Day picker for daily view
            if (_selectedTimeRange == 'day') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed:
                        _selectedDay != null
                            ? () => setState(() {
                              _selectedDay = _selectedDay!.subtract(
                                const Duration(days: 1),
                              );
                            })
                            : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: TextButton(
                        onPressed: () => _selectDate(),
                        child: Text(
                          _selectedDay != null
                              ? DateFormat('MMM dd, yyyy').format(_selectedDay!)
                              : 'Select Date',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _selectedDay != null &&
                                _selectedDay!.isBefore(
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                )
                            ? () => setState(() {
                              _selectedDay = _selectedDay!.add(
                                const Duration(days: 1),
                              );
                            })
                            : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeRangeLabel() {
    switch (_selectedTimeRange) {
      case 'day':
        return _isPremium ? 'Today' : 'Last 7 Days';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      default:
        return 'This Month';
    }
  }

  List<StockStatusPoint> _getFilteredStockPoints() {
    final stockAnalytics = _stockAnalytics;
    if (stockAnalytics == null) return [];

    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedTimeRange) {
      case 'day':
        cutoffDate =
            _isPremium
                ? now.subtract(const Duration(days: 1))
                : now.subtract(
                  const Duration(days: 7),
                ); // Show 7 days for free users
        break;
      case 'week':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      default:
        cutoffDate = now.subtract(const Duration(days: 30)); // Default to month
    }

    return stockAnalytics.statusPoints
        .where((point) => point.timestamp.isAfter(cutoffDate))
        .toList();
  }

  Future<List<StockStatusPoint>> _getStockHistoryForDay(DateTime day) async {
    try {
      return await _db.getStockHistoryForDay(widget.product.id, day);
    } catch (e) {
      return [];
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDay = picked;
      });
    }
  }

  /// Launches a URL in the default browser
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  /// Build history access badge showing subscription limitations
  Widget _buildHistoryAccessBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:
              isDark
                  ? Colors.green.shade800.withAlpha(100)
                  : Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.green.shade600 : Colors.green.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 12,
              color: isDark ? Colors.green.shade400 : Colors.green.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              'Full Access',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.green.shade400 : Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:
              isDark
                  ? Colors.orange.shade800.withAlpha(100)
                  : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.orange.shade600 : Colors.orange.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 12,
              color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              '${_currentTier.historyLimitDays} days',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Build subscription information banner
  Widget _buildSubscriptionInfoBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isDark
                  ? Colors.green.shade900.withAlpha(75)
                  : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.green.shade700 : Colors.green.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star,
              color: isDark ? Colors.amber.shade400 : Colors.amber.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Access',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isDark
                              ? Colors.green.shade300
                              : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Viewing full price & stock history with unlimited access',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? Colors.green.shade400
                              : Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isDark
                  ? Colors.orange.shade900.withAlpha(75)
                  : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info,
              color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limited History Access',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isDark
                              ? Colors.orange.shade300
                              : Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    'Free tier shows last ${_currentTier.historyLimitDays} days. Upgrade for full history access.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? Colors.orange.shade400
                              : Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showSimpleUpgradeDialog,
              style: TextButton.styleFrom(
                backgroundColor:
                    isDark
                        ? Colors.orange.shade800.withAlpha(75)
                        : Colors.orange.shade100,
                foregroundColor:
                    isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
  }

  /// Show simple upgrade dialog
  void _showSimpleUpgradeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Premium'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Get unlimited access to price and stock history:'),
              SizedBox(height: 16),
              Text('• Full price & stock history'),
              Text('• Unlimited favorite products'),
              Text('• Monitor all vendor sites'),
              Text('• Hourly check frequency'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => const SubscriptionUpgradeScreen(
                          sourceScreen: 'product_detail_history',
                        ),
                  ),
                );
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        );
      },
    );
  }

  /// Show error message in a snack bar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
