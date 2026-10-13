import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/screens/lookup_screen.dart';

void main() {
  Future<void> pumpLookup(WidgetTester tester) async {
    // Tall viewport so the lazily built sliver content below the card exists.
    tester.view.physicalSize = const Size(1170, 7500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LookupScreen()));
    await tester.pump();
  }

  testWidgets('Four ways to look up card shows 4 rows', (tester) async {
    await pumpLookup(tester);
    expect(find.text('Four ways to look up'), findsOneWidget);
    for (int i = 0; i < 4; i++) {
      expect(find.byKey(Key('lookupOverviewRow_$i')), findsOneWidget);
    }
    // Default mode is EST: its explainer is visible.
    expect(find.text('About the EST Lookup'), findsOneWidget);
  });

  testWidgets('Tapping an overview row switches mode', (tester) async {
    await pumpLookup(tester);
    await tester.tap(find.byKey(const Key('lookupOverviewRow_1')));
    await tester.pump();
    expect(find.text('Search Meat Brand or Company'), findsOneWidget);
    expect(find.text('About the EST Lookup'), findsNothing);

    await tester.tap(find.byKey(const Key('lookupOverviewRow_3')));
    await tester.pump();
    expect(find.text('Search FDA Seafood Enforcement'), findsOneWidget);
  });

  testWidgets('Picker uses short labels', (tester) async {
    await pumpLookup(tester);
    expect(find.text('Meat'), findsOneWidget);
    expect(find.text('Seafood'), findsOneWidget);
  });

  testWidgets('Overview card collapses', (tester) async {
    await pumpLookup(tester);
    await tester.tap(find.byKey(const Key('lookupOverviewToggle')));
    await tester.pump();
    expect(find.byKey(const Key('lookupOverviewRow_0')), findsNothing);
  });
}
