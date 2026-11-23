// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/main.dart';

void main() {
  test('KolomFightApp class exists and can be instantiated', () {
    // Verify the main app widget can be created
    const app = KolomFightApp();
    expect(app, isNotNull);
    expect(app, isA<KolomFightApp>());
  });
}
