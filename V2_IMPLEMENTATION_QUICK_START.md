# V2 Implementation Quick Start

## Step 1: Add SMS Filtering (30 mins)

### File: `lib/services/sms_service.dart`

**Add this method after `_isCUBSms` method (around line 74):**

```dart
/// Filter out non-UPI transactions (loans, credit cards, etc.)
bool _isNonUPITransaction(String smsBody) {
  final nonUPIPatterns = [
    r'\b(loan|emi|installment|repayment)\b',
    r'\b(credit card|card payment|card bill|card transaction)\b',
    r'\b(salary|salary credit)\b',
    r'\b(fd|fixed deposit|recurring deposit|rd)\b',
    r'\b(mutual fund|sip|investment|equity)\b',
    r'\b(insurance premium|policy)\b',
    r'\b(cheque|cheque clearing)\b',
    r'\b(nach|auto debit|standing instruction)\b',
  ];
  
  final lowerBody = smsBody.toLowerCase();
  return nonUPIPatterns.any((pattern) => 
    RegExp(pattern, caseSensitive: false).hasMatch(lowerBody)
  );
}
```

**Update `readTransactions` method (around line 19):**

```dart
for (var message in messages) {
  if (message.body == null) continue;
  
  // ADD THIS: Filter non-UPI transactions
  if (_isNonUPITransaction(message.body!)) {
    continue; // Skip this SMS
  }
  
  Transaction? transaction;
  // ... rest of existing code
}
```

---

## Step 2: Add Mode Selection UI (2-3 hours)

### File: `lib/screens/home_screen.dart`

**Add enum at top of file:**

```dart
enum ScanMode { quickScan, accurateScan }
```

**Add state variable in `_HomeScreenState`:**

```dart
ScanMode? selectedMode; // null = not selected yet
```

**Replace bank selection section with mode selection:**

```dart
// Show mode selection first
if (selectedMode == null) {
  return _buildModeSelection();
}

// Show bank selection only for Quick Scan
if (selectedMode == ScanMode.quickScan) {
  return _buildBankSelection();
}

// For Accurate Scan, show file picker button
return _buildAccurateScanButton();
```

**Add mode selection UI method:**

```dart
Widget _buildModeSelection() {
  return Scaffold(
    // ... existing scaffold code
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Choose Analysis Mode', style: TextStyle(...)),
        SizedBox(height: 32),
        
        // Quick Scan Card
        Card(
          child: InkWell(
            onTap: () => setState(() => selectedMode = ScanMode.quickScan),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.flash_on, size: 48),
                  Text('Quick Scan', style: TextStyle(...)),
                  Text('SMS-based, instant', style: TextStyle(...)),
                ],
              ),
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        // Accurate Scan Card
        Card(
          child: InkWell(
            onTap: () => setState(() => selectedMode = ScanMode.accurateScan),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.picture_as_pdf, size: 48),
                  Text('Accurate Scan', style: TextStyle(...)),
                  Text('PDF statement, reliable', style: TextStyle(...)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
```

**Update `_handleAnalyze` method:**

```dart
Future<void> _handleAnalyze() async {
  if (selectedMode == ScanMode.accurateScan) {
    // Handle PDF scan
    await _handleAccurateScan();
  } else {
    // Handle SMS scan (existing code)
    await _handleQuickScan();
  }
}

Future<void> _handleAccurateScan() async {
  setState(() => isLoading = true);
  
  try {
    final pdfService = PdfStatementService();
    final transactions = await pdfService.analyzeStatement();
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionSummaryScreen(
            transactions: transactions,
            mode: ScanMode.accurateScan, // Pass mode
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}

Future<void> _handleQuickScan() async {
  // Existing SMS scan code
  // ... (your current implementation)
  
  // Update navigation to pass mode:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TransactionSummaryScreen(
        transactions: transactions,
        mode: ScanMode.quickScan, // Pass mode
      ),
    ),
  );
}
```

---

## Step 3: Add PDF Dependencies (5 mins)

### File: `pubspec.yaml`

**Add to dependencies:**

```yaml
dependencies:
  file_picker: ^8.0.0+1
  syncfusion_flutter_pdf: ^28.0.0  # Recommended
  # OR
  # pdf_text: ^0.3.0  # Simpler but less reliable
```

**Run:**
```bash
flutter pub get
```

---

## Step 4: Implement PDF Text Extraction (1-2 hours)

### File: `lib/services/pdf_statement_service.dart`

**Update `extractText` method with syncfusion:**

```dart
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';

Future<String> extractText(File pdfFile) async {
  final bytes = await pdfFile.readAsBytes();
  final PdfDocument document = PdfDocument(inputBytes: bytes);
  
  String text = '';
  for (int i = 0; i < document.pages.count; i++) {
    text += PdfTextExtractor(document).extractText(
      startPageIndex: i, 
      endPageIndex: i
    );
    text += '\n'; // Add line break between pages
  }
  
  document.dispose();
  return text;
}
```

**Test with a sample PDF:**
- Download a bank statement PDF
- Test `extractText` method
- Print extracted text to see format
- Adjust `_parseTransactionLine` based on actual format

---

## Step 5: Update Transaction Summary Screen (30 mins)

### File: `lib/screens/transaction_summary_screen.dart`

**Update constructor:**

```dart
class TransactionSummaryScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final ScanMode mode; // ADD THIS

  const TransactionSummaryScreen({
    Key? key,
    required this.transactions,
    required this.mode, // ADD THIS
  }) : super(key: key);
}
```

**Add mode indicator in app bar or summary area:**

```dart
// In build method, add chip/badge:
Chip(
  label: Text(
    widget.mode == ScanMode.quickScan ? 'Quick Scan' : 'Accurate Scan',
    style: TextStyle(fontSize: 12),
  ),
  avatar: Icon(
    widget.mode == ScanMode.quickScan ? Icons.flash_on : Icons.picture_as_pdf,
    size: 16,
  ),
)
```

---

## Step 6: Testing Checklist

- [ ] Mode selection appears on home screen
- [ ] Quick Scan works with SMS (existing flow)
- [ ] Non-UPI SMS are filtered out
- [ ] Accurate Scan opens file picker
- [ ] PDF text extraction works
- [ ] PDF transactions are parsed correctly
- [ ] Mode indicator shows in summary screen
- [ ] No crashes on invalid PDFs
- [ ] "Unknown" merchants are accepted

---

## Common Issues & Fixes

### Issue: PDF text extraction returns empty
**Fix:** Check PDF is text-based (not scanned). Use `syncfusion_flutter_pdf` instead of `pdf_text`.

### Issue: Transactions not parsing from PDF
**Fix:** Print extracted text, check actual format, adjust regex patterns in `_parseTransactionLine`.

### Issue: File picker not working on Android
**Fix:** Add permissions in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### Issue: Too many false positives in SMS filtering
**Fix:** Tighten regex patterns, add more specific keywords based on your SMS samples.

---

## Next Steps After Basic Implementation

1. Test with real PDFs from your bank
2. Refine `_parseTransactionLine` based on actual format
3. Add more banks to PDF parser (if time permits)
4. Polish UI/UX
5. Test on real device
6. Submit to Play Store

---

## Time Estimate Per Step

- Step 1 (SMS Filtering): 30 mins
- Step 2 (Mode Selection UI): 2-3 hours
- Step 3 (Dependencies): 5 mins
- Step 4 (PDF Extraction): 1-2 hours
- Step 5 (Summary Screen): 30 mins
- Step 6 (Testing): 2-3 hours

**Total: ~8-10 hours of focused work**

