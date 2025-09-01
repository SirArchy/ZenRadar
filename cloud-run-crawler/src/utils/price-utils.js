/**
 * Price utilities for parsing and converting prices across different sites and currencies
 */
class PriceUtils {
  constructor() {
    // Fixed exchange rates (should be updated regularly in production)
    this.exchangeRates = {
      'USD': 0.85,    // 1 USD = 0.85 EUR
      'CAD': 0.63,    // 1 CAD = 0.63 EUR  
      'JPY': 0.0058,  // 1 JPY = 0.0058 EUR (updated for accurate conversion)
      'GBP': 1.17,    // 1 GBP = 1.17 EUR
      'SEK': 0.086,   // 1 SEK = 0.086 EUR (for Poppatea)
      'DKK': 0.134,   // 1 DKK = 0.134 EUR
      'NOK': 0.085,   // 1 NOK = 0.085 EUR
    };
  }

  /**
   * Parse price text and extract currency and amount
   */
  parsePriceAndCurrency(priceText) {
    if (!priceText) return { amount: null, currency: 'EUR' };

    const cleaned = priceText.replace(/\s+/g, ' ').trim();
    
    // Currency patterns
    const patterns = [
      { regex: /€(\d+[.,]\d+)/, currency: 'EUR' },           // €12.50
      { regex: /(\d+[.,]\d+)\s*€/, currency: 'EUR' },        // 12.50€ or 5,00€
      { regex: /\$(\d+[.,]\d+)/, currency: 'USD' },          // $12.50
      { regex: /(\d+[.,]\d+)\s*USD/, currency: 'USD' },      // 12.50 USD
      { regex: /CAD\s*(\d+[.,]\d+)/, currency: 'CAD' },      // CAD 15.00
      { regex: /(\d+[.,]\d+)\s*CAD/, currency: 'CAD' },      // 15.00 CAD
      { regex: /¥(\d{1,3}(?:,\d{3})*(?:\.\d+)?)/i, currency: 'JPY' }, // ¥10,800 or ¥648
      { regex: /(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*¥/i, currency: 'JPY' }, // 10800 ¥
      { regex: /(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*JPY/i, currency: 'JPY' }, // 10800 JPY
      { regex: /£(\d+[.,]\d+)/, currency: 'GBP' },           // £12.50
      { regex: /(\d+(?:[.,]\d+)?)\s*kr\b/i, currency: 'SEK' },       // 160 kr (Poppatea)
      { regex: /(\d+[.,]\d+)\s*DKK/, currency: 'DKK' },      // 12.50 DKK
      { regex: /(\d+[.,]\d+)\s*NOK/, currency: 'NOK' },      // 12.50 NOK
    ];

    for (const pattern of patterns) {
      const match = cleaned.match(pattern.regex);
      if (match) {
        const amountStr = match[1].replace(',', '.');
        const amount = parseFloat(amountStr);
        
        if (!isNaN(amount) && amount > 0) {
          return { amount, currency: pattern.currency };
        }
      }
    }

    // Fallback: try to extract any number and assume EUR
    const numberMatch = cleaned.match(/(\d+[.,]\d+)/);
    if (numberMatch) {
      const amountStr = numberMatch[1].replace(',', '.');
      const amount = parseFloat(amountStr);
      if (!isNaN(amount) && amount > 0) {
        return { amount, currency: 'EUR' };
      }
    }

    return { amount: null, currency: 'EUR' };
  }

  /**
   * Convert amount to EUR
   */
  convertToEUR(amount, fromCurrency) {
    if (!amount || fromCurrency === 'EUR') {
      return amount;
    }

    const rate = this.exchangeRates[fromCurrency];
    if (!rate) {
      console.warn('Unknown currency for conversion', { fromCurrency, amount });
      return amount;
    }

    const convertedAmount = amount * rate;
    return parseFloat(convertedAmount.toFixed(2));
  }

  /**
   * Extract numeric price value from price string
   */
  extractPriceValue(priceString) {
    if (!priceString) return null;

    // Handle multi-currency strings like "¥2,000$13.57€11.66£10.04¥97.06"
    // Extract EUR price first if present
    const eurMatch = priceString.match(/€(\d+[.,]?\d*)/);
    if (eurMatch) {
      const eurValue = parseFloat(eurMatch[1].replace(',', '.'));
      return eurValue > 0 ? eurValue : null;
    }

    // Handle Japanese Yen (no decimal places, may have comma thousands separator)
    if (priceString.includes('¥') || priceString.includes('￥')) {
      // For multi-currency strings, extract only the first Yen value
      const yenMatch = priceString.match(/[¥￥](\d+(?:,\d{3})*)/);
      if (yenMatch) {
        const cleaned = yenMatch[1].replace(/,/g, '');
        const jpyValue = parseInt(cleaned);
        return jpyValue > 0 ? jpyValue : null;
      }
      
      // Fallback for simple Yen extraction
      const cleaned = priceString.replace(/[¥￥]/g, '').replace(/[^\d]/g, '');
      const jpyValue = parseInt(cleaned);
      return jpyValue > 0 ? jpyValue : null;
    }

    // Handle European format with comma as decimal separator
    if (/\d+,\d{2}/.test(priceString)) {
      const cleaned = priceString.replace(/[€$£]/g, '').replace(/[^\d,]/g, '');
      const euroValue = parseFloat(cleaned.replace(',', '.'));
      return euroValue > 0 ? euroValue : null;
    }

    // Handle standard format with period as decimal separator
    const cleaned = priceString.replace(/[€$¥£￥]/g, '').replace(/[^\d.]/g, '');
    
    // Extract the first number with decimal places
    const priceMatch = cleaned.match(/(\d+)\.(\d+)/);
    if (priceMatch) {
      const wholePart = parseInt(priceMatch[1]);
      const decimalPart = parseInt(priceMatch[2]) / 100;
      return wholePart + decimalPart;
    }

    // Try extracting integer prices
    const intMatch = cleaned.match(/(\d+)/);
    if (intMatch) {
      return parseInt(intMatch[1]);
    }

    return null;
  }

  /**
   * Clean price string based on site-specific logic
   */
  cleanPriceBySite(rawPrice, siteKey) {
    if (!rawPrice) return '';

    let cleaned = rawPrice.trim();

    switch (siteKey) {
      case 'tokichi':
        return this.cleanTokichiPrice(cleaned);
      case 'marukyu':
        return this.cleanMarukyuPrice(cleaned);
      case 'ippodo':
        return this.cleanIppodoPrice(cleaned);
      case 'sho-cha':
        return this.cleanShoChaPrice(cleaned);
      case 'matcha-karu':
        return this.cleanMatchaKaruPrice(cleaned);
      case 'poppatea':
        return this.cleanPoppateaPrice(cleaned);
      case 'yoshien':
        return this.cleanYoshienPrice(cleaned);
      case 'sazentea':
        return this.cleanSazenteaPrice(cleaned);
      case 'enjoyemeri':
        return this.cleanEnjoyemeriPrice(cleaned);
      case 'horiishichimeien':
        return this.cleanHoriishichimeienPrice(cleaned);
      default:
        return this.cleanGenericPrice(cleaned);
    }
  }

  cleanTokichiPrice(cleaned) {
    // Fix duplicate price issue: €28,00€28,00 -> €28,00
    const duplicateMatch = cleaned.match(/(€\d+[.,]\d+)€\d+[.,]\d+/);
    if (duplicateMatch) {
      cleaned = duplicateMatch[1];
    }

    // Extract Euro price
    const euroMatch = cleaned.match(/€(\d+[.,]\d+)/);
    if (euroMatch) {
      const priceText = euroMatch[1].replace(',', '.');
      return `€${priceText}`;
    }
    return '';
  }

  cleanMarukyuPrice(cleaned) {
    // Handle multi-currency format: "4209.61€8.26£7.15¥68.39"
    const eurMatch = cleaned.match(/€(\d+[.,]\d+)/);
    if (eurMatch) {
      const priceText = eurMatch[1].replace(',', '.');
      return `€${priceText}`;
    }

    // Handle tilde-separated format: "100~14.21~€12.21~"
    if (cleaned.includes('~')) {
      const euroTildeMatch = cleaned.match(/€([0-9.,]+)~/);
      if (euroTildeMatch) {
        const priceText = euroTildeMatch[1].replace(',', '.');
        return `€${priceText}`;
      }
    }

    // Convert other currencies to Euro
    const conversionResults = [
      this.convertCurrencyMatch(cleaned, /[\$](\d+[.,]\d+)/, 'USD'),
      this.convertCurrencyMatch(cleaned, /£(\d+[.,]\d+)/, 'GBP'),
      this.convertCurrencyMatch(cleaned, /¥(\d+[.,]\d+)/, 'JPY')
    ];

    for (const result of conversionResults) {
      if (result) return result;
    }

    return '';
  }

  cleanIppodoPrice(cleaned) {
    // Extract Yen price and convert to Euro
    let jpyMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})*)/); // With comma separator
    if (!jpyMatch) {
      jpyMatch = cleaned.match(/¥(\d+)/); // Without comma separator for small amounts
    }
    
    if (jpyMatch) {
      const jpyValue = parseFloat(jpyMatch[1].replace(/,/g, ''));
      const euroValue = this.convertToEUR(jpyValue, 'JPY');
      return `€${euroValue.toFixed(2)}`;
    }

    // Handle format without currency symbol (assume JPY)
    const numMatch = cleaned.match(/(\d+[.,]\d+)/);
    if (numMatch) {
      const jpyValue = parseFloat(numMatch[1].replace(',', ''));
      const euroValue = this.convertToEUR(jpyValue, 'JPY');
      return `€${euroValue.toFixed(2)}`;
    }

    return '';
  }

  cleanShoChaPrice(cleaned) {
    // Handle German Euro formatting: "5,00€" or "24,00 €"
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    const shoChaEuroMatch = cleaned.match(/(\d+(?:,\d{2})?)\s*€/);
    if (shoChaEuroMatch) {
      const price = parseFloat(shoChaEuroMatch[1].replace(',', '.'));
      return `€${price.toFixed(2)}`;
    }
    
    // Try USD format and convert
    const shoChaUsdMatch = cleaned.match(/\$(\d+(?:\.\d{2})?)/);
    if (shoChaUsdMatch) {
      const usdValue = parseFloat(shoChaUsdMatch[1]);
      const euroValue = this.convertToEUR(usdValue, 'USD');
      return `€${euroValue.toFixed(2)}`;
    }

    return '';
  }

  cleanHoriishichimeienPrice(cleaned) {
    // For Horiishichimeien, handle Japanese Yen prices and convert to Euro
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|JPY/gi, '');
    
    // Extract only the first valid Yen price to avoid duplicates
    let horiYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})+)/); // With comma separator for thousands
    if (horiYenMatch) {
      const jpyValue = parseFloat(horiYenMatch[1].replace(/,/g, '')); // Remove commas: "10,800" -> 10800
      const euroValue = this.convertToEUR(jpyValue, 'JPY');
      return `€${euroValue.toFixed(2)}`;
    }
    
    // Handle prices without comma separator (for amounts under 1000)
    horiYenMatch = cleaned.match(/¥(\d+)(?!\d)/); // Ensure we don't partial match longer numbers
    if (horiYenMatch) {
      const jpyValue = parseFloat(horiYenMatch[1]);
      const euroValue = this.convertToEUR(jpyValue, 'JPY');
      return `€${euroValue.toFixed(2)}`;
    }
    
    // Handle format without currency symbol (assume JPY if Japanese site)
    const horiNumMatch = cleaned.match(/(\d{1,3}(?:,\d{3})+|\d+)/);
    if (horiNumMatch) {
      const jpyValue = parseFloat(horiNumMatch[1].replace(/,/g, ''));
      const euroValue = this.convertToEUR(jpyValue, 'JPY');
      return `€${euroValue.toFixed(2)}`;
    }

    return '';
  }

  cleanPoppateaPrice(cleaned) {
    // Handle Swedish Krona format (XXX kr)
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    cleaned = cleaned.replace(/Ordinarie pris|Försäljningspris|Från|Enhetspris|per/gi, '');
    
    const poppateaKrMatch = cleaned.match(/(\d+)\s*kr/i);
    if (poppateaKrMatch) {
      const sekValue = parseFloat(poppateaKrMatch[1]);
      const euroValue = this.convertToEUR(sekValue, 'SEK');
      return `€${euroValue.toFixed(2)}`;
    }
    
    // Handle Euro format as fallback
    const poppateaEurMatch = cleaned.match(/€?\s*(\d+[,.]\d{2})\s*€?/);
    if (poppateaEurMatch) {
      const price = poppateaEurMatch[1].replace(',', '.');
      return `€${price}`;
    }
    
    // Also try to match prices without decimals
    const simpleMatch = cleaned.match(/€?\s*(\d+)\s*€?/);
    if (simpleMatch) {
      return `€${simpleMatch[1]}.00`;
    }

    return '';
  }

  cleanGenericPrice(cleaned) {
    // General cleanup
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    
    // Extract price pattern (number with currency)
    const priceMatch = cleaned.match(/(\d+[.,]\d{2}\s*[€$¥£]|\d+\s*[€$¥£])/);
    if (priceMatch) {
      return priceMatch[1];
    }

    // Fallback: remove non-price characters
    return cleaned.replace(/[^\d.,€$¥£\s]/g, '').trim();
  }

  convertCurrencyMatch(text, regex, fromCurrency) {
    const match = text.match(regex);
    if (match) {
      const value = parseFloat(match[1].replace(',', '.'));
      const euroValue = this.convertToEUR(value, fromCurrency);
      return `€${euroValue.toFixed(2)}`;
    }
    return null;
  }

  // Add other site-specific cleaning methods as needed...
  cleanMatchaKaruPrice(cleaned) {
    // Handle German price formatting: "AngebotspreisAb 19,00 €"
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    cleaned = cleaned.replace(/Angebotspreis/g, '');
    cleaned = cleaned.replace(/Ab /g, '');
    cleaned = cleaned.replace(/ab /g, '');
    
    const matchaKaruMatch = cleaned.match(/(\d+,\d{2}\s*€)/);
    if (matchaKaruMatch) {
      return matchaKaruMatch[1];
    }
    return '';
  }

  cleanYoshienPrice(cleaned) {
    // Handle multi-currency strings like "¥2,000$13.57€11.66£10.04¥97.06"
    const yoshienEurMatch = cleaned.match(/€(\d+[.,]\d*)/);
    if (yoshienEurMatch) {
      const priceText = yoshienEurMatch[1].replace(',', '.');
      return `€${priceText}`;
    }
    
    // If no EUR found, try extracting the first Yen price and convert
    const yoshienYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})*)/);
    if (yoshienYenMatch) {
      const jpyValue = parseFloat(yoshienYenMatch[1].replace(/,/g, ''));
      const euroValue = this.convertToEUR(jpyValue, 'JPY');
      return `€${euroValue.toFixed(2)}`;
    }
    
    // Fallback: clean up and extract any price
    cleaned = cleaned.replace('Ab ', '').trim();
    const yoshienFallbackMatch = cleaned.match(/(\d+[.,]\d+)\s*€/);
    if (yoshienFallbackMatch) {
      return yoshienFallbackMatch[1] + ' €';
    }
    return '';
  }

  cleanSazenteaPrice(cleaned) {
    // Extract USD price and convert
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    const sazenMatch = cleaned.match(/\$(\d+\.\d+)/);
    if (sazenMatch) {
      const usdValue = parseFloat(sazenMatch[1]);
      const euroValue = this.convertToEUR(usdValue, 'USD');
      return `€${euroValue.toFixed(2)}`;
    }
    return '';
  }

  cleanEnjoyemeriPrice(cleaned) {
    // Basic EUR handling for Enjoyemeri
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    const enjoyEmeriMatch = cleaned.match(/€(\d+[.,]\d*)/);
    if (enjoyEmeriMatch) {
      const priceText = enjoyEmeriMatch[1].replace(',', '.');
      return `€${priceText}`;
    }
    return '';
  }
}

module.exports = PriceUtils;
