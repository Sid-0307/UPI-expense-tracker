import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class MerchantStore extends ChangeNotifier {
  MerchantStore._internal();

  static final MerchantStore instance = MerchantStore._internal();

  late Map<String, SpendCategory> _merchantToCategory;
  static const String _storageKey = 'merchant_mappings';
  bool _isInitialized = false;

  Map<String, SpendCategory> get mappings => Map.unmodifiable(_merchantToCategory);

  /// Initialize the store with saved data or defaults
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_storageKey);

      if (savedData != null) {
        // Load saved mappings
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        _merchantToCategory = {};

        decoded.forEach((key, value) {
          // Convert string back to SpendCategory enum
          final category = SpendCategory.values.firstWhere(
                (cat) => cat.toString() == value,
            orElse: () => SpendCategory.others,
          );
          _merchantToCategory[key] = category;
        });
      } else {
        // Initialize with defaults if no saved data
        _initializeDefaults();
      }
    } catch (e) {
      // If there's any error loading, fall back to defaults
      debugPrint('Error loading merchant mappings: $e');
      _initializeDefaults();
    }

    _isInitialized = true;
  }

  /// Initialize with default mappings
  void _initializeDefaults() {
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

  /// Save current mappings to SharedPreferences
  Future<void> _saveMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert SpendCategory enums to strings for JSON serialization
      final Map<String, String> toSave = {};
      _merchantToCategory.forEach((key, value) {
        toSave[key] = value.toString();
      });

      final encoded = jsonEncode(toSave);
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving merchant mappings: $e');
    }
  }

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

  Future<void> upsertMapping(String merchant, SpendCategory category) async {
    final key = _normalize(merchant);
    if (key.isEmpty) return;

    _merchantToCategory[key] = category;
    await _saveMappings();
    notifyListeners();
  }

  Future<void> removeMapping(String merchant) async {
    final key = _normalize(merchant);
    _merchantToCategory.remove(key);
    await _saveMappings();
    notifyListeners();
  }

  /// Reset to default mappings (useful for debugging or user preference)
  Future<void> resetToDefaults() async {
    _initializeDefaults();
    await _saveMappings();
    notifyListeners();
  }

  /// Clear all mappings
  Future<void> clearAllMappings() async {
    _merchantToCategory.clear();
    await _saveMappings();
    notifyListeners();
  }
}
