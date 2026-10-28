import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_explainer.dart';
import 'package:fat_app/menu/menu_interpreter.dart';
import 'package:fat_app/menu/menu_models.dart';
import 'package:fat_app/menu/menu_share.dart';

/// Share / Save for the menu reader — mirrors iOS MenuShareTests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MenuGlossary g;
  late MenuResult result;

  setUpAll(() async {
    g = await MenuClaimExplainer.loadGlossary();
    final pages = jsonDecode(File('test/fixtures/menu/menu_ocr_pv.json').readAsStringSync()) as List;
    result = MenuInterpreter(g).interpret([
      for (final p in pages)
        MenuPage(p['index'] as int, [
          for (final l in p['lines'] as List)
            () {
              final b = l['box'] as List;
              final x = (b[0][0] as num).toDouble(), y = (b[0][1] as num).toDouble();
              final w = (b[1][0] as num).toDouble(), h = (b[1][1] as num).toDouble();
              return MenuOCRLine(l['text'] as String, Rect.fromLTRB(x, y, x + w, y + h));
            }()
        ])
    ]);
  });

  test('share text lists every dish with claims, notes and questions', () {
    final text = MenuShare.text(result, g);
    expect(text.startsWith('RESTAURANT MENU — SOURCING WORDS AND QUESTIONS\n'), isTrue);
    expect(text, contains(MenuShare.summary(result, g)));
    for (final item in result.visibleItems) {
      expect(text, contains(item.dishName));
    }
    expect(text, contains('Sourcing words: farm-raised, sustainable'));
    expect(text, contains('No sourcing claim on the menu'));
    expect(text, contains('Also explained: caviar'));
    expect(text, contains('   • Are the oysters wild or farmed'));
    expect(text, contains('The kitchen’s answers are the disclosure.'));
    expect(text, contains(MenuShare.appURL));
  });

  test('dismissed dishes are left out of the write-up', () {
    final item = result.items.firstWhere((i) => i.dishName.toUpperCase().startsWith('OYSTERS'));
    item.dismissed = true;
    expect(MenuShare.text(result, g), isNot(contains('OYSTERS ON THE HALF SHELL')));
    item.dismissed = false;
  });

  test('a saved menu round-trips through JSON', () {
    final rec = MenuRecord(id: 'x1', savedAt: DateTime(2026, 10, 28), result: result, imagePaths: ['/a.jpg']);
    final back = MenuRecord.fromMap(jsonDecode(jsonEncode(rec.toMap())) as Map<String, dynamic>);
    expect(back.id, 'x1');
    expect(back.imagePaths, ['/a.jpg']);
    expect(back.result.items.map((i) => i.dishName), result.items.map((i) => i.dishName));
    expect(MenuShare.text(back.result, g, date: DateTime(2026, 10, 28)),
        MenuShare.text(result, g, date: DateTime(2026, 10, 28)));
    expect(back.title.toUpperCase().startsWith('OYSTERS ON THE HALF SHELL'), isTrue);
  });

  test('read tips cover sections, angle, light and screenshots', () {
    final all = MenuReadTips.tips.map((t) => '${t.$2} ${t.$3}').join(' ').toLowerCase();
    for (final w in ['section', 'flat', 'glare', 'screenshot', 'six pages', 'swipe']) {
      expect(all, contains(w));
    }
  });
}
