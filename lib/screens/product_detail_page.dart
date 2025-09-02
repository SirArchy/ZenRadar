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
import '../widgets/product_card.dart';
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

  Future<void> _loadUserSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        // Use user's preferred currency, fallback to product currency, then EUR
        _selectedCurrency =
            settings.preferredCurrency.isNotEmpty
                ? settings.preferredCurrency
                : (widget.product.currency ?? 'EUR');
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
        // Handle subscription limit or other errors
        if (result.limitReached && result.validationResult != null) {
          _showUpgradeDialog(result.validationResult!);
        } else {
          _showErrorSnackBar(result.error ?? 'Failed to update favorite');
        }
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
    return Stack(
      children: [
        ProductCard(
          product: widget.product,
          onTap: () => _launchUrl(widget.product.url),
          preferredCurrency: _selectedCurrency,
          isFavorite: _isFavorite,
          onFavoriteToggle: _toggleFavorite,
          hideLastChecked:
              true, // Hide last checked to prevent overlap with open URL button
        ),
        // Overlay the open URL button in the bottom right corner
        Positioned(
          right: 16,
          bottom: 28, // Position to replace the "last checked" section
          child: _buildOpenUrlButton(),
        ),
      ],
    );
  }

  Widget _buildOpenUrlButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _launchUrl(widget.product.url),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.open_in_new,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceOverview() {
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

  Widget _buildPriceChart() {
    if (_priceAnalytics == null || _filteredHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No price data available for selected time range',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ),
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
                      (context) => [
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
                        const PopupMenuItem(
                          value: 'all',
                          child: Text('All Time'),
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
            // Use the improved price chart
            ImprovedPriceChart(
              priceHistory: _filteredHistory,
              currencySymbol: _currentCurrencySymbol,
              timeRange: _selectedTimeRange,
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
            if (_convertedPrice != null)
              _buildDetailRow(
                'Current Price',
                '${_convertedPrice!.toStringAsFixed(2)}$_currentCurrencySymbol',
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Stock History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('No stock history available yet'),
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
                        (context) => [
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
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('All Time'),
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
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'all':
        return 'All Time';
      default:
        return 'All Time';
    }
  }

  List<StockStatusPoint> _getFilteredStockPoints() {
    final stockAnalytics = _stockAnalytics;
    if (stockAnalytics == null) return [];

    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedTimeRange) {
      case 'day':
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case 'week':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      default:
        return stockAnalytics.statusPoints;
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

  /// Show upgrade dialog when subscription limits are reached
  void _showUpgradeDialog(FavoriteValidationResult validationResult) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${validationResult.tier.displayName} Limit Reached'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(validationResult.message),
              const SizedBox(height: 16),
              Text(
                'Upgrade to Premium for:',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Unlimited favorites'),
              const Text('• Monitor all vendors'),
              const Text('• Hourly check frequency'),
              const Text('• Full history access'),
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
                        (context) => SubscriptionUpgradeScreen(
                          validationResult: validationResult,
                          sourceScreen: 'product_detail',
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

  /// Build history access badge showing subscription limitations
  Widget _buildHistoryAccessBadge() {
    if (_isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'Full Access',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              '${_currentTier.historyLimitDays} days',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Build subscription information banner
  Widget _buildSubscriptionInfoBanner() {
    if (_isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.star, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Access',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Viewing full price & stock history with unlimited access',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
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
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limited History Access',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    'Free tier shows last ${_currentTier.historyLimitDays} days. Upgrade for full history access.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showSimpleUpgradeDialog,
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade800,
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
