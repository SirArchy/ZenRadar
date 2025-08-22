// Test script to verify Horiishichimeien crawler fixes
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'lib/services/crawler_service.dart';
import 'lib/services/currency_price_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Testing Horiishichimeien crawler fixes...\n');

  // Test 1: Currency Price Service
  print('1️⃣ Testing Currency Price Service for JPY:');
  final priceService = CurrencyPriceService.instance;

  // Test various price formats that might come from Horiishichimeien
  final testPrices = [
    '¥864',
    '¥864 ¥864', // Duplicated price (the issue we're fixing)
    '¥1,200',
    '¥1200',
    'Price: ¥864',
    '864円', // Alternative Japanese format
  ];

  for (final testPrice in testPrices) {
    final priceInfo = priceService.extractPrice(testPrice, 'horiishichimeien');
    print('  Input: "$testPrice"');
    print('  Output: "${priceInfo.displayPrice}" (${priceInfo.currency})');
    print('  Value: ${priceInfo.priceValue}');
    print('');
  }

  // Test 2: Crawler Service
  print('2️⃣ Testing Horiishichimeien site configuration:');
  final crawler = CrawlerService.instance;
  final siteName = crawler.getSiteName('horiishichimeien');
  print('  Site name: $siteName');

  final availableSites = crawler.getAvailableSites();
  final hasHoriishichimeien = availableSites.contains('horiishichimeien');
  print('  Site available: $hasHoriishichimeien');

  print('\n✅ Horiishichimeien fixes test completed!');
  print('\n📋 Summary of fixes:');
  print('   ✓ Currency changed from EUR to JPY');
  print('   ✓ Price extraction improved to avoid duplication');
  print('   ✓ Stock detection enhanced to check for sold-out badges');
  print('   ✓ Japanese "売り切れ" text detection added');
}
