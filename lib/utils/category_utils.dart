// Updated lib/utils/category_utils.dart

import 'package:flutter/material.dart';
import 'package:upi_expense_tracker/services/merchant_store.dart';
import '../services/custom_category.dart';

enum SpendCategory {
  food,
  groceries,
  shopping,
  bills,
  transport,
  travel,
  entertainment,
  health,
  education,
  utilities,
  others,
}

class CategoryInfo {
  final SpendCategory? category;
  final String? customId;
  final String name;
  final Color color;
  final IconData icon;
  final bool isCustom;

  const CategoryInfo({
    this.category,
    this.customId,
    required this.name,
    required this.color,
    required this.icon,
    this.isCustom = false,
  });
}

const Map<SpendCategory, CategoryInfo> kCategoryInfo = {
  SpendCategory.food: CategoryInfo(
    category: SpendCategory.food,
    name: 'Food',
    color: Color(0xFFFF7043),
    icon: Icons.restaurant,
  ),
  SpendCategory.groceries: CategoryInfo(
    category: SpendCategory.groceries,
    name: 'Groceries',
    color: Color(0xFF66BB6A),
    icon: Icons.local_grocery_store,
  ),
  SpendCategory.shopping: CategoryInfo(
    category: SpendCategory.shopping,
    name: 'Shopping',
    color: Color(0xFFAB47BC),
    icon: Icons.shopping_bag,
  ),
  SpendCategory.bills: CategoryInfo(
    category: SpendCategory.bills,
    name: 'Bills',
    color: Color(0xFF42A5F5),
    icon: Icons.receipt_long,
  ),
  SpendCategory.transport: CategoryInfo(
    category: SpendCategory.transport,
    name: 'Transport',
    color: Color(0xFF26C6DA),
    icon: Icons.directions_bus,
  ),
  SpendCategory.travel: CategoryInfo(
    category: SpendCategory.travel,
    name: 'Travel',
    color: Color(0xFF7E57C2),
    icon: Icons.flight,
  ),
  SpendCategory.entertainment: CategoryInfo(
    category: SpendCategory.entertainment,
    name: 'Entertainment',
    color: Color(0xFFFF9A28),
    icon: Icons.movie,
  ),
  SpendCategory.health: CategoryInfo(
    category: SpendCategory.health,
    name: 'Health',
    color: Color(0xFFEF5350),
    icon: Icons.healing,
  ),
  SpendCategory.education: CategoryInfo(
    category: SpendCategory.education,
    name: 'Education',
    color: Color(0xFF8D6E63),
    icon: Icons.school,
  ),
  SpendCategory.utilities: CategoryInfo(
    category: SpendCategory.utilities,
    name: 'Utilities',
    color: Color(0xFF009688),
    icon: Icons.lightbulb,
  ),
  SpendCategory.others: CategoryInfo(
    category: SpendCategory.others,
    name: 'Others',
    color: Color(0xFFBDBDBD),
    icon: Icons.more_horiz,
  ),
};

// Lowercase substring patterns → category. Order matters; first match wins.
final List<MapEntry<List<String>, SpendCategory>> _merchantPatterns = [
  MapEntry(['swiggy', 'zomato', 'eat', 'restaurant', 'domino', 'pizza', 'kfc', 'mcdonald', 'burger king'], SpendCategory.food),
  MapEntry(['blinkit', 'zepto', 'bb', 'bigbasket', 'dunzo', 'grocer', 'more supermarket', 'dmart'], SpendCategory.groceries),
  MapEntry(['amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'tatacliq', 'meesho', 'croma', 'reliance digital', 'ikea'], SpendCategory.shopping),
  MapEntry(['electric', 'gas', 'water', 'internet', 'broadband', 'recharge', 'dth', 'postpaid', 'prepaid', 'billdesk'], SpendCategory.bills),
  MapEntry(['biller', 'eb bill', 'power', 'bsnl', 'jio', 'airtel'], SpendCategory.utilities),
  MapEntry(['uber', 'ola', 'rapido', 'bounce', 'meru', 'metro'], SpendCategory.transport),
  MapEntry(['irctc', 'makemytrip', 'mmt', 'yatra', 'ixigo', 'cleartrip', 'goibibo', 'air india', 'indigo', 'vistara'], SpendCategory.travel),
  MapEntry(['netflix', 'prime video', 'hotstar', 'disney', 'spotify', 'wynk', 'sonyliv', 'gaana', 'bookmyshow', 'bms'], SpendCategory.entertainment),
  MapEntry(['pharm', 'apollo', '1mg', 'tata 1mg', 'practo', 'clinic', 'hospital', 'medlife'], SpendCategory.health),
  MapEntry(['udemy', 'coursera', 'byju', 'unacademy', 'skillshare', 'edx'], SpendCategory.education),
];

SpendCategory getCategoryForMerchant(String merchant) {
  final override = MerchantStore.instance.lookupCategoryForMerchant(merchant);
  if (override != null) return override;
  final m = merchant.toLowerCase();
  for (final entry in _merchantPatterns) {
    for (final pattern in entry.key) {
      if (m.contains(pattern)) {
        return entry.value;
      }
    }
  }
  return SpendCategory.others;
}

String getCategoryName(Object category) {
  if (category is CustomCategory) {
    return category.name;
  }
  return kCategoryInfo[category]!.name;
}

Color getCategoryColor(Object category, {ColorScheme? colorScheme}) {
  if (category is CustomCategory) {
    return category.color;
  }
  if (category == SpendCategory.others && colorScheme != null) {
    return colorScheme.onSurface;
  }
  return kCategoryInfo[category]!.color;
}

IconData getCategoryIcon(Object category) {
  if (category is CustomCategory) {
    return category.icon;
  }
  return kCategoryInfo[category]!.icon;
}

// Unified display helpers for merchants (resolve to custom if present)
bool hasCustomCategoryForMerchant(String merchant) {
  return MerchantStore.instance.lookupCustomCategoryIdForMerchant(merchant) != null;
}

String getDisplayCategoryNameForMerchant(String merchant) {
  final customId = MerchantStore.instance.lookupCustomCategoryIdForMerchant(merchant);
  if (customId != null) {
    final cc = CustomCategoryStore.instance
        .getAllCustomCategories()
        .firstWhere((c) => c.id == customId, orElse: () => CustomCategory(id: '', name: 'Custom', colorValue: const Color(0xFFBDBDBD).value, iconCodePoint: Icons.category.codePoint));
    return cc.name;
  }
  final def = getCategoryForMerchant(merchant);
  return getCategoryName(def);
}

Color getDisplayCategoryColorForMerchant(String merchant, {ColorScheme? colorScheme}) {
  final customId = MerchantStore.instance.lookupCustomCategoryIdForMerchant(merchant);
  if (customId != null) {
    final cc = CustomCategoryStore.instance
        .getAllCustomCategories()
        .firstWhere((c) => c.id == customId, orElse: () => CustomCategory(id: '', name: 'Custom', colorValue: const Color(0xFFBDBDBD).value, iconCodePoint: Icons.category.codePoint));
    return cc.color;
  }
  final def = getCategoryForMerchant(merchant);
  return getCategoryColor(def, colorScheme: colorScheme);
}

IconData getDisplayCategoryIconForMerchant(String merchant) {
  final customId = MerchantStore.instance.lookupCustomCategoryIdForMerchant(merchant);
  if (customId != null) {
    final cc = CustomCategoryStore.instance
        .getAllCustomCategories()
        .firstWhere((c) => c.id == customId, orElse: () => CustomCategory(id: '', name: 'Custom', colorValue: const Color(0xFFBDBDBD).value, iconCodePoint: Icons.category.codePoint));
    return cc.icon;
  }
  final def = getCategoryForMerchant(merchant);
  return getCategoryIcon(def);
}

// Get all categories (default + custom)
List<CategoryInfo> getAllCategoriesInfo() {
  final defaultCategories = [
    SpendCategory.food,
    SpendCategory.groceries,
    SpendCategory.shopping,
    SpendCategory.bills,
    SpendCategory.transport,
    SpendCategory.travel,
    SpendCategory.entertainment,
    SpendCategory.health,
    SpendCategory.education,
    SpendCategory.utilities,
    SpendCategory.others,
  ].map((cat) => kCategoryInfo[cat]!).toList();

  final customCategories = CustomCategoryStore.instance
      .getAllCustomCategories()
      .map((custom) => (CategoryInfo(
    customId: custom.id,
    name: custom.name,
    color: custom.color,
    icon: custom.icon,
    isCustom: true,
  )))
      .toList();

  return [...defaultCategories, ...customCategories];
}

// For backward compatibility
List<SpendCategory> getAllCategories() {
  return [
    SpendCategory.food,
    SpendCategory.groceries,
    SpendCategory.shopping,
    SpendCategory.bills,
    SpendCategory.transport,
    SpendCategory.travel,
    SpendCategory.entertainment,
    SpendCategory.health,
    SpendCategory.education,
    SpendCategory.utilities,
    SpendCategory.others,
  ];
}