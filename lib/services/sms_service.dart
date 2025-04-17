import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class SmsService {
  // Read and parse SMS messages to extract transactions
  Future<List<Transaction>> readTransactions(String bankName) async {
    try {
      // Initialize SMS query
      final SmsQuery query = SmsQuery();
      final List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 2000, // Limit to recent messages for performance
      );
      print(messages.length);
      // Parse messages based on bank type
      List<Transaction> parsedTransactions = [];

      for (var message in messages) {
        if (message.body == null) continue;

        Transaction? transaction;

        // Route to appropriate parser based on bank
        if (bankName == 'Axis Bank' &&
            message.body!.contains('BLOCKUPI') &&
            message.body!.contains('Axis Bank')) {
          transaction = _parseAxisBankSms(message.body!);
        }
        // Add parsers for other banks here
        // else if (bankName == 'HDFC Bank' && ...) { ... }

        if (transaction != null) {
          parsedTransactions.add(transaction);
        }
      }

      return parsedTransactions;
    } catch (e) {
      print('Error reading SMS: $e');
      rethrow; // Propagate error to be handled by UI
    }
  }

  // Parse Axis Bank SMS format
  Transaction? _parseAxisBankSms(String smsBody) {
    // Example SMS format:
    // INR 3440.00 debited A/c no. XX8180 10-04-25, 17:54:12 UPI/P2M/510044436406/DUGOUT SPORTS AND E Not you? SMS BLOCKUPI Cust ID to 919951860002 Axis Bank

    try {
      // Extract amount
      final RegExp amountRegex = RegExp(r'INR\s+(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(smsBody);
      if (amountMatch == null) return null;
      final double amount = double.parse(amountMatch.group(1)!);

      // Extract date and time
      final RegExp dateTimeRegex = RegExp(r'(\d{2}-\d{2}-\d{2}),\s+(\d{2}:\d{2}:\d{2})');
      final dateTimeMatch = dateTimeRegex.firstMatch(smsBody);
      if (dateTimeMatch == null) return null;

      final String dateStr = dateTimeMatch.group(1)!;
      final String timeStr = dateTimeMatch.group(2)!;

      // Parse date (format: DD-MM-YY)
      final List<String> dateParts = dateStr.split('-');
      final int day = int.parse(dateParts[0]);
      final int month = int.parse(dateParts[1]);
      // Handle two-digit year by prefixing with '20' as we're in the 2000s
      final int year = int.parse('20${dateParts[2]}');

      // Parse time (format: HH:MM:SS)
      final List<String> timeParts = timeStr.split(':');
      final int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final int second = int.parse(timeParts[2]);

      final DateTime dateTime = DateTime(year, month, day, hour, minute, second);

      // Extract merchant name
      // Look for text between the last slash in UPI/P2M/number/ and "Not you?"
      final RegExp merchantRegex = RegExp(r'UPI\/(?:P2M|P2A)\/\d+\/(.+)\nNot you\?');
      final merchantMatch = merchantRegex.firstMatch(smsBody);
      String merchant = "Unknown";

      if (merchantMatch != null && merchantMatch.group(1) != null) {
        merchant = merchantMatch.group(1)!.trim();
      }

      return Transaction(
        amount: amount,
        merchant: merchant,
        dateTime: dateTime,
      );
    } catch (e) {
      print('Error parsing SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }
}