# ADDO Manager – Flutter starter

Offline-first Android starter for a single ADDO, with Swahili/English UI.

## Included in this first MVP
- Local SQLite database (medicines, sales, expenses, audit log tables)
- Dashboard with today's sales, gross profit, stock units and low-stock count
- Add medicine and view/search medicine stock
- Record a sale with stock validation and automatic stock deduction
- Basic sales history and all-time gross sales/profit summary
- Language toggle (Swahili / English)

## Run
1. Install Flutter SDK and Android Studio.
2. Unzip this project.
3. Run `flutter pub get`.
4. Connect an Android phone or start an emulator.
5. Run `flutter run`.

## Important production work still required
This is a functional starter, not yet a certified pharmacy/ADDO product. Before real deployment:
- Add medicine category and regulatory classification rules; validate allowed products against current Tanzania TMDA/ADDO requirements.
- Add expiry/batch-level stock with FEFO selling, purchase receiving, supplier balances, customer credit ledger, returns, expenses UI, and full audit trail.
- Add authentication, role permissions, PIN lock, encrypted backup/restore and tested export/import.
- Add PDF/Excel reports, barcode support, Bluetooth receipt printing and optional secure cloud sync.
- Add automated tests, database migrations, device-loss recovery, and privacy/security review.
- Validate tax, fiscal receipt and business compliance requirements with the relevant authorities and providers.

## Data
The database is stored locally on the Android device in `addo_manager.db`. Uninstalling the app or clearing app data can delete local data; implement and test backups before using it for live business records.


## Version 0.2 additions
- Admin-only login screen
- Password login and 4-digit PIN login
- First-run credentials: username `admin`, password `admin123`, PIN `1234`
- Change username/password/PIN screen
- Password/PIN hashes stored in SQLite (not plaintext)

**Important:** Change the default credentials immediately. The starter does not yet implement account lockout, encrypted database, secure backup, or a production-grade password KDF. Do not use the default credentials in a live shop.


## Version 0.3 additions
- Supplier directory
- Purchase receiving workflow that increases medicine stock and records batch/expiry details
- Expense recording and expense history
- Expiry alert list for medicines with expiry date within the next 90 days
- SQLite schema migration to version 2

Note: purchase intake currently updates the medicine's single batch/expiry fields. For production pharmacy use, implement a dedicated batch-level inventory ledger and FEFO allocation before relying on expiry reporting across multiple batches.


## Version 0.4 additions
- Batch ledger created for each purchase receipt
- FEFO batch depletion during sales (earliest expiry first)
- Credit sales require a customer name and create a customer debt record
- Customer debt payment recording
- Supplier balance summary and supplier payment recording
- Database schema migration to version 3

Important limitations to resolve before production:
- Supplier payments are recorded in a payment ledger, but the supplier balance aggregation currently needs to subtract those payments in a follow-up migration/query.
- Historical medicines already in stock before batch tracking are legacy unbatched stock.
- Expiry alerts and batch availability need comprehensive tests, especially mixed batches and expired stock.
- No PDF/Excel export or backup/restore in this release yet.


## Version 0.5 additions
- Export sales history as CSV (opens in Microsoft Excel, Google Sheets and similar apps).
- Share a copy of the local SQLite database as a backup file.
- Restore a selected `.db` backup; the app asks for confirmation because restore replaces current records.

Important: CSV is a spreadsheet-compatible export, not a native `.xlsx` workbook. PDF reports are not included in this iteration. Backups are currently unencrypted; store them securely. Restore requires a valid backup created by this app and the app should be restarted afterwards. This code has not been compiled or device-tested in this environment.

## Version 0.5.1 maintenance fixes
- Fixed a missing closing parenthesis in the supplier-entry dialog that prevented Dart compilation.
- Supplier balance totals now subtract supplier payments from the outstanding balance.
- Supplier payments are checked against the remaining balance and recorded in the audit log.
- Purchase receiving rejects an initial payment greater than the purchase total.
- Expense entries are validated and recorded in the audit log.

## Remaining work before production
This maintenance update does **not** claim to complete the full production checklist. Native barcode scanning, Bluetooth receipt printing, PDF reports, encrypted backup/database, account lockout and role permissions, cloud sync, formal automated/device testing, and TMDA/tax/fiscal compliance validation still need separate implementation and verification. Bluetooth printing also needs the target printer model/protocol; regulatory and fiscal requirements must be confirmed with the relevant Tanzanian authorities/providers. Do not use this app as a certified pharmacy/fiscal system until those checks are complete.
