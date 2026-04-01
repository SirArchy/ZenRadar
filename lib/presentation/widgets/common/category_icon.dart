import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final String? category;
  final double size;
  final Color? color;

  const CategoryIcon({super.key, this.category, this.size = 18, this.color});

  /// Maps category names to their corresponding asset paths
  String? _getCategoryAssetPath(String? category) {
    if (category == null || category.isEmpty) {
      return 'lib/assets/Product_Category_Matcha.png'; // Default to matcha
    }

    final String normalizedCategory = category.toLowerCase().trim();

    switch (normalizedCategory) {
      case 'accessories':
        return 'lib/assets/Product_Category_Accessories.png';
      case 'black tea':
      case 'blacktea':
      case 'black_tea':
        return 'lib/assets/Product_Category_BlackTea.png';
      case 'genmaicha':
        return 'lib/assets/Product_Category_Genmaicha.png';
      case 'hojicha':
        return 'lib/assets/Product_Category_Hojicha.png';
      case 'matcha':
        return 'lib/assets/Product_Category_Matcha.png';
      case 'tea set':
      case 'teaset':
      case 'tea_set':
        return 'lib/assets/Product_Category_TeaSet.png';
      default:
        // For unknown categories, try to detect based on product name patterns
        return _detectCategoryFromName(category) ??
            'lib/assets/Product_Category_Matcha.png';
    }
  }

  /// Attempts to detect category from product name patterns
  String? _detectCategoryFromName(String? productName) {
    if (productName == null) return null;

    final String lower = productName.toLowerCase();

    // Check for accessories first (most specific)
    if (lower.contains('accessory') ||
        lower.contains('tool') ||
        lower.contains('whisk') ||
        lower.contains('bowl') ||
        lower.contains('chawan') ||
        lower.contains('chasen') ||
        lower.contains('chashaku') ||
        lower.contains('halter') ||
        lower.contains('teetasse') ||
        lower.contains('teetassen') ||
        lower.contains('teebecher') ||
        lower.contains('tea pot') ||
        lower.contains('teapot') ||
        lower.contains('pot') ||
        lower.contains('glass') ||
        lower.contains('glas') || // German spelling
        lower.contains('besen') ||
        lower.contains('geschenkgutschein') ||
        lower.contains('gutschein') ||
        lower.contains('schale') ||
        lower.contains('spoon') ||
        lower.contains('löffel') ||
        lower.contains('bamboo') ||
        lower.contains('scoop') ||
        lower.contains('sifter') ||
        lower.contains('strainer')) {
      return 'lib/assets/Product_Category_Accessories.png';
    }

    // Check for tea sets (also specific)
    if (lower.contains('set') ||
        lower.contains('kit') ||
        lower.contains('collection')) {
      return 'lib/assets/Product_Category_TeaSet.png';
    }

    // Other tea types (before matcha)
    if (lower.contains('genmaicha')) {
      return 'lib/assets/Product_Category_Genmaicha.png';
    } else if (lower.contains('hojicha')) {
      return 'lib/assets/Product_Category_Hojicha.png';
    } else if (lower.contains('black tea') ||
        lower.contains('earl grey') ||
        lower.contains('assam') ||
        lower.contains('darjeeling') ||
        lower.contains('ceylon') ||
        lower.contains('english breakfast')) {
      return 'lib/assets/Product_Category_BlackTea.png';
    }

    // Matcha - check last since it's most common
    if (lower.contains('matcha')) {
      return 'lib/assets/Product_Category_Matcha.png';
    }

    return null;
  }

  /// Gets a fallback color if the image fails to load
  Color _getFallbackColor(String? category) {
    if (category == null) return const Color(0xFF9DBE87); // Matcha green

    final String normalizedCategory = category.toLowerCase().trim();

    switch (normalizedCategory) {
      case 'accessories':
        return const Color(0xFF8D6E63); // Brown
      case 'black tea':
      case 'blacktea':
      case 'black_tea':
        return const Color(0xFF3E2723); // Dark brown
      case 'genmaicha':
        return const Color(0xFFFFB74D); // Orange
      case 'hojicha':
        return const Color(0xFFA1887F); // Light brown
      case 'matcha':
        return const Color(0xFF9DBE87); // Matcha green
      case 'tea set':
      case 'teaset':
      case 'tea_set':
        return const Color(0xFF607D8B); // Blue grey
      default:
        return const Color(0xFF9DBE87); // Default matcha green
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _getCategoryAssetPath(category);
    final fallbackColor = color ?? _getFallbackColor(category);

    return SizedBox(
      width: size,
      height: size,
      child:
          assetPath != null
              ? Image.asset(
                assetPath,
                width: size,
                height: size,
                color: color, // Apply color tint if specified
                colorBlendMode: color != null ? BlendMode.srcIn : null,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to colored circle if image fails to load
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Container(
                      decoration: BoxDecoration(
                        color: fallbackColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_cafe,
                        color: Colors.white,
                        size: size * 0.6,
                      ),
                    ),
                  );
                },
              )
              : SizedBox(
                width: size,
                height: size,
                child: Container(
                  decoration: BoxDecoration(
                    color: fallbackColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_cafe,
                    color: Colors.white,
                    size: size * 0.6,
                  ),
                ),
              ),
    );
  }
}
