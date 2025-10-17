import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../models/matcha_product.dart';

/// Service for handling Stripe payments and subscription management
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  static PaymentService get instance => _instance;

  // Your Firebase Functions URL - update this with your actual URL
  static const String _functionsBaseUrl =
      'https://europe-west3-zenradar-acb85.cloudfunctions.net';

  /// Stripe price IDs - create these in your Stripe dashboard
  static const String monthlyPriceId =
      'price_monthly_premium'; // Replace with actual price ID
  static const String yearlyPriceId =
      'price_yearly_premium'; // Replace with actual price ID

  /// Create a checkout session for premium subscription
  Future<String?> createCheckoutSession({
    required String plan, // 'monthly' or 'yearly'
    String? successUrl,
    String? cancelUrl,
    bool? isTrialFlow, // Whether this is starting from trial
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final priceId = plan == 'yearly' ? yearlyPriceId : monthlyPriceId;

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createCheckoutSession'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'userId': user.uid,
          'priceId': priceId,
          'successUrl': successUrl ?? 'https://your-app.com/success',
          'cancelUrl': cancelUrl ?? 'https://your-app.com/cancel',
          'isTrialFlow': isTrialFlow ?? false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sessionUrl'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to create checkout session: ${error['error']}');
      }
    } catch (e) {
      debugPrint('Error creating checkout session: $e');
      rethrow;
    }
  }

  /// Create customer portal session for subscription management
  Future<String?> createCustomerPortalSession({String? returnUrl}) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createCustomerPortalSession'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'userId': user.uid,
          'returnUrl': returnUrl ?? 'https://your-app.com/settings',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sessionUrl'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          'Failed to create customer portal session: ${error['error']}',
        );
      }
    } catch (e) {
      debugPrint('Error creating customer portal session: $e');
      rethrow;
    }
  }

  /// Get current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse(
          '$_functionsBaseUrl/getUserSubscriptionStatus?userId=${user.uid}',
        ),
        headers: {'Authorization': 'Bearer ${await user.getIdToken()}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SubscriptionStatus.fromJson(data);
      } else if (response.statusCode == 404) {
        // User doesn't exist yet, return default free status
        return SubscriptionStatus.free();
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to get subscription status: ${error['error']}');
      }
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      // Return free status on error to prevent app crashes
      return SubscriptionStatus.free();
    }
  }

  /// Launch checkout URL in browser
  Future<void> launchCheckout(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Opens in browser
      );
    } else {
      throw Exception('Could not launch checkout URL');
    }
  }

  /// Launch customer portal URL in browser
  Future<void> launchCustomerPortal(String portalUrl) async {
    final uri = Uri.parse(portalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Opens in browser
      );
    } else {
      throw Exception('Could not launch customer portal URL');
    }
  }

  /// Start premium upgrade flow
  Future<void> startPremiumUpgrade({
    required String plan,
    String? successUrl,
    String? cancelUrl,
    bool? isTrialFlow,
  }) async {
    try {
      final checkoutUrl = await createCheckoutSession(
        plan: plan,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
        isTrialFlow: isTrialFlow,
      );

      if (checkoutUrl != null) {
        await launchCheckout(checkoutUrl);
      } else {
        throw Exception('Failed to create checkout session');
      }
    } catch (e) {
      debugPrint('Error starting premium upgrade: $e');
      rethrow;
    }
  }

  /// Start a free trial (no payment required)
  Future<bool> startFreeTrial() async {
    try {
      // Import subscription service to start the trial
      final SubscriptionService subscriptionService =
          SubscriptionService.instance;
      return await subscriptionService.startTrial();
    } catch (e) {
      debugPrint('Error starting free trial: $e');
      return false;
    }
  }

  /// Check trial status
  Future<TrialStatus> getTrialStatus() async {
    try {
      // Import subscription service to get trial status
      final SubscriptionService subscriptionService =
          SubscriptionService.instance;
      return await subscriptionService.getTrialStatus();
    } catch (e) {
      debugPrint('Error getting trial status: $e');
      return TrialStatus(
        canStart: false,
        isActive: false,
        hasExpired: false,
        daysRemaining: 0,
      );
    }
  }

  /// Open subscription management portal
  Future<void> openSubscriptionManagement({String? returnUrl}) async {
    try {
      final portalUrl = await createCustomerPortalSession(returnUrl: returnUrl);

      if (portalUrl != null) {
        await launchCustomerPortal(portalUrl);
      } else {
        throw Exception('Failed to create customer portal session');
      }
    } catch (e) {
      debugPrint('Error opening subscription management: $e');
      rethrow;
    }
  }

  /// Set debug premium mode (development only)
  Future<bool> setDebugPremiumMode(bool enabled) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/setDebugPremiumMode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({'userId': user.uid, 'enabled': enabled}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint(
          'Debug premium mode ${enabled ? 'enabled' : 'disabled'}: ${data['message']}',
        );
        return data['success'] ?? false;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to set debug premium mode: ${error['error']}');
      }
    } catch (e) {
      debugPrint('Error setting debug premium mode: $e');
      return false;
    }
  }
}

/// Subscription status model
class SubscriptionStatus {
  final bool isPremium;
  final String subscriptionTier;
  final String subscriptionStatus;
  final String? subscriptionId;
  final DateTime? currentPeriodEnd;
  final String? customerId;

  SubscriptionStatus({
    required this.isPremium,
    required this.subscriptionTier,
    required this.subscriptionStatus,
    this.subscriptionId,
    this.currentPeriodEnd,
    this.customerId,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isPremium: json['isPremium'] ?? false,
      subscriptionTier: json['subscriptionTier'] ?? 'free',
      subscriptionStatus: json['subscriptionStatus'] ?? 'inactive',
      subscriptionId: json['subscriptionId'],
      currentPeriodEnd:
          json['currentPeriodEnd'] != null
              ? DateTime.parse(json['currentPeriodEnd'])
              : null,
      customerId: json['customerId'],
    );
  }

  factory SubscriptionStatus.free() {
    return SubscriptionStatus(
      isPremium: false,
      subscriptionTier: 'free',
      subscriptionStatus: 'inactive',
    );
  }

  bool get isActive => subscriptionStatus == 'active';
  bool get isCanceled => subscriptionStatus == 'canceled';
  bool get isPastDue => subscriptionStatus == 'past_due';

  @override
  String toString() {
    return 'SubscriptionStatus(isPremium: $isPremium, tier: $subscriptionTier, '
        'status: $subscriptionStatus, periodEnd: $currentPeriodEnd)';
  }
}
