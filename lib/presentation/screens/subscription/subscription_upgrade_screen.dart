// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zenradar/models/matcha_product.dart';
import 'package:zenradar/data/services/subscription/subscription_service.dart';
import 'package:zenradar/data/services/subscription/payment_service.dart';

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
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.upgradeToPremium),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [
                    Colors.amber.shade800.withAlpha(75),
                    Colors.orange.shade800.withAlpha(75),
                  ]
                  : [Colors.amber.shade100, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.unlockPremiumFeatures,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.premiumUpgradeSubtitle,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedCard() {
    final result = widget.validationResult!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.orange.shade900.withAlpha(75)
                : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.limitReached,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.message,
                  style: TextStyle(
                    color:
                        isDark
                            ? Colors.orange.shade400
                            : Colors.orange.shade700,
                    fontSize: 13,
                  ),
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
        Text(
          AppLocalizations.of(context)!.choosePlanTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    final l10n = AppLocalizations.of(context)!;
    final isCurrentTier =
        isFreeTier
            ? _currentTier == SubscriptionTier.free
            : _currentTier == SubscriptionTier.premium;
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
                isFreeTier ? l10n.free : l10n.premium,
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
                  l10n.perMonth,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.yearlyPlanSavings,
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
              l10n.foreverFree,
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
                l10n.currentPlan,
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

    final l10n = AppLocalizations.of(context)!;
    final comparison = _tierComparison!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.featureComparison,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              _buildFeatureRow(
                l10n.favoriteProductsLabel,
                '${comparison.free.maxFavorites} ${l10n.maximum}',
                l10n.unlimitedLabel,
                Icons.favorite,
              ),
              _buildFeatureRow(
                l10n.scanFrequency,
                l10n.everyHours(comparison.free.checkFrequencyHours),
                l10n.everyHours(comparison.premium.checkFrequencyHours),
                Icons.schedule,
              ),
              _buildFeatureRow(
                l10n.analyticsHistoryLabel,
                '${comparison.free.historyDays} ${l10n.days}',
                l10n.unlimitedLabel,
                Icons.analytics,
              ),
              _buildFeatureRow(
                l10n.priorityNotifications,
                l10n.basicLabel,
                l10n.premium,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border:
            isLastRow
                ? null
                : Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
                  ),
                ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: const TextStyle(fontWeight: FontWeight.w500),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              freeValue,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              premiumValue,
              textAlign: TextAlign.center,
              softWrap: true,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.whatPremiumUsersSay,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTestimonialCard(
          l10n.testimonialUserOneName,
          l10n.testimonialUserOneTitle,
          l10n.testimonialUserOneQuote,
          Icons.star,
        ),
        const SizedBox(height: 12),
        _buildTestimonialCard(
          l10n.testimonialUserTwoName,
          l10n.testimonialUserTwoTitle,
          l10n.testimonialUserTwoQuote,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
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
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade200 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            testimonial,
            style: TextStyle(
              color: isDark ? Colors.grey.shade200 : Colors.grey.shade700,
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
        Text(
          AppLocalizations.of(context)!.frequentlyAskedQuestions,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildFAQItem(
          AppLocalizations.of(context)!.canICancelAnytime,
          AppLocalizations.of(context)!.cancelAnytimeAnswer,
        ),
        _buildFAQItem(
          AppLocalizations.of(context)!.isThereFreeTrial,
          AppLocalizations.of(context)!.freeTrialAnswer,
        ),
        _buildFAQItem(
          AppLocalizations.of(context)!.whatPaymentMethods,
          AppLocalizations.of(context)!.paymentMethodsAnswer,
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    final l10n = AppLocalizations.of(context)!;
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
            Expanded(
              child: Text(
                l10n.youAlreadyHavePremiumAccess,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<TrialStatus>(
      future: PaymentService.instance.getTrialStatus(),
      builder: (context, snapshot) {
        final trialStatus = snapshot.data;

        // Show trial options if user can start trial
        if (trialStatus?.canStart == true) {
          return Column(
            children: [
              // Start Trial Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleStartTrial,
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.play_arrow, size: 24),
                  label: Text(
                    _isLoading ? l10n.startingTrial : l10n.startFreeTrial,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.fullPremiumNoCardRequired,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Or upgrade directly
              TextButton(
                onPressed: _isLoading ? null : _handleUpgrade,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber.shade700,
                ),
                child: Text(l10n.upgradeDirectlyWithPayment),
              ),
            ],
          );
        }

        // Show active trial status
        if (trialStatus?.isActive == true) {
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
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.freeTrialActive,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.daysRemaining(trialStatus!.daysRemaining),
                  style: TextStyle(color: Colors.blue.shade700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.amber.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(l10n.upgradeNowKeepPremium),
                  ),
                ),
              ],
            ),
          );
        }

        // Default upgrade button for users who already used trial
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
                  _isLoading ? l10n.processing : l10n.upgradeToPremium,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
              l10n.premiumFeaturesAvailableImmediatelyCancelAnytime,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactSupport() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade200 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.support_agent, color: Colors.blue.shade700, size: 24),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.needHelp,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.contactSupportTeam,
            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _contactSupport,
            child: Text(
              AppLocalizations.of(context)!.contactSupport,
              style: TextStyle(
                color: isDark ? Colors.amber.shade800 : Colors.amber.shade200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpgrade() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      // Import the payment service
      final PaymentService paymentService = PaymentService.instance;

      // Start premium upgrade flow (defaults to monthly)
      await paymentService.startPremiumUpgrade(
        plan: 'monthly', // You can add UI to let users choose monthly vs yearly
        successUrl: 'https://your-app.com/success',
        cancelUrl: 'https://your-app.com/cancel',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.redirectingToSecureCheckout),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithDetails('$e')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleStartTrial() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await PaymentService.instance.startFreeTrial();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.freeTrialStartedEnjoyPremium),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Close the upgrade screen since user now has premium access
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorStartingTrialWithError('$e')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _contactSupport() async {
    final l10n = AppLocalizations.of(context)!;
    const email = 'support@zenradar.app';
    final subject = l10n.premiumSubscriptionQuestion;
    final body = l10n.premiumSubscriptionQuestionBody;

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
          SnackBar(
            content: Text(l10n.couldNotOpenEmailAppContactSupport),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
