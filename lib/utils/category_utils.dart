import 'package:flutter/material.dart';
import 'package:upi_expense_tracker/services/merchant_store.dart';

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
  final SpendCategory category;
  final String name;
  final Color color;
  final IconData icon;

  const CategoryInfo({
    required this.category,
    required this.name,
    required this.color,
    required this.icon,
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
    color: Color(0xFFFFCA28),
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
  // Note: 'others' now uses a placeholder color - use getCategoryColor() for theme-aware color
  SpendCategory.others: CategoryInfo(
    category: SpendCategory.others,
    name: 'Others',
    color: Color(0xFFBDBDBD), // Fallback color
    icon: Icons.more_horiz,
  ),
};

// Lowercase substring patterns → category. Order matters; first match wins.
final List<MapEntry<List<String>, SpendCategory>> _merchantPatterns = [
  // Food delivery & restaurants
  MapEntry(['swiggy', 'zomato', 'eat', 'restaurant', 'domino', 'pizza', 'kfc', 'mcdonald', 'burger king'], SpendCategory.food),
  // Groceries & quick commerce
  MapEntry(['blinkit', 'zepto', 'bb', 'bigbasket', 'dunzo', 'grocer', 'more supermarket', 'dmart'], SpendCategory.groceries),
  // Shopping & e-commerce
  MapEntry(['amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'tatacliq', 'meesho', 'croma', 'reliance digital', 'ikea'], SpendCategory.shopping),
  // Bills & utilities
  MapEntry(['electric', 'gas', 'water', 'internet', 'broadband', 'recharge', 'dth', 'postpaid', 'prepaid', 'billdesk'], SpendCategory.bills),
  MapEntry(['biller', 'eb bill', 'power', 'bsnl', 'jio', 'airtel'], SpendCategory.utilities),
  // Transport & mobility
  MapEntry(['uber', 'ola', 'rapido', 'bounce', 'meru', 'metro'], SpendCategory.transport),
  // Travel
  MapEntry(['irctc', 'makemytrip', 'mmt', 'yatra', 'ixigo', 'cleartrip', 'goibibo', 'air india', 'indigo', 'vistara'], SpendCategory.travel),
  // Entertainment
  MapEntry(['netflix', 'prime video', 'hotstar', 'disney', 'spotify', 'wynk', 'sonyliv', 'gaana', 'bookmyshow', 'bms'], SpendCategory.entertainment),
  // Health
  MapEntry(['pharm', 'apollo', '1mg', 'tata 1mg', 'practo', 'clinic', 'hospital', 'medlife'], SpendCategory.health),
  // Education
  MapEntry(['udemy', 'coursera', 'byju', 'unacademy', 'skillshare', 'edx'], SpendCategory.education),
];

SpendCategory getCategoryForMerchant(String merchant) {
  // Check user-defined or default merchant mappings first
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

String getCategoryName(SpendCategory category) => kCategoryInfo[category]!.name;

// Updated function to handle theme-aware color for 'others' category
Color getCategoryColor(SpendCategory category, {ColorScheme? colorScheme}) {
  if (category == SpendCategory.others && colorScheme != null) {
    // Return theme-appropriate color for 'others'
    return colorScheme.onSurface;
  }
  return kCategoryInfo[category]!.color;
}

IconData getCategoryIcon(SpendCategory category) => kCategoryInfo[category]!.icon;

// Helper function to get all categories in a specific order
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