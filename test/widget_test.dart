import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cashier/main.dart';

void main() {
  testWidgets('التطبيق يعرض عنوان كاشير المحل الذكي', (tester) async {
    await tester.pumpWidget(const SmartCashierApp());
    expect(find.text('كاشير المحل الذكي'), findsOneWidget);
  });
}
