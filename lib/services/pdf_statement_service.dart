// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:upi_expense_tracker/models/transaction.dart';
// // TODO: Add PDF parsing package (syncfusion_flutter_pdf or pdf_text)
//
// class PdfStatementService {
//   /// Main entry point: Pick PDF and analyze
//   Future<List<Transaction>> analyzeStatement() async {
//     // Step 1: Pick PDF file
//     final pdfFile = await pickPdfFile();
//     if (pdfFile == null) {
//       throw Exception('No PDF file selected');
//     }
//
//     // Step 2: Extract text from PDF
//     final pdfText = await extractText(pdfFile);
//
//     // Step 3: Parse transactions
//     final transactions = parseTransactions(pdfText);
//
//     return transactions;
//   }
//
//   /// Pick PDF file using file picker
//   Future<File?> pickPdfFile() async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['pdf'],
//     );
//
//     if (result != null && result.files.single.path != null) {
//       return File(result.files.single.path!);
//     }
//     return null;
//   }
//
//   /// Extract text from PDF file
//   /// TODO: Implement using syncfusion_flutter_pdf or pdf_text package
//   Future<String> extractText(File pdfFile) async {
//     // Placeholder - implement based on chosen PDF package
//     // Example with syncfusion_flutter_pdf:
//     /*
//     final PdfDocument document = PdfDocument(inputBytes: await pdfFile.readAsBytes());
//     String text = '';
//     for (int i = 0; i < document.pages.count; i++) {
//       text += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
//     }
//     document.dispose();
//     return text;
//     */
//
//     throw UnimplementedError('PDF text extraction not yet implemented');
//   }
//
//   /// Parse transactions from extracted PDF text
//   /// Simple regex-based parser - start with basic patterns
//   List<Transaction> parseTransactions(String pdfText) {
//     final transactions = <Transaction>[];
//     final lines = pdfText.split('\n');
//
//     for (var line in lines) {
//       // Skip empty lines and headers
//       if (line.trim().isEmpty || _isHeaderOrFooter(line)) {
//         continue;
//       }
//
//       // Try to extract transaction
//       final transaction = _parseTransactionLine(line);
//       if (transaction != null) {
//         transactions.add(transaction);
//       }
//     }
//
//     return transactions;
//   }
//
//   /// Check if line is header or footer (skip these)
//   bool _isHeaderOrFooter(String line) {
//     final headerKeywords = [
//       'date',
//       'description',
//       'debit',
//       'credit',
//       'balance',
//       'particulars',
//       'narration',
//       'statement',
//       'account',
//       'page',
//     ];
//
//     final lowerLine = line.toLowerCase();
//     return headerKeywords.any((keyword) => lowerLine.contains(keyword)) ||
//         RegExp(r'^\s*$').hasMatch(line) ||
//         line.length < 10; // Skip very short lines
//   }
//
//   /// Parse a single line into Transaction
//   /// Start simple - improve based on actual PDF format
//   Transaction? _parseTransactionLine(String line) {
//     try {
//       // Extract date (DD-MM-YYYY or DD/MM/YYYY)
//       final dateMatch = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})').firstMatch(line);
//       if (dateMatch == null) return null;
//
//       final day = int.parse(dateMatch.group(1)!);
//       final month = int.parse(dateMatch.group(2)!);
//       final year = int.parse(dateMatch.group(3)!);
//       final fullYear = year < 100 ? 2000 + year : year;
//
//       // Extract amount (debit or credit)
//       final amountRegex = RegExp(r'(?:Rs\.?|INR)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)');
//       final debitMatch = amountRegex.firstMatch(line);
//
//       String type = 'debit';
//       double? amount;
//
//       // Check for credit indicators
//       if (line.toLowerCase().contains('credit') ||
//           line.toLowerCase().contains('cr')) {
//         type = 'credit';
//       }
//
//       if (debitMatch != null) {
//         final amountStr = debitMatch.group(1)!.replaceAll(',', '');
//         amount = double.parse(amountStr);
//       } else {
//         return null; // No amount found
//       }
//
//       // Extract merchant/description (text between date and amount)
//       String merchant = 'Unknown';
//       final dateEnd = dateMatch.end;
//       final amountStart = debitMatch?.start ?? line.length;
//
//       if (amountStart > dateEnd) {
//         merchant = line.substring(dateEnd, amountStart).trim();
//         if (merchant.isEmpty) merchant = 'Unknown';
//       }
//
//       return Transaction(
//         amount: amount,
//         merchant: merchant,
//         dateTime: DateTime(fullYear, month, day),
//         type: type,
//       );
//     } catch (e) {
//       // Skip lines that can't be parsed
//       return null;
//     }
//   }
// }
//
