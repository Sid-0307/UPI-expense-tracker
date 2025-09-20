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
      print('Total messages: ${messages.length}');

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
        } else if (bankName == 'ICICI Bank' &&
            (message.body!.contains('ICICI Bank') || message.body!.contains('ICICI'))) {
          transaction = _parseICICIBankSms(message.body!);
        } else if (bankName == 'HDFC Bank' &&
            message.body!.contains('HDFC Bank')) {
          transaction = _parseHDFCBankSms(message.body!);
        } else if (bankName == 'Citi Union Bank' &&
            (_isCUBSms(message.body!))) {
          transaction = _parseCUBSms(message.body!);
        } else if (bankName == 'Kotak Bank' &&
            message.body!.contains('Kotak Bank')) {
          transaction = _parseKotakBankSms(message.body!);
        } else if (bankName == 'SBI Bank' &&
            message.body!.contains('SBI')) {
          transaction = _parseSBISms(message.body!);
        }
        if (transaction != null) {
          parsedTransactions.add(transaction);
        }
      }

      print('Parsed ${parsedTransactions.length} transactions for $bankName');
      return parsedTransactions;
    } catch (e) {
      print('Error reading SMS: $e');
      rethrow; // Propagate error to be handled by UI
    }
  }

  // Helper method to identify CUB SMS (handles cases where 'CUB' might not be present in debit SMS)
  bool _isCUBSms(String smsBody) {
    // Check for explicit CUB mention
    if (smsBody.contains('CUB')) return true;

    // Check for CUB-specific patterns
    final cubPatterns = [
      r'Your a/c no\. X+\d+ is (?:debited|credited) for Rs\.\d+(?:\.\d+)? on \d{1,2}-\d{1,2}-\d{4} and (?:credited to|debited from) a/c no\. X+\d+ \(UPI Ref no \d+\)',
    ];

    for (final pattern in cubPatterns) {
      if (RegExp(pattern).hasMatch(smsBody)) return true;
    }

    return false;
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

      // Determine transaction type
      String type = 'debit'; // Axis Bank SMS format typically shows debits
      if (smsBody.contains('credited')) {
        type = 'credit';
      }

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
      final int year = int.parse('20${dateParts[2]}');

      // Parse time (format: HH:MM:SS)
      final List<String> timeParts = timeStr.split(':');
      final int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final int second = int.parse(timeParts[2]);

      final DateTime dateTime = DateTime(year, month, day, hour, minute, second);

      // Extract merchant name
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
        type: type,
      );
    } catch (e) {
      print('Error parsing Axis Bank SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }

  // Parse ICICI Bank SMS format
  Transaction? _parseICICIBankSms(String smsBody) {
    // Example formats:
    // Dear Customer, Acct XX025 is credited with Rs 28500.00 on 19-Sep-25 from G ELANGOVAN. UPI:562824916828-ICICI Bank.
    // ICICI Bank Acct XX025 debited for Rs 600.00 on 20-Sep-25; KAKADA RAMPRASA credited. UPI:526361746352. Call 18002662 for dispute. SMS BLOCK 025 to 9215676766.

    try {
      // Extract amount
      final RegExp amountRegex = RegExp(r'Rs\s+(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(smsBody);
      if (amountMatch == null) return null;
      final double amount = double.parse(amountMatch.group(1)!);

      // Determine transaction type
      String type = 'debit';
      if (smsBody.contains('credited with') || smsBody.contains('is credited')) {
        type = 'credit';
      }

      // Extract date
      final RegExp dateRegex = RegExp(r'on\s+(\d{1,2}-\w{3}-\d{2})');
      final dateMatch = dateRegex.firstMatch(smsBody);
      if (dateMatch == null) return null;

      final String dateStr = dateMatch.group(1)!;
      final DateTime dateTime = _parseDateString(dateStr, 'DD-MMM-YY');

      // Extract merchant name
      String merchant = "Unknown";

      if (type == 'credit') {
        // For credit transactions: extract sender name
        final RegExp merchantRegex = RegExp(r'from\s+([^.]+)\.');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      } else {
        // For debit transactions: extract recipient name
        final RegExp merchantRegex = RegExp(r';\s*([^;]+)\s+credited');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      }

      return Transaction(
        amount: amount,
        merchant: merchant,
        dateTime: dateTime,
        type: type,
      );
    } catch (e) {
      print('Error parsing ICICI Bank SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }

  // Parse HDFC Bank SMS format
  Transaction? _parseHDFCBankSms(String smsBody) {
    // Example formats:
    // Sent Rs.1.00 From HDFC Bank A/C *1472 To SIDDHARTH S On 20/09/25 Ref 111520861388
    // Received Rs.500.00 In HDFC Bank A/C *1472 From JOHN DOE On 20/09/25 Ref 111520861388

    try {
      // Extract amount
      final RegExp amountRegex = RegExp(r'Rs\.(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(smsBody);
      if (amountMatch == null) return null;
      final double amount = double.parse(amountMatch.group(1)!);

      // Determine transaction type
      String type = 'debit';
      if (smsBody.startsWith('Received') || smsBody.contains('Received')) {
        type = 'credit';
      }

      // Extract date
      final RegExp dateRegex = RegExp(r'On\s+(\d{1,2}\/\d{1,2}\/\d{2})');
      final dateMatch = dateRegex.firstMatch(smsBody);
      if (dateMatch == null) return null;

      final String dateStr = dateMatch.group(1)!;
      final DateTime dateTime = _parseDateString(dateStr, 'DD/MM/YY');

      // Extract merchant name
      String merchant = "Unknown";
      if (type == 'debit') {
        // For sent transactions: extract recipient
        final RegExp merchantRegex = RegExp(r'To\s+([^\n]+)');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      } else {
        // For received transactions: extract sender
        final RegExp merchantRegex = RegExp(r'From\s+([^\n]+)\s+On');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      }

      return Transaction(
        amount: amount,
        merchant: merchant,
        dateTime: dateTime,
        type: type,
      );
    } catch (e) {
      print('Error parsing HDFC Bank SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }

  // Parse CUB (Citi Union Bank) SMS format
  Transaction? _parseCUBSms(String smsBody) {
    // Example formats:
    // Your a/c no. XXXXXXXX6873 is debited for Rs.210.00 on 20-09-2025 and credited to a/c no. XXXXXXXX0051 (UPI Ref no 526393844602)
    // Your a/c no. XXXXXXXX6873 is credited for Rs.285.00 on 17-09-2025 and debited from a/c no. XXXXXXXX2862 (UPI Ref no 562645364876) -CUB

    try {
      // Extract amount
      final RegExp amountRegex = RegExp(r'Rs\.(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(smsBody);
      if (amountMatch == null) return null;
      final double amount = double.parse(amountMatch.group(1)!);

      // Determine transaction type
      String type = 'debit';
      if (smsBody.contains('is credited for')) {
        type = 'credit';
      }

      // Extract date
      final RegExp dateRegex = RegExp(r'on\s+(\d{1,2}-\d{1,2}-\d{4})');
      final dateMatch = dateRegex.firstMatch(smsBody);
      if (dateMatch == null) return null;

      final String dateStr = dateMatch.group(1)!;
      final DateTime dateTime = _parseDateString(dateStr, 'DD-MM-YYYY');

      // Extract transaction type and set merchant accordingly
      String merchant = "Unknown";
      if (type == 'debit') {
        // For debit transactions: extract credited account info
        final RegExp merchantRegex = RegExp(r'credited to a/c no\. (X+\d+)');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = "Account ${merchantMatch.group(1)!}";
        }
      } else {
        // For credit transactions: extract debited account info
        final RegExp merchantRegex = RegExp(r'debited from a/c no\. (X+\d+)');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = "Account ${merchantMatch.group(1)!}";
        }
      }

      return Transaction(
        amount: amount,
        merchant: merchant,
        dateTime: dateTime,
        type: type,
      );
    } catch (e) {
      print('Error parsing CUB SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }

  // Parse Kotak Bank SMS format
  Transaction? _parseKotakBankSms(String smsBody) {
    // Example formats:
    // Sent Rs.5.00 from Kotak Bank AC X4998 to bdpg.iruts@sbi on 20-09-25.UPI Ref 562913861691. Not you, https://kotak.com/KBANKT/Fraud
    // Received Rs.500.00 in your Kotak Bank AC X4998 from jnyrajan@okaxis on 11-09-25.UPI Ref:525442520455.

    try {
      // Extract amount
      final RegExp amountRegex = RegExp(r'Rs\.(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(smsBody);
      if (amountMatch == null) return null;
      final double amount = double.parse(amountMatch.group(1)!);

      // Determine transaction type
      String type = 'debit';
      if (smsBody.startsWith('Received')) {
        type = 'credit';
      }

      // Extract date
      final RegExp dateRegex = RegExp(r'on\s+(\d{1,2}-\d{1,2}-\d{2})');
      final dateMatch = dateRegex.firstMatch(smsBody);
      if (dateMatch == null) return null;

      final String dateStr = dateMatch.group(1)!;
      final DateTime dateTime = _parseDateString(dateStr, 'DD-MM-YY');

      // Extract merchant name based on transaction type
      String merchant = "Unknown";
      if (type == 'debit') {
        // For sent transactions: extract recipient
        final RegExp merchantRegex = RegExp(r'to\s+([^\s]+)\s+on');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      } else {
        // For received transactions: extract sender
        final RegExp merchantRegex = RegExp(r'from\s+([^\s]+)\s+on');
        final merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      }

      return Transaction(
        amount: amount,
        merchant: merchant,
        dateTime: dateTime,
        type: type,
      );
    } catch (e) {
      print('Error parsing Kotak Bank SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }

  Transaction? _parseSBISms(String smsBody) {
    // Example formats:
    // Dear UPI user A/C X7687 debited by 40.0 on date 08Jul25 trf to MODERN BAKES Refno 518952818169. If not u? call 1800111109. -SBI

    try {
      // Extract amount (handle multiple formats: INR, Rs, and direct amount)
      RegExp amountRegex = RegExp(r'(?:INR|Rs)\s+(\d+(?:\.\d+)?)');
      Match? amountMatch = amountRegex.firstMatch(smsBody);
      // If no INR/Rs prefix found, try the "debited by" or "credited by" format
      if (amountMatch == null) {
        amountRegex = RegExp(r'(?:debited|credited)\s+by\s+(\d+(?:\.\d+)?)');
        amountMatch = amountRegex.firstMatch(smsBody);
      }

      if (amountMatch == null) return null;
      final double amount = double.parse(amountMatch.group(1)!);

      // Determine transaction type
      String type = 'debit';
      if (smsBody.contains('credited to') ||
          smsBody.contains('received in') ||
          smsBody.contains('credited by')) {
        type = 'credit';
      }

      // Extract date (handle multiple formats)
      RegExp dateRegex;
      Match? dateMatch;
      String? dateStr;

      // Try format: DDMmmYY (08Jul25)
      dateRegex = RegExp(r'on date (\d{1,2}\w{3}\d{2})');
      dateMatch = dateRegex.firstMatch(smsBody);
      if (dateMatch != null) {
        dateStr = dateMatch.group(1)!;
      } else {
        // Try format: DD-MMM-YY (20-Sep-25)
        dateRegex = RegExp(r'on\s+(\d{1,2}-\w{3}-\d{2})');
        dateMatch = dateRegex.firstMatch(smsBody);
        if (dateMatch != null) {
          dateStr = dateMatch.group(1)!;
        }
      }

      if (dateStr == null) return null;

      final DateTime dateTime = _parseDateString(dateStr,
          dateStr.contains('-') ? 'DD-MMM-YY' : 'DDMMMYY');

      // Extract merchant name
      String merchant = "Unknown";

      if (type == 'debit') {
        // For debit transactions: try multiple patterns

        // Pattern 1: "trf to MERCHANT NAME"
        RegExp merchantRegex = RegExp(r'trf to (.*?)(?:\s+Refno|\s+Ref\s|$)', caseSensitive: false);
        Match? merchantMatch = merchantRegex.firstMatch(smsBody);

        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        } else {
          // Pattern 2: "to VPA xyz@paytm" or "to john.doe@ybl"
          merchantRegex = RegExp(r'to\s+(?:VPA\s+)?([^\s]+)');
          merchantMatch = merchantRegex.firstMatch(smsBody);
          if (merchantMatch != null) {
            merchant = merchantMatch.group(1)!.trim();
          }
        }
      } else {
        // For credit transactions: extract sender VPA or name
        RegExp merchantRegex = RegExp(r'from\s+(?:VPA\s+)?([^\s]+)');
        Match? merchantMatch = merchantRegex.firstMatch(smsBody);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)!.trim();
        }
      }
      return Transaction(
        amount: amount,
        merchant: merchant,
        dateTime: dateTime,
        type: type,
      );
    } catch (e) {
      print('Error parsing SBI SMS: $e');
      print('SMS content: $smsBody');
      return null;
    }
  }

// Helper method to parse different date formats
  DateTime _parseDateString(String dateStr, String format) {
    try {
      if (format == 'DD-MMM-YY') {
        // Format: 19-Sep-25
        final parts = dateStr.split('-');
        final day = int.parse(parts[0]);
        final year = int.parse('20${parts[2]}');

        final monthMap = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        final month = monthMap[parts[1]] ?? 1;

        return DateTime(year, month, day);
      } else if (format == 'DDMMMYY') {
        // Format: 08Jul25
        final dayStr = dateStr.substring(0, 2);
        final monthStr = dateStr.substring(2, 5);
        final yearStr = dateStr.substring(5, 7);

        final day = int.parse(dayStr);
        final year = int.parse('20$yearStr');

        final monthMap = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        final month = monthMap[monthStr] ?? 1;

        return DateTime(year, month, day);
      } else if (format == 'DD/MM/YY') {
        // Format: 20/09/25
        final parts = dateStr.split('/');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse('20${parts[2]}');

        return DateTime(year, month, day);
      } else if (format == 'DD-MM-YYYY') {
        // Format: 20-09-2025
        final parts = dateStr.split('-');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        return DateTime(year, month, day);
      } else if (format == 'DD-MM-YY') {
        // Format: 20-09-25
        final parts = dateStr.split('-');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse('20${parts[2]}');

        return DateTime(year, month, day);
      }

      // Fallback to current date if parsing fails
      return DateTime.now();
    } catch (e) {
      print('Error parsing date: $dateStr with format: $format');
      return DateTime.now();
    }
  }
}