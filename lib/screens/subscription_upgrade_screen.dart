import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../services/subscription_service.dart';

class SubscriptionUpgradeScreen extends StatefulWidget {
  final FavoriteValidationResult? validationResult;
  final String? sourceScreen; // For analytics tracking

  const SubscriptionUpgradeScreen({
    super.key,
    this.validationResult,
    this.sourceScreen,
  });

  @override
  State<SubscriptionUpgradeScreen> createState() =>
      _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState extends State<SubscriptionUpgradeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  SubscriptionTier _currentTier = SubscriptionTier.free;
  TierComparison? _tierComparison;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _loadSubscriptionData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final tier = await SubscriptionService.instance.getCurrentTier();
      final comparison = SubscriptionService.instance.getTierComparison();

      setState(() {
        _currentTier = tier;
        _tierComparison = comparison;
      });
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                if (widget.validationResult != null) ...[
                  _buildLimitReachedCard(),
                  const SizedBox(height: 24),
                ],
                _buildPricingCards(),
                const SizedBox(height: 32),
                _buildFeatureComparison(),
                const SizedBox(height: 32),
                _buildTestimonials(),
                const SizedBox(height: 32),
                _buildFAQ(),
                const SizedBox(height: 32),
                _buildUpgradeButton(),
                const SizedBox(height: 16),
                _buildContactSupport(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.amber.shade100, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlock Premium Features',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Get unlimited access to all matcha vendors, faster notifications, and comprehensive analytics.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedCard() {
    final result = widget.validationResult!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Limit Reached',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.message,
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Plan',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildPricingCard(isFreeTier: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildPricingCard(isFreeTier: false)),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingCard({required bool isFreeTier}) {
    final isCurrentTier =
        isFreeTier
            ? _currentTier == SubscriptionTier.free
            : _currentTier == SubscriptionTier.premium;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isFreeTier ? Colors.grey.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFreeTier ? Colors.grey.shade300 : Colors.amber.shade300,
          width: isCurrentTier ? 2 : 1,
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
              'or \$29.99/year (save 65%)',
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
          if (isCurrentTier)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isFreeTier ? Colors.grey.shade200 : Colors.amber.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Current Plan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isFreeTier ? Colors.grey.shade700 : Colors.amber.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    if (_tierComparison == null) return const SizedBox();

    final comparison = _tierComparison!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feature Comparison',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildFeatureRow(
                'Favorite Products',
                '${comparison.free.maxFavorites}',
                'Unlimited',
                Icons.favorite,
              ),
              _buildFeatureRow(
                'Vendor Sites',
                '${comparison.free.maxVendors} sites',
                'All sites',
                Icons.store,
              ),
              _buildFeatureRow(
                'Check Frequency',
                'Every ${comparison.free.checkFrequencyHours}h',
                'Every ${comparison.premium.checkFrequencyHours}h',
                Icons.schedule,
              ),
              _buildFeatureRow(
                'Analytics History',
                '${comparison.free.historyDays} days',
                'Unlimited',
                Icons.analytics,
              ),
              _buildFeatureRow(
                'Priority Notifications',
                'Basic',
                'Premium',
                Icons.notifications_active,
                isLastRow: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    String feature,
    String freeValue,
    String premiumValue,
    IconData icon, {
    bool isLastRow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border:
            isLastRow
                ? null
                : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              freeValue,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              premiumValue,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What Premium Users Say',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTestimonialCard(
          'Sarah M.',
          'Tea Enthusiast',
          'Premium notifications helped me snag limited edition matcha from Kyoto before it sold out!',
          Icons.star,
        ),
        const SizedBox(height: 12),
        _buildTestimonialCard(
          'Ken T.',
          'Matcha Collector',
          'Monitoring all vendors simultaneously saved me hours of manual checking.',
          Icons.star,
        ),
      ],
    );
  }

  Widget _buildTestimonialCard(
    String name,
    String title,
    String testimonial,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.amber.shade100,
                child: Icon(icon, color: Colors.amber.shade700),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            testimonial,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildFAQItem(
          'Can I cancel anytime?',
          'Yes! You can cancel your subscription at any time. You\'ll continue to have premium access until the end of your billing period.',
        ),
        _buildFAQItem(
          'Is there a free trial?',
          'Yes! New users get a 7-day free trial of all premium features.',
        ),
        _buildFAQItem(
          'What payment methods do you accept?',
          'We accept all major credit cards, PayPal, and mobile payments through app stores.',
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    if (_currentTier == SubscriptionTier.premium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You already have Premium access!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleUpgrade,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.upgrade, size: 24),
            label: Text(
              _isLoading ? 'Processing...' : 'Start 7-Day Free Trial',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.amber.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Premium features available immediately. Cancel anytime.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildContactSupport() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.support_agent, color: Colors.blue.shade700, size: 24),
          const SizedBox(height: 8),
          Text(
            'Need Help?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Contact our support team for any questions',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _contactSupport,
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpgrade() async {
    setState(() => _isLoading = true);

    try {
      // Show coming soon message for now
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium upgrade coming soon! 🚀'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // TODO: Implement actual payment processing
      // For now, just show a placeholder
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _contactSupport() async {
    const email = 'support@zenradar.app';
    const subject = 'Premium Subscription Question';
    const body = 'Hi,\n\nI have a question about the Premium subscription.\n\n';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email app. Please contact support@zenradar.app',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
