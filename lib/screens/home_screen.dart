import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upi_expense_tracker/main.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/screens/transaction_summary_screen.dart';
import 'package:upi_expense_tracker/services/permission_service.dart';
import 'package:upi_expense_tracker/services/sms_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedBank = 'Axis Bank';
  List<Map<String, String>> banks = [
    {"name": "Axis Bank", "logo": "assets/banks/axis.jpg"},
    {"name": "HDFC Bank", "logo": "assets/banks/hdfc.png"},
    {"name": "SBI Bank", "logo": "assets/banks/sbi.jpg"},
    {"name": "ICICI Bank", "logo": "assets/banks/icici.jpg"},
    {"name": "Kotak Bank", "logo": "assets/banks/kotak.png"},
    {"name": "Citi Union Bank", "logo": "assets/banks/cub.png"},
    {"name": "Canara Bank","logo":"assets/banks/canara.png"}
  ];
  bool isLoading = false;
  bool isInitializing = true;
  bool hasAutoNavigated = false; // Track if we've already auto-navigated

  final PermissionService _permissionService = PermissionService();
  final SmsService _smsService = SmsService();
  static const String _bankPrefsKey = 'selected_bank';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize app and check for stored bank preference
  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedBank = prefs.getString(_bankPrefsKey);

      if (storedBank != null && mounted) {
        // Bank is stored, set it as selected
        setState(() {
          selectedBank = storedBank;
          isInitializing = false;
        });

        // Auto-navigate only if this is the first initialization
        // and we haven't auto-navigated before in this session
        if (!hasAutoNavigated) {
          hasAutoNavigated = true;

          // Small delay to show the selected bank briefly
          // await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            // Check permissions and auto-navigate
            final hasPermission = await _permissionService.requestSmsPermission();

            if (hasPermission && mounted) {
              await _autoNavigateToTransactions();
            } else if (mounted) {
              _showPermissionDialog();
            }
          }
        }
      } else {
        // No bank stored, show normal home screen
        setState(() {
          isInitializing = false;
        });
      }
    } catch (e) {
      // Handle error gracefully
      if (mounted) {
        setState(() {
          isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preferences: $e')),
        );
      }
    }
  }

  /// Auto-navigate to transactions (only on first init)
  Future<void> _autoNavigateToTransactions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final List<Transaction> transactions = await _smsService.readTransactions(selectedBank);

      if (mounted) {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionSummaryScreen(
              transactions: transactions,
              // onBankChange: _handleBankChange,
            ),
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            isLoading = false;
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading SMS: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Store selected bank in preferences
  Future<void> _storeBankPreference(String bankName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bankPrefsKey, bankName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bank preference: $e')),
        );
      }
    }
  }

  /// Clear stored bank preference
  Future<void> _clearBankPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bankPrefsKey);
      hasAutoNavigated = false; // Reset auto-navigation flag
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing bank preference: $e')),
        );
      }
    }
  }

  /// Handle bank change request from transaction screen
  void _handleBankChange() {
    _clearBankPreference();
    setState(() {
      selectedBank = banks.first['name']!;
    });
  }

  /// Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text(
            'This app needs SMS permission to read your transaction messages. Please grant permission to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearBankPreference(); // Reset bank selection
                setState(() {
                  selectedBank = banks.first['name']!;
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final hasPermission = await _permissionService.requestSmsPermission();
                if (hasPermission && mounted) {
                  await _autoNavigateToTransactions();
                }
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;

    // Responsive padding and sizing
    final horizontalPadding = screenWidth * 0.08; // 8% of screen width
    final verticalPadding = isSmallScreen ? 16.0 : screenHeight * 0.05; // 5% of screen height or minimum
    final titleFontSize = isVerySmallScreen ? 28.0 : (isSmallScreen ? 32.0 : 55.0);
    final cardRadius = screenWidth * 0.04; // 4% of screen width

    // Show loading screen during initialization or auto-navigation
    if (isInitializing || (hasAutoNavigated && isLoading)) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isInitializing && !isLoading
                    ? 'Initializing...'
                    : 'Loading transactions...',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              if (selectedBank.isNotEmpty && (hasAutoNavigated || isLoading)) ...[
                const SizedBox(height: 8),
                Text(
                  'Bank: $selectedBank',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Subtle purple gradient background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: horizontalPadding,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: isSmallScreen ? 16 : 32),

                            // App Title with responsive sizing
                            Align(
                              alignment: Alignment.center,
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'X',
                                      style: TextStyle(
                                        fontFamily: 'BagelFatOne',
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'pense',
                                      style: TextStyle(
                                        fontFamily: 'CherryBombOne',
                                        fontWeight: FontWeight.w100,
                                        color: Theme.of(context).colorScheme.onBackground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              'Your money\'s mirror',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: isSmallScreen ? 14 : null,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 24 : 32),

                            // Bank Selector Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Select your bank',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedBank,
                                  isExpanded: true, // Prevents overflow
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.03,
                                      vertical: 14,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: scheme.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: scheme.primary, width: 2),
                                    ),
                                  ),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedBank = newValue!;
                                    });
                                  },
                                  items: banks.map((bank) {
                                    return DropdownMenuItem<String>(
                                      value: bank["name"],
                                      child: Row(
                                        children: [
                                          Image.asset(
                                            bank["logo"]!,
                                            width: 24,
                                            height: 24,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.account_balance,
                                                size: 24,
                                                color: scheme.onSurfaceVariant,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              bank["name"]!,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),

                            SizedBox(height: isSmallScreen ? 16 : 24),

                            // Read Transactions Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _readTransactions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 14 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                child: isLoading
                                    ? SizedBox(
                                  width: isSmallScreen ? 20 : 24,
                                  height: isSmallScreen ? 20 : 24,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text(
                                  'Read My Transactions',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // App description with flexible expansion
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.9,
                                  ),
                                  child: Card(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(cardRadius),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.05,
                                        vertical: isSmallScreen ? 16 : 24,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: isSmallScreen ? 32 : 40,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withOpacity(0.12),
                                            child: Icon(
                                              Icons.sms_outlined,
                                              size: isSmallScreen ? 28 : 36,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                          SizedBox(height: isSmallScreen ? 12 : 16),
                                          Text(
                                            'This app reads your SMS messages to analyze UPI transactions.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 14 : 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap the button above to get started.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 12 : 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: screenWidth * 0.04,
              top: screenHeight * 0.02,
              child: _ThemeFab(),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if bank preference exists
  Future<bool> _hasBankPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_bankPrefsKey) != null;
    } catch (e) {
      return false;
    }
  }

  /// Manual read transactions (when user clicks the button)
  Future<void> _readTransactions() async {
    // Store the selected bank
    await _storeBankPreference(selectedBank);

    // Request SMS permission
    final hasPermission = await _permissionService.requestSmsPermission();

    if (hasPermission) {
      setState(() {
        isLoading = true;
      });

      try {
        // Read and parse SMS
        final List<Transaction> transactions = await _smsService.readTransactions(selectedBank);

        if (mounted) {

          // Navigate to transaction summary screen (use push, not pushReplacement for manual navigation)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionSummaryScreen(
                transactions: transactions,
                // onBankChange: _handleBankChange,
              ),
            ),
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() {
              isLoading = false;
            });
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading SMS: $e')),
          );
          setState(() {
            isLoading = false;
          });
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission is required')),
      );
    }
  }
}

class _ThemeFab extends StatefulWidget {
  @override
  State<_ThemeFab> createState() => _ThemeFabState();
}

class _ThemeFabState extends State<_ThemeFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

    // Check the actual resolved theme mode
    final currentMode = AppTheme.mode.value;
    final isDark = currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    if (isDark) {
      _controller.value = 1;
    }
    AppTheme.mode.addListener(_sync);
  }

  void _sync() {
    final currentMode = AppTheme.mode.value;
    final isDark = currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    if (isDark) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    AppTheme.mode.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = AppTheme.mode.value;
    final isDark = currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    return GestureDetector(
      onTap: () {
        AppTheme.mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
      },
      child: _ThemeToggle(
        isDark: isDark,
        progress: _controller,
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final Animation<double> progress;
  final bool isDark;
  const _ThemeToggle({Key? key, required this.progress, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    // Responsive sizing for theme toggle
    final toggleWidth = isSmallScreen ? 70.0 : 80.0;
    final toggleHeight = isSmallScreen ? 35.0 : 40.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;

    return Container(
      width: toggleWidth,
      height: toggleHeight,
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(toggleHeight / 2),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Container(
                width: toggleHeight - 6,
                height: toggleHeight - 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular((toggleHeight - 6) / 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FadeTransition(
                      opacity: Tween<double>(begin: 1, end: 0).animate(
                        CurvedAnimation(parent: progress, curve: Curves.easeInOut),
                      ),
                      child: Icon(Icons.wb_sunny, size: iconSize, color: Colors.white),
                    ),
                    FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(parent: progress, curve: Curves.easeInOut),
                      ),
                      child: Icon(Icons.nights_stay, size: iconSize, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}