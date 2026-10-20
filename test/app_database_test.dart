import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_cashier/data/app_database.dart';

void main() {
  // بنجهّز SQLite للاختبارات على الكمبيوتر بدل الاعتماد على Android.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDirectory;
  late AppDatabase db;

  // كل اختبار بياخد ملف قاعدة بيانات مستقل، علشان بيانات الاختبارات
  // ما تختلطش ببعض، والأهم ما تلمسش قاعدة بيانات التطبيق الحقيقية.
  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('smart_cashier_test_');

    db = AppDatabase.forTesting(
      databasePath: p.join(tempDirectory.path, 'test.db'),
    );

    // فتح الاتصال هنا بيشغّل إنشاء الجداول قبل تنفيذ الاختبار.
    await db.database;
  });

  // بنقفل الاتصال ونمسح ملفات الاختبار بعد كل حالة.
  tearDown(() async {
    await db.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> addSampleProduct({int quantity = 5}) {
    return db.saveProduct(
      barcode: '123456',
      name: 'منتج تجريبي',
      buyPrice: 8,
      sellPrice: 10,
      quantity: quantity,
    );
  }

  test('رفض تكرار الباركود من غير استبدال بيانات المنتج', () async {
    await addSampleProduct();

    await expectLater(
      addSampleProduct(quantity: 99),
      throwsA(isA<StateError>()),
    );

    final product = await db.productByBarcode('123456');

    expect(product, isNotNull);
    expect(product!['name'], 'منتج تجريبي');
    expect(product['buy_price'], 8);
    expect(product['sell_price'], 10);
    expect(product['quantity'], 5);
  });

  test('استلام بضاعة بيزوّد الكمية ويحافظ على بيانات المنتج', () async {
    await addSampleProduct();

    await db.receiveStock(barcode: '123456', quantity: 3);

    final product = await db.productByBarcode('123456');

    expect(product, isNotNull);
    expect(product!['quantity'], 8);
    expect(product['name'], 'منتج تجريبي');
    expect(product['buy_price'], 8);
    expect(product['sell_price'], 10);
  });

  test('بيع وحدتين يحسب الإيراد والتكلفة والربح ويحفظ أسعار وقت البيع',
      () async {
    await addSampleProduct();

    await db.completeSale(
      items: [
        {'barcode': '123456', 'quantity': 2},
      ],
      paid: 20,
    );

    final database = await db.database;
    final sales = await database.query('sales');
    final saleItems = await database.query('sale_items');
    final product = await db.productByBarcode('123456');

    expect(sales, hasLength(1));
    expect(sales.single['total'], 20);
    expect(sales.single['cost'], 16);
    expect(sales.single['profit'], 4);

    expect(saleItems, hasLength(1));
    expect(saleItems.single['buy_price'], 8);
    expect(saleItems.single['sell_price'], 10);
    expect(saleItems.single['quantity'], 2);

    expect(product!['quantity'], 3);

    // تغيير سعر الشراء الحالي بعد البيع ما يغيّرش تكلفة الفاتورة القديمة.
    await database.update(
      'products',
      {'buy_price': 9},
      where: 'barcode = ?',
      whereArgs: ['123456'],
    );

    final savedSale = await database.query('sales');
    final savedItem = await database.query('sale_items');

    expect(savedSale.single['cost'], 16);
    expect(savedSale.single['profit'], 4);
    expect(savedItem.single['buy_price'], 8);
  });

  test('رفض بيع كمية أكبر من المخزون من غير تسجيل فاتورة', () async {
    await addSampleProduct(quantity: 1);

    await expectLater(
      db.completeSale(
        items: [
          {'barcode': '123456', 'quantity': 2},
        ],
        paid: 20,
      ),
      throwsA(isA<StateError>()),
    );

    final database = await db.database;
    final sales = await database.query('sales');
    final product = await db.productByBarcode('123456');

    expect(sales, isEmpty);
    expect(product!['quantity'], 1);
  });
}
