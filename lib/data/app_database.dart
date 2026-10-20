import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// قاعدة البيانات المحلية: المنتجات والفواتير وبنود الفواتير والحركات المالية.
/// بنستخدم SQLite بدل localStorage عشان البيانات تبقى مناسبة لتطبيق Android
/// وتفضل موجودة بعد قفل التطبيق أو إعادة تشغيل الموبايل.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getDatabasesPath();
    _database = await openDatabase(
      p.join(directory, 'smart_cashier.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            barcode TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            buy_price REAL NOT NULL CHECK(buy_price >= 0),
            sell_price REAL NOT NULL CHECK(sell_price >= 0),
            quantity INTEGER NOT NULL CHECK(quantity >= 0),
            low_stock_threshold INTEGER NOT NULL DEFAULT 5
          )
        ''');
        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            total REAL NOT NULL,
            cost REAL NOT NULL,
            profit REAL NOT NULL,
            paid REAL NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sale_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            barcode TEXT NOT NULL,
            product_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            buy_price REAL NOT NULL,
            sell_price REAL NOT NULL,
            FOREIGN KEY(sale_id) REFERENCES sales(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE cash_movements(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            note TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  /// حفظ أو تعديل المنتج حسب الباركود؛ الإدخال والتعديل في عملية واحدة.
  Future<void> saveProduct({
    required String barcode,
    required String name,
    required double buyPrice,
    required double sellPrice,
    required int quantity,
    int lowStockThreshold = 5,
  }) async {
    final db = await database;
    await db.insert(
      'products',
      {
        'barcode': barcode.trim(),
        'name': name.trim(),
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'quantity': quantity,
        'low_stock_threshold': lowStockThreshold,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> products({String search = ''}) async {
    final db = await database;
    return db.query(
      'products',
      where: search.isEmpty ? null : 'name LIKE ? OR barcode LIKE ?',
      whereArgs: search.isEmpty ? null : ['%$search%', '%$search%'],
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<Map<String, Object?>?> productByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// حفظ الفاتورة وخصم المخزون داخل transaction واحدة.
  /// لو أي بند كميته غير متاحة، العملية كلها تتراجع بدل ما نحفظ فاتورة ناقصة.
  Future<int> completeSale({
    required List<Map<String, Object?>> items,
    required double paid,
    String? note,
  }) async {
    if (items.isEmpty) throw ArgumentError('الفاتورة فاضية');
    final db = await database;

    return db.transaction<int>((txn) async {
      double total = 0;
      double cost = 0;

      for (final item in items) {
        final code = item['barcode']! as String;
        final quantity = item['quantity']! as int;
        final rows = await txn.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [code],
          limit: 1,
        );
        if (rows.isEmpty) throw StateError('منتج غير موجود: $code');

        final product = rows.first;
        final stock = product['quantity']! as int;
        if (quantity < 1 || quantity > stock) {
          throw StateError('الكمية غير متاحة للمنتج: ${product['name']}');
        }

        final buy = (product['buy_price']! as num).toDouble();
        final sell = (product['sell_price']! as num).toDouble();
        total += sell * quantity;
        cost += buy * quantity;
      }

      final saleId = await txn.insert('sales', {
        'created_at': DateTime.now().toIso8601String(),
        'total': total,
        'cost': cost,
        'profit': total - cost,
        'paid': paid,
        'note': note,
      });

      for (final item in items) {
        final code = item['barcode']! as String;
        final quantity = item['quantity']! as int;
        final product = (await txn.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [code],
          limit: 1,
        )).first;

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'barcode': code,
          'product_name': product['name'],
          'quantity': quantity,
          'buy_price': product['buy_price'],
          'sell_price': product['sell_price'],
        });
        await txn.update(
          'products',
          {'quantity': (product['quantity']! as int) - quantity},
          where: 'barcode = ?',
          whereArgs: [code],
        );
      }
      return saleId;
    });
  }

  Future<void> addCashMovement({
    required String type,
    required double amount,
    String? note,
  }) async {
    final db = await database;
    await db.insert('cash_movements', {
      'created_at': DateTime.now().toIso8601String(),
      'type': type,
      'amount': amount,
      'note': note,
    });
  }

  Future<List<Map<String, Object?>>> todaySales() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    return db.query(
      'sales',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start, end],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> todayMovements() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    return db.query(
      'cash_movements',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start, end],
      orderBy: 'created_at DESC',
    );
  }
}
