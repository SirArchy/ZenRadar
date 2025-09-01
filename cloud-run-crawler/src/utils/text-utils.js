/**
 * Text processing utilities for cleaning and extracting data from scraped content
 */
class TextUtils {
  /**
   * Clean and normalize text content
   */
  static cleanText(text) {
    if (!text) return '';
    
    return text
      .replace(/\n+/g, ' ')           // Replace newlines with spaces
      .replace(/\s+/g, ' ')           // Normalize whitespace
      .replace(/\u00A0/g, ' ')        // Replace non-breaking spaces
      .trim();                        // Remove leading/trailing whitespace
  }

  /**
   * Extract text content from HTML elements, handling nested structures
   */
  static extractTextContent($, element) {
    if (!element || !$(element).length) return '';
    
    // Remove script and style tags first
    $(element).find('script, style').remove();
    
    // Get text content
    const text = $(element).text();
    return this.cleanText(text);
  }

  /**
   * Remove common e-commerce noise words from product titles
   */
  static cleanProductTitle(title) {
    if (!title) return '';
    
    const cleaned = this.cleanText(title);
    
    // Remove common noise patterns
    const noisePatterns = [
      /\s*-\s*Sold\s*Out\s*$/i,
      /\s*-\s*Out\s*of\s*Stock\s*$/i,
      /\s*\|\s*.*$/,                  // Remove everything after pipe
      /\s*\/\s*.*$/,                  // Remove everything after slash (sometimes used for categories)
      /^\s*NEW\s*[:\-]?\s*/i,         // Remove leading NEW:
      /^\s*SALE\s*[:\-]?\s*/i,        // Remove leading SALE:
      /\s*\[\s*.*\s*\]\s*$/,          // Remove bracketed content at end
    ];
    
    let result = cleaned;
    noisePatterns.forEach(pattern => {
      result = result.replace(pattern, '');
    });
    
    return this.cleanText(result);
  }

  /**
   * Extract stock status from text
   */
  static extractStockStatus(text) {
    if (!text) return 'unknown';
    
    const cleanedText = this.cleanText(text).toLowerCase();
    
    // Out of stock indicators
    const outOfStockPatterns = [
      /sold\s*out/,
      /out\s*of\s*stock/,
      /not\s*available/,
      /unavailable/,
      /discontinued/,
      /temporarily\s*unavailable/,
      /currently\s*unavailable/,
      /ausverkauft/,           // German
      /nicht\s*verfügbar/,     // German
      /slut\s*i\s*lager/,      // Swedish
      /slutsåld/,              // Swedish
      /在庫切れ/,                // Japanese
      /完売/,                   // Japanese
    ];
    
    for (const pattern of outOfStockPatterns) {
      if (pattern.test(cleanedText)) {
        return 'out_of_stock';
      }
    }
    
    // In stock indicators
    const inStockPatterns = [
      /in\s*stock/,
      /available/,
      /add\s*to\s*cart/,
      /buy\s*now/,
      /purchase/,
      /verfügbar/,             // German
      /in\s*den\s*warenkorb/,  // German
      /i\s*lager/,             // Swedish
      /köp\s*nu/,              // Swedish
      /在庫あり/,               // Japanese
      /購入/,                   // Japanese
    ];
    
    for (const pattern of inStockPatterns) {
      if (pattern.test(cleanedText)) {
        return 'in_stock';
      }
    }
    
    return 'unknown';
  }

  /**
   * Extract numeric values from text (weights, quantities, etc.)
   */
  static extractNumericValue(text, unit = null) {
    if (!text) return null;
    
    const cleanedText = this.cleanText(text);
    
    if (unit) {
      // Look for number followed by specific unit
      const pattern = new RegExp(`(\\d+(?:[.,]\\d+)?)\\s*${unit}`, 'i');
      const match = cleanedText.match(pattern);
      if (match) {
        return parseFloat(match[1].replace(',', '.'));
      }
    }
    
    // Extract first number found
    const numberMatch = cleanedText.match(/(\d+(?:[.,]\d+)?)/);
    if (numberMatch) {
      return parseFloat(numberMatch[1].replace(',', '.'));
    }
    
    return null;
  }

  /**
   * Extract weight from product text
   */
  static extractWeight(text) {
    if (!text) return null;
    
    const cleanedText = this.cleanText(text);
    
    // Weight patterns with units
    const weightPatterns = [
      /(\d+(?:[.,]\d+)?)\s*g\b/i,      // grams
      /(\d+(?:[.,]\d+)?)\s*gr\b/i,     // grams (alternative)
      /(\d+(?:[.,]\d+)?)\s*gram/i,     // grams (full word)
      /(\d+(?:[.,]\d+)?)\s*kg\b/i,     // kilograms
      /(\d+(?:[.,]\d+)?)\s*oz\b/i,     // ounces
      /(\d+(?:[.,]\d+)?)\s*lb\b/i,     // pounds
    ];
    
    for (const pattern of weightPatterns) {
      const match = cleanedText.match(pattern);
      if (match) {
        return {
          value: parseFloat(match[1].replace(',', '.')),
          unit: match[0].replace(match[1], '').trim().toLowerCase()
        };
      }
    }
    
    return null;
  }

  /**
   * Detect language from text content
   */
  static detectLanguage(text) {
    if (!text) return 'unknown';
    
    const cleanedText = this.cleanText(text).toLowerCase();
    
    // Japanese patterns
    const japanesePatterns = [
      /[\u3040-\u309F]/,  // Hiragana
      /[\u30A0-\u30FF]/,  // Katakana
      /[\u4E00-\u9FAF]/   // Kanji
    ];
    
    for (const pattern of japanesePatterns) {
      if (pattern.test(cleanedText)) {
        return 'japanese';
      }
    }
    
    // German patterns
    const germanWords = ['und', 'der', 'die', 'das', 'mit', 'von', 'zu', 'auf', 'für', 'ein', 'eine', 'einen'];
    const germanPattern = new RegExp(`\\b(${germanWords.join('|')})\\b`, 'i');
    if (germanPattern.test(cleanedText)) {
      return 'german';
    }
    
    // Swedish patterns
    const swedishWords = ['och', 'för', 'från', 'med', 'till', 'av', 'på', 'i', 'som', 'att'];
    const swedishPattern = new RegExp(`\\b(${swedishWords.join('|')})\\b`, 'i');
    if (swedishPattern.test(cleanedText)) {
      return 'swedish';
    }
    
    // English (default for most sites)
    return 'english';
  }

  /**
   * Extract category information from text
   */
  static extractCategory(text, breadcrumbs = null) {
    if (!text && !breadcrumbs) return null;
    
    const allText = [text, breadcrumbs].filter(Boolean).join(' ');
    const cleanedText = this.cleanText(allText).toLowerCase();
    
    // Matcha-related categories
    const categoryPatterns = [
      { pattern: /ceremonial\s*grade/i, category: 'Ceremonial Grade' },
      { pattern: /premium\s*grade/i, category: 'Premium Grade' },
      { pattern: /culinary\s*grade/i, category: 'Culinary Grade' },
      { pattern: /cooking\s*grade/i, category: 'Culinary Grade' },
      { pattern: /organic/i, category: 'Organic' },
      { pattern: /stone\s*ground/i, category: 'Stone Ground' },
      { pattern: /traditional/i, category: 'Traditional' },
    ];
    
    for (const { pattern, category } of categoryPatterns) {
      if (pattern.test(cleanedText)) {
        return category;
      }
    }
    
    return null;
  }

  /**
   * Normalize product variants text
   */
  static normalizeVariantText(text) {
    if (!text) return '';
    
    let normalized = this.cleanText(text);
    
    // Common variant normalizations
    const normalizations = [
      { from: /(\d+)\s*g\s*dose/gi, to: '$1g Dose' },
      { from: /(\d+)\s*g\s*nachfüllbeutel/gi, to: '$1g Nachfüllbeutel' },
      { from: /(\d+)\s*portionen/gi, to: '$1 Portionen' },
      { from: /(\d+)\s*x\s*(\d+)\s*g/gi, to: '$1 x $2g' },
    ];
    
    normalizations.forEach(({ from, to }) => {
      normalized = normalized.replace(from, to);
    });
    
    return normalized;
  }

  /**
   * Extract rating from text
   */
  static extractRating(text) {
    if (!text) return null;
    
    const cleanedText = this.cleanText(text);
    
    // Rating patterns
    const ratingPatterns = [
      /(\d+(?:\.\d+)?)\s*\/\s*5/,       // 4.5/5
      /(\d+(?:\.\d+)?)\s*out\s*of\s*5/i, // 4.5 out of 5
      /(\d+(?:\.\d+)?)\s*stars?/i,      // 4.5 stars
      /rating[:\s]*(\d+(?:\.\d+)?)/i,   // Rating: 4.5
    ];
    
    for (const pattern of ratingPatterns) {
      const match = cleanedText.match(pattern);
      if (match) {
        const rating = parseFloat(match[1]);
        if (rating >= 0 && rating <= 5) {
          return rating;
        }
      }
    }
    
    return null;
  }

  /**
   * Remove HTML tags and decode entities
   */
  static stripHtml(html) {
    if (!html) return '';
    
    // Remove HTML tags
    let text = html.replace(/<[^>]*>/g, ' ');
    
    // Decode common HTML entities
    const entities = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
      '&euro;': '€',
      '&yen;': '¥',
      '&pound;': '£',
      '&copy;': '©',
      '&reg;': '®',
    };
    
    Object.entries(entities).forEach(([entity, char]) => {
      text = text.replace(new RegExp(entity, 'g'), char);
    });
    
    return this.cleanText(text);
  }
}

module.exports = TextUtils;
