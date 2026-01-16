# XpenseEz V2 Architecture & Implementation Plan

## V2 Architecture Overview

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Home Screen (Mode Selection)              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  Quick Scan      │         │  Accurate Scan   │         │
│  │  (SMS-based)     │         │  (PDF Statement)  │         │
│  └────────┬─────────┘         └────────┬─────────┘         │
└───────────┼─────────────────────────────┼───────────────────┘
            │                             │
            ▼                             ▼
┌──────────────────────┐    ┌──────────────────────────────┐
│  SMS Service         │    │  PDF Statement Service        │
│  - Read SMS          │    │  - File picker                │
│  - Parse by bank     │    │  - PDF text extraction        │
│  - Filter non-UPI    │    │  - Parse transactions         │
│  - Accept "Unknown"  │    │  - Extract debit + credit     │
└──────────┬───────────┘    └──────────────┬───────────────┘
           │                                │
           └────────────┬───────────────────┘
                        ▼
            ┌───────────────────────┐
            │  Transaction Model    │
            │  (Unified format)     │
            └───────────┬───────────┘
                        ▼
            ┌───────────────────────┐
            │  Transaction Summary  │
            │  Screen (Shared UI)   │
            └───────────────────────┘
```

### Key Design Decisions

1. **Separate Analysis Pipelines**: SMS and PDF never merge. User chooses one mode per session.
2. **Shared UI**: Both modes use same `TransactionSummaryScreen` with different data sources.
3. **Mode Selection**: Explicit choice on home screen before analysis.
4. **Storage**: Separate SharedPreferences keys for each mode's last scan.

---

## Implementation Plan

### Phase 1: Mode Selection UI (Day 1-2)

#### 1.1 Update Home Screen
- Add two large action cards: "Quick Scan" and "Accurate Scan"
- Keep bank selection for Quick Scan only
- Remove auto-navigation
- Store selected mode in SharedPreferences

**Files to modify:**
- `lib/screens/home_screen.dart`

**Changes:**
```dart
// Add mode enum
enum ScanMode { quickScan, accurateScan }

// Add mode selection UI before bank selection
// Show bank selector only for Quick Scan mode
```

#### 1.2 Navigation Logic
- Quick Scan → SMS Service → TransactionSummaryScreen
- Accurate Scan → PDF Picker → PDF Service → TransactionSummaryScreen
- Pass mode context to TransactionSummaryScreen (for display purposes)

---

### Phase 2: SMS Quick Scan Improvements (Day 2-4)

#### 2.1 Enhanced Filtering
**File:** `lib/services/sms_service.dart`

**Add filter method:**
```dart
bool _isNonUPITransaction(String smsBody) {
  final nonUPIPatterns = [
    r'\b(loan|emi|installment|repayment)\b',
    r'\b(credit card|card payment|card bill)\b',
    r'\b(salary|salary credit)\b',
    r'\b(fd|fixed deposit|recurring deposit)\b',
    r'\b(mutual fund|sip|investment)\b',
  ];
  
  final lowerBody = smsBody.toLowerCase();
  return nonUPIPatterns.any((pattern) => 
    RegExp(pattern, caseSensitive: false).hasMatch(lowerBody)
  );
}
```

**Update `readTransactions`:**
- Apply `_isNonUPITransaction` filter before parsing
- Skip SMS that match non-UPI patterns
- Keep "Unknown" merchant acceptance (no changes needed)

#### 2.2 Bank-Specific Improvements
**Priority banks only (Axis, HDFC, ICICI, SBI):**
- Improve regex patterns for merchant extraction
- Better date parsing (use SMS date as fallback)
- Handle edge cases for these 4 banks only

**Ignore:**
- Kotak, CUB, Canara edge cases
- New bank additions
- Format variations for non-priority banks

---

### Phase 3: PDF Statement Analyzer (Day 4-8)

#### 3.1 Dependencies
**Add to `pubspec.yaml`:**
```yaml
dependencies:
  file_picker: ^8.0.0+1
  pdf_text: ^0.3.0  # or pdfx: ^0.8.0
  # OR use syncfusion_flutter_pdf: ^28.0.0 (more reliable)
```

#### 3.2 PDF Service Structure
**New file:** `lib/services/pdf_statement_service.dart`

**Core methods:**
```dart
class PdfStatementService {
  // 1. Pick PDF file
  Future<File?> pickPdfFile() async { ... }
  
  // 2. Extract text from PDF
  Future<String> extractText(File pdfFile) async { ... }
  
  // 3. Parse transactions from text
  List<Transaction> parseTransactions(String pdfText) { ... }
  
  // 4. Main entry point
  Future<List<Transaction>> analyzeStatement() async { ... }
}
```

#### 3.3 PDF Text Extraction
**Simple approach:**
- Use `syncfusion_flutter_pdf` or `pdf_text` package
- Extract all text from PDF
- Parse line by line

**Bank statement format assumptions:**
- Date | Description | Debit | Credit | Balance
- Common formats: DD-MM-YYYY, DD/MM/YYYY
- Amount formats: Rs. 1,234.56, INR 1234.56

#### 3.4 Transaction Parsing
**Simple regex-based parser:**
```dart
List<Transaction> parseTransactions(String pdfText) {
  final lines = pdfText.split('\n');
  final transactions = <Transaction>[];
  
  for (var line in lines) {
    // Skip header/footer lines
    if (_isHeaderOrFooter(line)) continue;
    
    // Extract date
    final dateMatch = RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').firstMatch(line);
    if (dateMatch == null) continue;
    
    // Extract amount (debit or credit)
    final debitMatch = RegExp(r'(?:Rs\.?|INR)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)').firstMatch(line);
    // ... similar for credit
    
    // Extract description/merchant
    // Simple: text between date and amount
    
    // Create Transaction object
  }
  
  return transactions;
}
```

**Start simple:**
- Support 1-2 common bank PDF formats (Axis, HDFC)
- Add more banks only if time permits
- Accept "Unknown" for unparseable transactions

#### 3.4 UI Integration
**Update home screen:**
- Add "Accurate Scan" button
- On tap: call `PdfStatementService.analyzeStatement()`
- Show loading indicator
- Navigate to TransactionSummaryScreen with results

---

### Phase 4: Transaction Summary Screen Updates (Day 8-9)

#### 4.1 Mode Indicator
- Add badge/chip showing current mode: "Quick Scan" or "Accurate Scan"
- Display in app bar or summary cards area

#### 4.2 Data Source Labeling
- Show "Source: SMS" or "Source: Bank Statement" in transaction list
- Optional: Different icon for each mode

**File:** `lib/screens/transaction_summary_screen.dart`

**Changes:**
```dart
class TransactionSummaryScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final ScanMode mode; // Add this
  // ...
}
```

---

### Phase 5: Storage & State Management (Day 9-10)

#### 5.1 Mode Preference
- Store last selected mode in SharedPreferences
- Pre-select mode on next app launch (optional, can skip)

#### 5.2 Separate Scan History
- Store last scan timestamp per mode
- Show "Last scanned: X hours ago" in home screen

---

## What NOT to Build in V2

### ❌ Do Not Build

1. **SMS + PDF Data Merging**
   - Never combine data from both sources
   - No "merge scans" feature

2. **Auto Bank Detection**
   - Keep manual bank selection for Quick Scan
   - No automatic bank detection from SMS

3. **ML/AI Features**
   - No merchant name normalization with ML
   - No transaction categorization AI
   - No fraud detection

4. **Multi-Bank Support for PDF**
   - Start with 1-2 banks (Axis, HDFC)
   - Don't build universal PDF parser

5. **Cloud/Backend**
   - No data sync
   - No cloud backup
   - No analytics tracking

6. **Advanced PDF Features**
   - No OCR for scanned PDFs (text-based only)
   - No password-protected PDF support
   - No multi-page statement handling (start with single page)

7. **Transaction Editing**
   - No manual transaction correction in V2
   - No bulk edit features

8. **Export/Import**
   - No CSV export (keep existing Excel export if present)
   - No data import from other apps

9. **Notifications**
   - No real-time transaction alerts
   - No daily/weekly summaries

10. **Social/Sharing**
    - No sharing features
    - No comparison with friends

---

## Edge Cases to Ignore

### Intentionally Ignored

1. **SMS Edge Cases:**
   - Multi-line SMS (only parse single-line)
   - Encrypted SMS
   - SMS from non-UPI apps (Paytm wallet, etc.)
   - International transactions
   - Failed/cancelled transactions in SMS

2. **PDF Edge Cases:**
   - Scanned PDFs (image-based, requires OCR)
   - Password-protected PDFs
   - Multi-currency statements
   - Statements with multiple accounts
   - Partial statements (only parse complete months)

3. **Transaction Edge Cases:**
   - Refunds (treat as credits)
   - Reversals (may appear as duplicate)
   - Split transactions
   - Recurring payments identification

4. **Bank-Specific Edge Cases:**
   - Regional language SMS
   - Custom SMS formats from smaller banks
   - Bank app notifications (not SMS)

5. **Data Quality:**
   - Duplicate transaction detection (basic only)
   - Missing merchant names (accept "Unknown")
   - Incorrect dates (use SMS/PDF date as-is)

---

## File Structure Changes

```
lib/
├── models/
│   └── transaction.dart (no changes)
├── screens/
│   ├── home_screen.dart (MODIFY: add mode selection)
│   └── transaction_summary_screen.dart (MODIFY: add mode indicator)
├── services/
│   ├── sms_service.dart (MODIFY: add filtering)
│   ├── pdf_statement_service.dart (NEW)
│   └── custom_category.dart (no changes)
└── utils/
    └── (no changes)
```

---

## Testing Strategy (Minimal)

### Manual Testing Only

1. **Quick Scan:**
   - Test with 2-3 banks (Axis, HDFC)
   - Verify non-UPI filtering works
   - Check "Unknown" merchant acceptance

2. **Accurate Scan:**
   - Test with 1-2 PDF samples (Axis, HDFC)
   - Verify debit + credit extraction
   - Check date parsing

3. **UI Flow:**
   - Mode selection works
   - Navigation to summary screen
   - Mode indicator displays correctly

**No automated tests for V2** (time constraint)

---

## Success Criteria

### V2 is Complete When:

✅ User can choose between Quick Scan and Accurate Scan  
✅ Quick Scan filters obvious non-UPI transactions  
✅ Accurate Scan parses PDF statements for 1-2 banks  
✅ Both modes show results in TransactionSummaryScreen  
✅ Mode is clearly indicated in UI  
✅ App remains offline-first  
✅ No crashes on valid inputs  

### V2 is NOT Complete If:

❌ SMS and PDF data are merged  
❌ Complex edge cases are handled  
❌ More than 2 banks supported for PDF  
❌ ML/AI features added  
❌ Backend/cloud features added  

---

## Timeline Estimate

- **Day 1-2:** Mode selection UI
- **Day 2-4:** SMS filtering improvements
- **Day 4-8:** PDF analyzer (basic)
- **Day 8-9:** UI integration
- **Day 9-10:** Polish & testing
- **Day 10-14:** Buffer for issues + Play Store submission

**Total: 1-2 weeks** ✅

---

## Next Steps

1. Review this architecture
2. Start with Phase 1 (mode selection UI)
3. Iterate based on testing
4. Ship when 90% accuracy goal is met

**Remember: Ship > Perfect**

