import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'addo_manager.db');
    _db = await openDatabase(path, version: 3, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) { await _createBusinessTables(db); }
      if (oldVersion < 3) {
        await _createAdvancedTables(db);
        await db.execute("ALTER TABLE sales ADD COLUMN customer_name TEXT");
      }
    }, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE medicines(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          generic_name TEXT,
          category TEXT,
          batch_no TEXT,
          expiry_date TEXT,
          cost_price REAL NOT NULL DEFAULT 0,
          selling_price REAL NOT NULL DEFAULT 0,
          quantity INTEGER NOT NULL DEFAULT 0,
          min_stock INTEGER NOT NULL DEFAULT 5,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicine_id INTEGER NOT NULL,
          medicine_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          unit_cost REAL NOT NULL,
          total REAL NOT NULL,
          profit REAL NOT NULL,
          payment_method TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE expenses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE app_users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          pin_hash TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      final saltText = base64Encode(salt);
      final defaultHash = sha256.convert(utf8.encode('admin123:$saltText')).toString();
      final defaultPinHash = sha256.convert(utf8.encode('1234:$saltText')).toString();
      await db.insert('app_users', {
        'username': 'admin',
        'password_hash': '$saltText:$defaultHash',
        'pin_hash': '$saltText:$defaultPinHash',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.execute('''
        CREATE TABLE audit_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          details TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await _createBusinessTables(db);
      await _createAdvancedTables(db);
    });
    return _db!;
  }

  Future<void> checkpointForBackup() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> closeForRestore() async {
    await _db?.close();
    _db = null;
  }

  Future<int> addMedicine(Map<String, Object?> data) async {
    final db = await database;
    final id = await db.insert('medicines', data);
    await db.insert('audit_log', {
      'action': 'ADD_MEDICINE',
      'details': data['name'],
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<List<Map<String, Object?>>> medicines() async =>
      (await database).query('medicines', orderBy: 'name COLLATE NOCASE');

  Future<List<Map<String, Object?>>> sales() async =>
      (await database).query('sales', orderBy: 'created_at DESC');


  Future<void> recordSale({
    required int medicineId,
    required String medicineName,
    required int quantity,
    required double unitPrice,
    required double unitCost,
    required String paymentMethod,
    String customerName = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('medicines', where: 'id=?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw Exception('Medicine not found');
      final available = rows.first['quantity'] as int;
      if (quantity <= 0 || quantity > available) throw Exception('Stock haitoshi. Iliyopo: $available');

      var remaining = quantity;
      final batches = await txn.query('medicine_batches',
        where: 'medicine_id=? AND quantity>0', whereArgs: [medicineId],
        orderBy: "CASE WHEN expiry_date IS NULL OR expiry_date='' THEN 1 ELSE 0 END, expiry_date ASC, id ASC");
      for (final batch in batches) {
        if (remaining == 0) break;
        final batchExpiry = (batch['expiry_date'] ?? '').toString();
        if (batchExpiry.isNotEmpty && batchExpiry.length >= 10 &&
            batchExpiry.substring(0, 10).compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0) {
          continue;
        }
        final batchQty = batch['quantity'] as int;
        final take = batchQty < remaining ? batchQty : remaining;
        await txn.update('medicine_batches', {'quantity': batchQty - take},
          where: 'id=?', whereArgs: [batch['id']]);
        remaining -= take;
      }
      // Legacy stock without batch rows can still be sold; new receipts are batch-tracked.
      if (remaining > 0 && batches.isNotEmpty) throw Exception('Stock ya batch halitoshi au baadhi ime-expire');
      final total = quantity * unitPrice;
      final profit = quantity * (unitPrice - unitCost);
      final saleId = await txn.insert('sales', {
        'medicine_id': medicineId, 'medicine_name': medicineName,
        'quantity': quantity, 'unit_price': unitPrice, 'unit_cost': unitCost,
        'total': total, 'profit': profit, 'payment_method': paymentMethod,
        'customer_name': customerName, 'created_at': DateTime.now().toIso8601String(),
      });
      await txn.update('medicines', {'quantity': available - quantity}, where: 'id=?', whereArgs: [medicineId]);
      if (paymentMethod == 'Credit') {
        if (customerName.trim().isEmpty) throw Exception('Jina la mteja linahitajika kwa mauzo ya mkopo');
        await txn.insert('customer_debts', {
          'customer_name': customerName.trim(), 'sale_id': saleId,
          'amount': total, 'paid': 0, 'created_at': DateTime.now().toIso8601String(),
        });
      }
      await txn.insert('audit_log', {
        'action': 'SALE', 'details': '$medicineName x$quantity',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> addExpense(String title, double amount, String note) async {
    final db = await database;
    if (title.trim().isEmpty || amount <= 0) throw Exception('Taarifa za matumizi si sahihi');
    await db.transaction((txn) async {
      await txn.insert('expenses', {
        'title': title.trim(), 'amount': amount, 'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('audit_log', {
        'action': 'ADD_EXPENSE', 'details': '${title.trim()}: $amount',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<Map<String, num>> summary() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final s = await db.rawQuery(
      'SELECT COALESCE(SUM(total),0) sales, COALESCE(SUM(profit),0) profit FROM sales WHERE created_at >= ?',
      [start],
    );
    final stock = await db.rawQuery('SELECT COALESCE(SUM(quantity),0) count FROM medicines');
    final low = await db.rawQuery('SELECT COUNT(*) count FROM medicines WHERE quantity <= min_stock');
    return {
      'sales': (s.first['sales'] as num),
      'profit': (s.first['profit'] as num),
      'stock': (stock.first['count'] as num),
      'low': (low.first['count'] as num),
    };
  }


  Future<void> _createBusinessTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER,
        supplier_name TEXT NOT NULL,
        medicine_id INTEGER,
        medicine_name TEXT NOT NULL,
        batch_no TEXT,
        expiry_date TEXT,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_name TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }


  Future<void> _createAdvancedTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicine_batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        batch_no TEXT,
        expiry_date TEXT,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_debts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        sale_id INTEGER,
        amount REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> addCustomer(String name, String phone) async {
    await (await database).insert('customers', {
      'name': name, 'phone': phone, 'created_at': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, Object?>>> customers() async =>
      (await database).query('customers', orderBy: 'name COLLATE NOCASE');

  Future<List<Map<String, Object?>>> customerDebts() async =>
      (await database).query('customer_debts', orderBy: 'created_at DESC');

  Future<void> recordCustomerDebtPayment(int debtId, double amount, String note) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('customer_debts', where: 'id=?', whereArgs: [debtId]);
      if (rows.isEmpty) throw Exception('Deni halijapatikana');
      final row = rows.first;
      final balance = (row['amount'] as num) - (row['paid'] as num);
      if (amount <= 0 || amount > balance) throw Exception('Kiasi si sahihi. Deni lililobaki: $balance');
      await txn.insert('customer_debt_payments', {
        'debt_id': debtId, 'amount': amount, 'note': note,
        'created_at': DateTime.now().toIso8601String()
      });
      await txn.update('customer_debts', {'paid': (row['paid'] as num) + amount},
        where: 'id=?', whereArgs: [debtId]);
    });
  }

  Future<List<Map<String, Object?>>> supplierBalances() async {
    final db = await database;
    // Payments are kept in a separate ledger, so subtract them from each
    // supplier's purchase balance instead of reporting the pre-payment total.
    return db.rawQuery('''
      SELECT p.supplier_name AS name,
        COALESCE(SUM(p.total), 0) AS purchased,
        COALESCE(SUM(p.paid), 0) + COALESCE((
          SELECT SUM(sp.amount) FROM supplier_payments sp
          WHERE lower(trim(sp.supplier_name)) = lower(trim(p.supplier_name))
        ), 0) AS paid,
        MAX(0, COALESCE(SUM(p.total), 0) - COALESCE(SUM(p.paid), 0) - COALESCE((
          SELECT SUM(sp.amount) FROM supplier_payments sp
          WHERE lower(trim(sp.supplier_name)) = lower(trim(p.supplier_name))
        ), 0)) AS balance
      FROM purchases p
      GROUP BY p.supplier_name
      ORDER BY p.supplier_name COLLATE NOCASE
    ''');
  }

  Future<void> addSupplierPayment(String supplierName, double amount, String note) async {
    final db = await database;
    if (supplierName.trim().isEmpty || amount <= 0) throw Exception('Taarifa za malipo si sahihi');
    await db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT COALESCE(SUM(total-paid), 0) AS outstanding
        FROM purchases WHERE lower(trim(supplier_name)) = lower(trim(?))
      ''', [supplierName]);
      final previousPayments = await txn.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS paid
        FROM supplier_payments WHERE lower(trim(supplier_name)) = lower(trim(?))
      ''', [supplierName]);
      final outstanding = (rows.first['outstanding'] as num) - (previousPayments.first['paid'] as num);
      if (outstanding <= 0 || amount > outstanding) {
        throw Exception('Malipo yanazidi deni lililobaki: ${outstanding < 0 ? 0 : outstanding}');
      }
      await txn.insert('supplier_payments', {
        'supplier_name': supplierName.trim(), 'amount': amount, 'note': note,
        'created_at': DateTime.now().toIso8601String()
      });
      await txn.insert('audit_log', {
        'action': 'SUPPLIER_PAYMENT', 'details': '$supplierName: $amount',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> supplierPayments() async =>
      (await database).query('supplier_payments', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> batchList() async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.*, m.name AS medicine_name FROM medicine_batches b
      JOIN medicines m ON m.id=b.medicine_id
      WHERE b.quantity > 0 ORDER BY
      CASE WHEN b.expiry_date IS NULL OR b.expiry_date='' THEN 1 ELSE 0 END,
      b.expiry_date ASC
    ''');
  }

  Future<List<Map<String, Object?>>> suppliers() async =>
      (await database).query('suppliers', orderBy: 'name COLLATE NOCASE');

  Future<void> addSupplier(String name, String phone, String address) async {
    final db = await database;
    await db.insert('suppliers', {
      'name': name, 'phone': phone, 'address': address,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('audit_log', {
      'action': 'ADD_SUPPLIER', 'details': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> receivePurchase({
    required String supplierName,
    required int medicineId,
    required String medicineName,
    required String batchNo,
    required String expiryDate,
    required int quantity,
    required double unitCost,
    required double paid,
  }) async {
    if (quantity <= 0 || unitCost < 0 || paid < 0 || paid > quantity * unitCost) throw Exception('Taarifa za manunuzi si sahihi: malipo hayawezi kuzidi jumla ya manunuzi');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('medicines', where: 'id=?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw Exception('Dawa haijapatikana');
      final oldQty = rows.first['quantity'] as int;
      final total = quantity * unitCost;
      await txn.insert('purchases', {
        'supplier_name': supplierName, 'medicine_id': medicineId,
        'medicine_name': medicineName, 'batch_no': batchNo,
        'expiry_date': expiryDate, 'quantity': quantity,
        'unit_cost': unitCost, 'total': total, 'paid': paid,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('medicine_batches', {
        'medicine_id': medicineId, 'batch_no': batchNo, 'expiry_date': expiryDate,
        'quantity': quantity, 'unit_cost': unitCost,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.update('medicines', {
        'quantity': oldQty + quantity,
        'cost_price': unitCost,
        'batch_no': batchNo,
        'expiry_date': expiryDate,
      }, where: 'id=?', whereArgs: [medicineId]);
      await txn.insert('audit_log', {
        'action': 'PURCHASE_RECEIVED',
        'details': '$medicineName +$quantity from $supplierName',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> purchases() async =>
      (await database).query('purchases', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> expenses() async =>
      (await database).query('expenses', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> expiringMedicines({int days = 90}) async {
    final cutoff = DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return (await database).query('medicines',
      where: "expiry_date IS NOT NULL AND expiry_date != '' AND expiry_date <= ?",
      whereArgs: [cutoff], orderBy: 'expiry_date ASC');
  }

  String _hashCredential(String value, String salt) =>
      sha256.convert(utf8.encode('$value:$salt')).toString();

  Future<bool> verifyPassword(String username, String password) async {
    final db = await database;
    final rows = await db.query('app_users', where: 'username=?', whereArgs: [username]);
    if (rows.isEmpty) return false;
    final stored = rows.first['password_hash'] as String;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _hashCredential(password, parts[0]) == parts[1];
  }

  Future<bool> verifyPin(String username, String pin) async {
    final db = await database;
    final rows = await db.query('app_users', where: 'username=?', whereArgs: [username]);
    if (rows.isEmpty) return false;
    final stored = rows.first['pin_hash'] as String;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _hashCredential(pin, parts[0]) == parts[1];
  }

  Future<void> changeCredentials({
    required String username,
    String? newPassword,
    String? newPin,
  }) async {
    final db = await database;
    final rows = await db.query('app_users', where: 'username=?', whereArgs: ['admin']);
    if (rows.isEmpty) throw Exception('Admin account not found');
    final old = rows.first;
    final currentPassword = old['password_hash'] as String;
    final currentPin = old['pin_hash'] as String;
    String make(String value) {
      final salt = base64Encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
      return '$salt:${_hashCredential(value, salt)}';
    }
    await db.update('app_users', {
      'username': username,
      'password_hash': newPassword == null || newPassword.isEmpty ? currentPassword : make(newPassword),
      'pin_hash': newPin == null || newPin.isEmpty ? currentPin : make(newPin),
    }, where: 'id=?', whereArgs: [old['id']]);
    await db.insert('audit_log', {
      'action': 'ADMIN_CREDENTIALS_CHANGED',
      'details': 'Admin login credentials updated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

}
