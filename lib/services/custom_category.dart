// Create a new file: lib/services/custom_category_store.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CustomCategory {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;

  CustomCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'iconCodePoint': iconCodePoint,
  };

  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    colorValue: json['colorValue'] as int,
    iconCodePoint: json['iconCodePoint'] as int,
  );

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
}

class CustomCategoryStore {
  static final CustomCategoryStore _instance = CustomCategoryStore._internal();
  static CustomCategoryStore get instance => _instance;

  CustomCategoryStore._internal();

  static const String _storageKey = 'custom_categories';
  List<CustomCategory> _categories = [];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final String? categoriesJson = prefs.getString(_storageKey);

    if (categoriesJson != null) {
      final List<dynamic> decoded = json.decode(categoriesJson);
      _categories = decoded.map((e) => CustomCategory.fromJson(e)).toList();
    }
  }

  List<CustomCategory> getAllCustomCategories() => List.unmodifiable(_categories);

  Future<void> addCategory(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final color = _assignColor(name);
    final icon = _assignIcon(name);

    final newCategory = CustomCategory(
      id: id,
      name: name,
      colorValue: color.value,
      iconCodePoint: icon.codePoint,
    );

    _categories.add(newCategory);
    await _save();
  }

  Future<void> removeCategory(String id) async {
    _categories.removeWhere((cat) => cat.id == id);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = json.encode(_categories.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, categoriesJson);
  }

  Color _assignColor(String name) {
    final colors = [
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue Grey
    ];

    // Use name hash to pick a consistent color
    final hash = name.toLowerCase().codeUnits.fold(0, (prev, curr) => prev + curr);
    return colors[hash % colors.length];
  }

  IconData _assignIcon(String name) {
    final nameLower = name.toLowerCase();

    // Keyword-based icon assignment
    final iconMap = {
      // Finance
      ['investment', 'invest', 'stock', 'mutual', 'fund']: Icons.trending_up,
      ['saving', 'save', 'deposit']: Icons.account_balance,
      ['loan', 'emi', 'debt']: Icons.credit_card,
      ['insurance', 'policy']: Icons.security,

      // Personal
      ['gift', 'present']: Icons.card_giftcard,
      ['pet', 'animal']: Icons.pets,
      ['hobby', 'craft']: Icons.palette,
      ['donation', 'charity']: Icons.volunteer_activism,

      // Home & Family
      ['home', 'house', 'rent', 'mortgage']: Icons.home,
      ['family', 'kid', 'child']: Icons.family_restroom,
      ['furniture', 'appliance']: Icons.weekend,
      ['maintenance', 'repair']: Icons.handyman,

      // Tech & Communication
      ['subscription', 'software', 'app']: Icons.subscriptions,
      ['gadget', 'electronic', 'tech']: Icons.devices,
      ['phone', 'mobile']: Icons.phone_android,

      // Fashion & Beauty
      ['beauty', 'cosmetic', 'makeup']: Icons.face,
      ['fashion', 'cloth', 'apparel']: Icons.checkroom,
      ['jewelry', 'accessory']: Icons.diamond,

      // Sports & Fitness
      ['gym', 'fitness', 'workout']: Icons.fitness_center,
      ['sport', 'game']: Icons.sports,

      // Other
      ['book', 'reading']: Icons.menu_book,
      ['music', 'instrument']: Icons.music_note,
      ['art', 'painting']: Icons.brush,
      ['photo', 'camera']: Icons.photo_camera,
    };

    for (final entry in iconMap.entries) {
      if (entry.key.any((keyword) => nameLower.contains(keyword))) {
        return entry.value;
      }
    }

    // Default icon
    return Icons.category;
  }
}