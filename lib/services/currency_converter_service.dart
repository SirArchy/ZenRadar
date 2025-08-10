// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConverterService {
  static const String _apiUrl = 'https://api.exchangerate-api.com/v4/latest/';
  static const String _cacheKey = 'exchange_rates';
  static const Duration _cacheDuration = Duration(hours: 12);

  Future<Map<String, dynamic>> _fetchExchangeRates(String baseCurrency) async {
    final response = await http.get(Uri.parse('$_apiUrl$baseCurrency'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['rates'] as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch exchange rates');
    }
  }

  Future<Map<String, dynamic>> getExchangeRates(String baseCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);
    final now = DateTime.now();

    if (cachedData != null) {
      final cached = json.decode(cachedData) as Map<String, dynamic>;
      final cacheTime = DateTime.parse(cached['timestamp'] as String);

      if (now.difference(cacheTime) < _cacheDuration) {
        return cached['rates'] as Map<String, dynamic>;
      }
    }

    final rates = await _fetchExchangeRates(baseCurrency);
    final cache = {'timestamp': now.toIso8601String(), 'rates': rates};

    prefs.setString(_cacheKey, json.encode(cache));
    return rates;
  }

  Future<double?> convert(
    String fromCurrency,
    String toCurrency,
    double amount,
  ) async {
    try {
      final rates = await getExchangeRates(fromCurrency);
      if (rates.containsKey(toCurrency)) {
        return amount * (rates[toCurrency] as double);
      }
    } catch (e) {
      debugPrint('Currency conversion failed: $e');
    }
    return null;
  }
}
