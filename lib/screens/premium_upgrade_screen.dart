import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  final VoidCallback? onContinue;
  final VoidCallback? onUpgrade;

  const PremiumUpgradeScreen({super.key, this.onContinue, this.onUpgrade});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark
                  ? Colors.amber.shade900.withAlpha(50)
                  : Colors.amber.shade50,
              isDark ? Colors.grey.shade900 : Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildPricingComparison(),
                    const SizedBox(height: 32),
                    _buildKeyFeatures(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Premium icon with animation
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade400, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withAlpha(75),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.star, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 32),

        // Title
        Text(
          'Choose Your ZenRadar Experience',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Subtitle
        Text(
          'Start with a free account or unlock unlimited potential with Premium',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade600,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPricingComparison() {
    return Row(
      children: [
        Expanded(child: _buildPricingCard(isFreeTier: true)),
        const SizedBox(width: 16),
        Expanded(child: _buildPricingCard(isFreeTier: false)),
      ],
    );
  }

  Widget _buildPricingCard({required bool isFreeTier}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            isFreeTier
                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade50)
                : (isDark
                    ? Colors.amber.shade900.withAlpha(75)
                    : Colors.amber.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isFreeTier
                  ? (isDark ? Colors.grey.shade600 : Colors.grey.shade300)
                  : (isDark ? Colors.amber.shade600 : Colors.amber.shade300),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFreeTier ? Icons.person : Icons.star,
                color:
                    isFreeTier ? Colors.grey.shade600 : Colors.amber.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isFreeTier ? 'Free' : 'Premium',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      isFreeTier ? Colors.grey.shade700 : Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isFreeTier) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$2.99',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                Text(
                  '/month',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '7-day free trial',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              '\$0',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Forever free',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          _buildFeatureList(isFreeTier),
        ],
      ),
    );
  }

  Widget _buildFeatureList(bool isFreeTier) {
    final features =
        isFreeTier
            ? [
              'Up to 42 favorite products',
              '5 vendor sites',
              'Check every 6 hours',
              'Basic notifications',
            ]
            : [
              'Unlimited favorites',
              'All vendor sites',
              'Check every hour',
              'Priority notifications',
            ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color:
                        isFreeTier
                            ? Colors.grey.shade600
                            : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isFreeTier
                                ? Colors.grey.shade600
                                : Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildKeyFeatures() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Choose Premium?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureHighlight(
            Icons.speed,
            'Faster Updates',
            'Get notified within the hour of stock changes',
          ),
          _buildFeatureHighlight(
            Icons.store,
            'All Vendors',
            'Monitor all matcha vendors simultaneously',
          ),
          _buildFeatureHighlight(
            Icons.favorite,
            'Unlimited Favorites',
            'Track as many products as you want',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlight(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.amber.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Start Free Trial button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _startFreeTrial,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: Colors.amber.withAlpha(125),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Start 7-Day Free Trial',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
        const SizedBox(height: 16),

        // Continue with Free button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Continue with Free Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Trial disclaimer
        Text(
          'Free trial includes all Premium features. Cancel anytime.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _startFreeTrial() async {
    setState(() => _isLoading = true);
    try {
      await PaymentService.instance.startFreeTrial();
      if (mounted) {
        widget.onUpgrade?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start trial: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
