import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_explainer.dart';
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

  test('phone OCR: Filet Mignon read and caviar species shown', () {
    final r = interpreter.interpret(fixture('phone_lb'));
    expect(names(r), contains('filet mignon'));
    expect(names(r).any((n) => n.contains('fit no')), isFalse);
    final caviar = r.items.firstWhere((i) => i.dishName == 'Caviar');
    expect(caviar.claims.firstWhere((c) => c.entryKey == 'caviar').matchedText.toLowerCase(), 'osetra');
  });

  test('phone OCR: Cote has no Korean junk', () {
    final r = interpreter.interpret(fixture('phone_cote'));
    final text = r.items.map((i) => '${i.dishName} ${i.description}').join(' | ');
    for (final junk in ['encerioin', 'Petrossian sai', '0|0122181', 'п|ор', '₫', 'Hvbrid', '.02', 'Miyazaki AS']) {
      expect(text.contains(junk), isFalse, reason: 'junk "$junk"');
    }
    expect(names(r), containsAll(['tenderloin', 'beluga hybrid']));
  });

  test('OCR merge replaces Latin junk with the CJK line', () {
    final latin = [
      MenuOCRLine('Miyazaki Prefecture.п|ор7|7|₫ A5', const Rect.fromLTRB(0.6, 0.5, 0.9, 0.52)),
      MenuOCRLine('Ribeye 38/oz', const Rect.fromLTRB(0.6, 0.47, 0.9, 0.49)),
    ];
    final cjk = [MenuOCRLine('Miyazaki Prefecture..미야자키현 A5 와규', const Rect.fromLTRB(0.6, 0.5, 0.91, 0.52))];
    final m = MenuOCRMerge.merge(latin, cjk);
    expect(m.length, 2);
    expect(m.any((l) => l.text.contains('₫')), isFalse);
    expect(MenuText.dropForeignScript('Miyazaki Prefecture..미야자키현 A5 와규'), 'Miyazaki Prefecture.. A5');
  });

  test('tiles split a wide page at its gutter', () {
    final lines = <MenuOCRLine>[];
    for (var i = 0; i < 20; i++) {
      final y = 0.9 - i * 0.04;
      lines.add(MenuOCRLine('Left $i', Rect.fromLTRB(0.05, y, 0.4, y + 0.02)));
      lines.add(MenuOCRLine('Right $i', Rect.fromLTRB(0.6, y, 0.95, y + 0.02)));
    }
    expect(MenuOCRMerge.tiles(lines, 3600, 2400).length, 4);
    expect(MenuOCRMerge.tiles(lines, 1000, 1400).length, 1);
  });

  test('a species word is a note, not a sourcing claim', () {
    final g = MenuGlossary.fromJson(
        jsonDecode(File('assets/data/menu_claim_glossary.json').readAsStringSync()) as Map<String, dynamic>);
    final r = MenuInterpreter(g).interpret([MenuPage.fromPlainText('Tuna\nLayers of Thinly Pounded Yellowfin Tuna\n\nWild Atlantic Black Bass 58')]);
    final tuna = r.items.firstWhere((i) => i.dishName == 'Tuna');
    expect(MenuClaimExplainer.hasSourcingClaim(tuna, g), isFalse);
    expect(MenuClaimExplainer.cards(tuna, g, null).first.title, 'No sourcing claim');
    final bass = r.items.firstWhere((i) => i.dishName.contains('Black Bass'));
    expect(MenuClaimExplainer.hasSourcingClaim(bass, g), isTrue);
  });

  test('A5 misreads, regions and sizes', () {
    expect(MenuText.fixCommonMisreads('As WAGYU'), 'A5 WAGYU');
    expect(MenuText.fixCommonMisreads('Miyazaki AS'), 'Miyazaki A5');
    expect(MenuText.fixCommonMisreads('as tender as wagyu, they say'), 'as tender as wagyu, they say');
    final r = run('Ice-chilled East/West Coast oysters 5/pc\n\nU10 Diver scallop 18/pc');
    final oysters = r.items.firstWhere((i) => i.dishName.contains('oysters'));
    expect(oysters.claims.any(MenuClaimExplainer.isNamedSource), isFalse);
    final scallop = r.items.firstWhere((i) => i.dishName.contains('scallop'));
    expect(scallop.claims.any((c) => c.matchedText.toLowerCase() == 'u10'), isFalse);
    expect(scallop.claims.any((c) => c.matchedText.toLowerCase() == 'diver'), isTrue);
  });

  test('fresh, foie gras, bap and grand cru are not sourcing claims', () {
    final g = MenuGlossary.fromJson(
        jsonDecode(File('assets/data/menu_claim_glossary.json').readAsStringSync()) as Map<String, dynamic>);
    final r = MenuInterpreter(g).interpret([
      MenuPage.fromPlainText('Tuna\nLayers of Yellowfin Tuna, Foie Gras, Toasted Baguette\n\nRed Snapper\n'
          'Whole Red Snapper Baked in Fresh Herbes\n\nOyster Sot-bap\nTongyeong oyster, Golden Queen rice\n\nGrand Cru Galbi 78')
    ]);
    for (final name in ['Tuna', 'Red Snapper', 'Oyster Sot-bap', 'Grand Cru Galbi']) {
      final d = r.items.firstWhere((i) => i.dishName == name);
      expect(MenuClaimExplainer.hasSourcingClaim(d, g), isFalse, reason: name);
    }
  });
}
