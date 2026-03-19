// Basic smoke test — just ensures the app widget tree builds without crashing.
import 'package:flutter_test/flutter_test.dart';
import 'package:stickman_physics/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const StickmanApp());
  });
}
