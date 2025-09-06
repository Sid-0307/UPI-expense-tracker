import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:upi_expense_tracker/screens/home_screen.dart';

class AppTheme {
  AppTheme._();
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static void toggle() {
    final current = mode.value;
    if (current == ThemeMode.light) {
      mode.value = ThemeMode.dark;
    } else if (current == ThemeMode.dark) {
      mode.value = ThemeMode.light;
    } else {
      mode.value = ThemeMode.dark;
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  ThemeData _lightTheme() {
    // Light theme with specified purple
    const primary = Color(0xFF5026A3); // Your specified purple
    const surface = Color(0xFFFFFFFF); // Pure white
    const background = Color(0xFFFFFFFF); // Pure white
    const onPrimary = Color(0xFFFFFFFF);
    const onSurface = Color(0xFF000000); // Black text
    const onBackground = Color(0xFF000000); // Black text
    
    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      surface: surface,
      onSurface: onSurface,
      background: background,
      onBackground: onBackground,
      surfaceVariant: const Color(0xFFD3D1D1),
      onSurfaceVariant: const Color(0xFF333333),
      outline: const Color(0xFFCCCCCC),
      outlineVariant: const Color(0xFFE0E0E0),
    );
    
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ThemeData _darkTheme() {
    // Dark theme with specified colors
    const primary = Color(0xFF7553BA); // Your specified purple
    const surface = Color(0xFF180229); // Your specified dark background
    const background = Color(0xFF180229); // Your specified dark background
    const onPrimary = Color(0xFFFFFFFF);
    const onSurface = Color(0xFFFFFFFF); // White text
    const onBackground = Color(0xFFFFFFFF); // White text
    
    final scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      surface: surface,
      onSurface: onSurface,
      background: background,
      onBackground: onBackground,
      surfaceVariant: const Color(0xFF2A1A3A),
      onSurfaceVariant: const Color(0xFFE0E0E0),
      outline: const Color(0xFF5A4A6A),
      outlineVariant: const Color(0xFF3A2A4A),
    );
    
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'UPI Expense Reader',
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: mode,
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}