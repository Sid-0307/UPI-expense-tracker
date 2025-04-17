import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Expense Reader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bank Selector Dropdown
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DropdownButton<String>(
                  value: selectedBank,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedBank = newValue!;
                    });
                  },
                  items: banks.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Read Transactions Button
            ElevatedButton(
              onPressed: isLoading ? null : _readTransactions,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isLoading ? 'Loading...' : 'Read My Transactions',
                style: const TextStyle(fontSize: 16),
              ),
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

            // App description
            if (!isLoading)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sms_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'This app reads your SMS messages to analyze UPI transactions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button above to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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