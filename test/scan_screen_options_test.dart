import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/screens/scan_screen.dart';

/// The Scan tab must offer every camera-based scan in the app, with the
/// packaged-label scan as the primary action. Mirrors iOS ScanOptionTests.
void main() {
  testWidgets('Scan screen shows every scan option row', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ScanScreen(autoLaunch: false, onAutoLaunchConsumed: () {}),
    ));

    expect(ScanOption.values,
        [ScanOption.label, ScanOption.looseSeafood, ScanOption.menu]);
    for (final option in ScanOption.values) {
      expect(find.byKey(Key('scanOption.${option.name}')), findsOneWidget,
          reason: option.name);
      expect(find.text(option.title), findsOneWidget, reason: option.name);
      expect(find.text(option.description), findsOneWidget,
          reason: option.name);
    }
    // Scan Label stays the primary (filled) button.
    expect(
      find.ancestor(
        of: find.text('Scan Label'),
        matching: find.byType(ElevatedButton),
      ),
      findsOneWidget,
    );
  });
}
