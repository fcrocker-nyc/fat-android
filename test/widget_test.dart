import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FATApp());
    expect(find.text('Home'), findsOneWidget);
  });
}
