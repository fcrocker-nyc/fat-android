import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_interpreter.dart';
import 'package:fat_app/menu/menu_models.dart';

/// Dish segmentation on real fine-dining menus — mirrors the iOS
/// MenuSegmentationTests. Fixtures are saved OCR (text + Vision boxes) of the
/// published menus of Le Bernardin, Providence, Atomix and Cote (Oct 2026),
/// shared byte-for-byte with the iOS test target.
void main() {
  late MenuInterpreter interpreter;

  setUpAll(() {
    final g = MenuGlossary.fromJson(
        jsonDecode(File('assets/data/menu_claim_glossary.json').readAsStringSync()) as Map<String, dynamic>);
    interpreter = MenuInterpreter(g);
  });

  List<MenuPage> fixture(String name) {
    final pages = jsonDecode(File('test/fixtures/menu/menu_ocr_$name.json').readAsStringSync()) as List;
    return [
      for (final p in pages)
        MenuPage(p['index'] as int, [
          for (final l in p['lines'] as List)
            () {
              // Swift CGRect encodes as [[x, y], [w, h]] with a bottom-left origin.
              final b = l['box'] as List;
              final x = (b[0][0] as num).toDouble(), y = (b[0][1] as num).toDouble();
              final w = (b[1][0] as num).toDouble(), h = (b[1][1] as num).toDouble();
              return MenuOCRLine(l['text'] as String, Rect.fromLTRB(x, y, x + w, y + h));
            }()
        ])
    ];
  }

  List<String> names(MenuResult r) => r.items.map((i) => i.dishName.toLowerCase()).toList();

  void expectFinds(List<String> expected, MenuResult r) {
    final got = names(r);
    for (final e in expected) {
      expect(got, contains(e.toLowerCase()), reason: 'missing "$e". Got: $got');
    }
  }

  MenuResult run(String text) => interpreter.interpret([MenuPage.fromPlainText(text)]);

  test('Le Bernardin: four centered columns', () {
    final r = interpreter.interpret(fixture('lb'));
    expectFinds(['Caviar', 'Oysters', 'Oyster-Uni', 'Tuna', 'Hamachi', 'Gamberoni Rosso', 'Shima-aji',
      'Black Cod', 'Calamari', 'Trout', 'Dover Sole', 'Salmon', 'Skate', 'Striped Bass', 'Halibut',
      'Merluza', 'Filet Mignon', 'Duck', 'Red Snapper'], r);
    expect(names(r), isNot(contains('lightly cooked')));
    expect(names(r), isNot(contains('upon request')));
    expect(r.items.any((i) => i.description.contains('Upon Request')), isFalse);
  });

  test('Providence: tasting menu with OR choices and a price strip', () {
    final r = interpreter.interpret(fixture('pv'));
    expectFinds(['Oysters on the half shell', 'Farm-raised, sustainable caviar', 'Uni egg', 'Kaluga caviar',
      'Sashimi', 'Scallop', 'King crab', 'Black bass', 'Monkfish', 'Liberty Farms duck', 'A5 Wagyu'], r);
    expect(names(r), isNot(contains('or')));
    expect(r.layoutUncertain, isFalse);
  });

  test('Atomix: one line per course', () {
    final r = interpreter.interpret(fixture('atomix'));
    expect(names(r), ['pacific saury', 'littleneck clam', 'razor clam', 'sea urchin', 'kohlrabi', 'abalone',
      'golden eye snapper', 'lobster', 'lamb saddle']);
    expect(r.items.firstWhere((i) => i.dishName == 'Lobster').description, contains('Lobster jeotgal rice'));
  });

  test('Cote: dense multi-band layout', () {
    final r = interpreter.interpret(fixture('cote'));
    expectFinds(['Shrimp Cocktail', 'Wedge Salad', 'Caviar Service', 'Steak Tartare', 'Tuna Tartare',
      'Hanger Steak', 'Skirt Steak', 'Filet Mignon', 'Dry Aged Ribeye', 'Kobe (Hyogo Prefecture)'], r);
    expect(r.items.firstWhere((i) => i.dishName == 'Shrimp Cocktail').description, contains('chilled prawn'));
    expect(r.headerStatements, isEmpty);
  });

  test('OR line separates choices', () {
    expect(names(run('MONKFISH\nchanterelle\nOR\nDUCK\napricot')), ['monkfish', 'duck']);
  });

  test('wine pairing lines ignored', () {
    final r = run('Chilled Maine Lobster Tail\nwith Passionfruit and Lime\n'
        'Linden, Petit Manseng, Virginia (2020)\nBillecart-Salmon, Brut Rosé (N.V)');
    expect(r.items.length, 1);
    expect(r.items.first.description, isNot(contains('Linden')));
    expect(r.items.first.proteins, isNot(contains(ProteinFamily.finfish)));
  });

  test('comma line splits into name and components', () {
    final r = run('Pacific saury*, Gim bugak, Perilla\n\nLamb saddle, Neungi mushroom, Dubu');
    expect(names(r), ['pacific saury', 'lamb saddle']);
    expect(r.items.first.description, 'Gim bugak, Perilla');
  });

  test('section word followed by a description is a dish', () {
    expect(names(run('KALUGA CAVIAR\ncountry ham, giant clam\nSASHIMI\npear, celtuce, yuzu')),
        ['kaluga caviar', 'sashimi']);
  });

  test('per-unit price and fragment description', () {
    expect(MenuText.hasTrailingPrice('Shrimp Cocktail* | 5/pc'), isTrue);
    expect(MenuText.isPriceOnly('145/oz'), isTrue);
    expect(names(run('Shrimp Cocktail* | 5/pc\n\nSoft poached and chilled prawn,\ngochujang cocktail sauce')),
        ['shrimp cocktail']);
  });

  test('prose paragraph is not a dish', () {
    final r = run('Black Angus is the dominant beef breed in the United States. It is known for\n'
        'marbling and flavor. American Wagyu is a hybrid of Japanese Wagyu and Angus.\n'
        'Our cattle are raised in Nebraska and Georgia on family farms.\n\nHanger Steak 38');
    expect(names(r), ['hanger steak']);
  });

  test('clean title and junk', () {
    expect(MenuText.cleanTitle('• American Wagyu •'), 'American Wagyu');
    expect(MenuText.cleanTitle('1 COTE Galbi'), 'COTE Galbi');
    expect(MenuText.cleanTitle('A5 WAGYU'), 'A5 WAGYU');
    expect(MenuText.isJunkTitle('O0'), isTrue);
    expect(MenuText.isJunkTitle('18/pc'), isTrue);
    expect(MenuText.isJunkTitle('U10 Diver scallop'), isFalse);
  });

  test('wine lines without a vintage are ignored', () {
    expect(MenuSegmenter.isWinePairing('1 Didier Dagueneau, Les Jardins de Babylone, Demi-Sec, Jurançon, France,'), isTrue);
    expect(MenuSegmenter.isWinePairing('11 Billecart-Salmon, Cuvée Elisabeth Salmon, Brut Rosé, Champagne, France'), isTrue);
    expect(MenuSegmenter.isWinePairing('sea urchin, champagne beurre blanc, brioche croutons'), isFalse);
    expect(MenuSegmenter.isWinePairing('Iceberg lettuce, bacon, tomato'), isFalse);
    final r = run('Chilled Maine Lobster Tail\nwith Passionfruit and Lime\n'
        '11 Billecart-Salmon, Cuvée Elisabeth Salmon, Brut Rosé, Champagne, France');
    expect(names(r), ['chilled maine lobster tail']);
    expect(r.items.first.proteins, isNot(contains(ProteinFamily.finfish)));
  });

  test('grass-fed on a beef cut', () {
    final r = run('Steak Tartare* | 29\nLocal grass-fed top-round, pear, crispy tendon puffs');
    expect(r.items.first.claims.map((c) => c.entryKey), contains('grass_fed'));
  });
}
