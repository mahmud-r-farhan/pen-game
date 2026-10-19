// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/main.dart';

void main() {
  testWidgets('Kolom Fight smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KolomFightApp());
    expect(find.byType(KolomFightApp), findsOneWidget);
  });
}
