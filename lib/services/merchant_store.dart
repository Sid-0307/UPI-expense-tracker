import 'package:flutter/foundation.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class MerchantStore extends ChangeNotifier {
  MerchantStore._internal() {
    // Defaults
    _merchantToCategory = {
      'swiggy': SpendCategory.food,
      'zomato': SpendCategory.food,
      'dominos': SpendCategory.food,
      'pizza hut': SpendCategory.food,
      'kfc': SpendCategory.food,
      'mcdonalds': SpendCategory.food,
      'amazon': SpendCategory.shopping,
      'flipkart': SpendCategory.shopping,
      'myntra': SpendCategory.shopping,
      'ajio': SpendCategory.shopping,
      'bigbasket': SpendCategory.groceries,
      'blinkit': SpendCategory.groceries,
      'zepto': SpendCategory.groceries,
      'dmart': SpendCategory.groceries,
      'kirana': SpendCategory.groceries,
      'sangeetha': SpendCategory.food,
    };
  }

  static final MerchantStore instance = MerchantStore._internal();

  late Map<String, SpendCategory> _merchantToCategory;

  Map<String, SpendCategory> get mappings => Map.unmodifiable(_merchantToCategory);

  String _normalize(String merchant) => merchant.trim().toLowerCase();

  SpendCategory? lookupCategoryForMerchant(String merchant) {
    final key = _normalize(merchant);
    // Exact match first
    final exact = _merchantToCategory[key];
    if (exact != null) return exact;
    // Fuzzy/substring match: allow mapping keys to act like keywords
    // e.g., mapping 'bikanervala' will match 'Bikanervala - Indiranagar'
    for (final entry in _merchantToCategory.entries) {
      final mappedKey = entry.key;
      if (key.contains(mappedKey)) {
        return entry.value;
      }
    }
    return null;
  }

  void upsertMapping(String merchant, SpendCategory category) {
    final key = _normalize(merchant);
    if (key.isEmpty) return;
    _merchantToCategory[key] = category;
    notifyListeners();
  }

  void removeMapping(String merchant) {
    final key = _normalize(merchant);
    _merchantToCategory.remove(key);
    notifyListeners();
  }
}


