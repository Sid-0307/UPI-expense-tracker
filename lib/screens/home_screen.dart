import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<String> banks = ['Axis Bank', 'HDFC Bank', 'SBI', 'ICICI Bank'];
  bool isLoading = false;

  final PermissionService _permissionService = PermissionService();
  final SmsService _smsService = SmsService();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              padding: const EdgeInsets.symmetric(vertical: 64.0,horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  Align(
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text: 'X',
                        style: GoogleFonts.bagelFatOne(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: 'pense',
                        style: GoogleFonts.cherryBombOne(
                          fontWeight: FontWeight.w100// or Theme.of(context).colorScheme.onBackground
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your money’s mirror',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              // Bank Selector Dropdown (polished)
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
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                items: banks.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Read Transactions Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _readTransactions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_stories, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isLoading ? 'Loading...' : 'Read My Transactions',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Loading Indicator
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 32.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Reading and analyzing SMS messages...'),
                      ],
                    ),
                  ),
                ),

              // App description (stronger contrast)
              if (!isLoading)
                Expanded(
                  child: Center(
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.12),
                              child: Icon(
                                Icons.sms_outlined,
                                size: 36,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This app reads your SMS messages to analyze UPI transactions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button above to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
            Positioned(
              right: 16,
              top: 16,
              child: _ThemeFab(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _readTransactions() async {
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
          setState(() {
            isLoading = false;
          });

          // Navigate to transaction summary screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionSummaryScreen(transactions: transactions),
            ),
          );
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
    if (AppTheme.mode.value == ThemeMode.dark) {
      _controller.value = 1;
    }
    AppTheme.mode.addListener(_sync);
  }

  void _sync() {
    final isDark = AppTheme.mode.value == ThemeMode.dark;
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
    final isDark = AppTheme.mode.value == ThemeMode.dark;
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
    return Container(
      width: 80,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FadeTransition(
                      opacity: Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: progress, curve: Curves.easeInOut)),
                      child: const Icon(Icons.wb_sunny, size: 24, color: Colors.white),
                    ),
                    FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: progress, curve: Curves.easeInOut)),
                      child: const Icon(Icons.nights_stay, size: 24, color: Colors.white),
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