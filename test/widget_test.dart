import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_cashier/main.dart';

void main() {
  // بنجهّز SQLite عشان الاختبارات بتشتغل على الكمبيوتر،
  // مش على Android اللي بيجهّز محرك قاعدة البيانات تلقائيًا.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('التطبيق يعرض عنوان كاشير المحل الذكي', (tester) async {
    // بنعرض التطبيق الحقيقي ونتأكد إن عنوانه ظاهر.
    await tester.pumpWidget(const SmartCashierApp());

    // بنسيب أول دورة من الواجهة تشتغل عشان العنوان يظهر.
    await tester.pump();

    expect(find.text('كاشير المحل الذكي'), findsOneWidget);
  });
}
