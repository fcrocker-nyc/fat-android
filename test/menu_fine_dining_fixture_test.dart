import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_explainer.dart';
import 'package:fat_app/menu/menu_interpreter.dart';
import 'package:fat_app/menu/menu_models.dart';

/// Real-world fine-dining menu (user photo, Oct 2026). Two fixtures share one
/// expectation file with the iOS suite (FATAppMVP2Tests/menu_fine_dining_*):
///   menu_fine_dining_ocr.json      — true Apple Vision OCR lines + boxes
///   menu_fine_dining.txt           — the same menu as plain text (letter-spaced header)
///   menu_fine_dining_expected.json — dish → species → add-on species → claims → row tags
/// Keep the three files byte-identical across the two repos.
void main() {
  late MenuGlossary glossary;
  late MenuInterpreter interpreter;

  setUpAll(() {
    glossary = MenuGlossary.fromJson(
      jsonDecode(File('assets/data/menu_claim_glossary.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    interpreter = MenuInterpreter(glossary);
  });

  MenuPage ocrPage() {
    final f = jsonDecode(File('test/menu_fine_dining_ocr.json').readAsStringSync()) as Map<String, dynamic>;
    return MenuPage(0, [
      for (final l in (f['lines'] as List).cast<Map<String, dynamic>>())
        MenuOCRLine(
          l['text'] as String,
          Rect.fromLTWH((l['x'] as num).toDouble(), (l['y'] as num).toDouble(),
              (l['w'] as num).toDouble(), (l['h'] as num).toDouble()),
        ),
    ]);
  }

  List<Map<String, Object>> snapshot(MenuResult r) => [
        for (final i in r.items)
          {
            'dish': i.dishName,
            'species': [for (final p in i.proteins) p.name],
            'addOnSpecies': [for (final p in i.addOnProteins) p.name],
            'addOns': i.addOns,
            'claims': [for (final c in i.claims) c.entryKey],
            'claimText': [for (final c in i.claims) c.matchedText.toLowerCase()],
            'tags': [for (final t in MenuClaimExplainer.tags(i)) t.text],
          }
      ];

  final expected = jsonDecode(File('test/menu_fine_dining_expected.json').readAsStringSync());

  void expectMatches(MenuResult r) {
    final got = snapshot(r);
    expect(got, expected, reason: const JsonEncoder.withIndent('  ').convert(got));
  }

  test('real Vision OCR matches the shared expectation', () {
    expectMatches(interpreter.interpret([ocrPage()]));
  });

  test('plain text matches the shared expectation', () {
    final text = File('test/menu_fine_dining.txt').readAsStringSync();
    expectMatches(interpreter.interpret([MenuPage.fromPlainText(text)]));
  });

  test('section headers and add-ons are never dishes', () {
    final r = interpreter.interpret([ocrPage()]);
    final names = r.items.map((i) => i.dishName.toUpperCase()).toList();
    for (final h in ['CLASSICS', 'SEASONAL', 'SIDES TO SHARE']) {
      expect(names.contains(h), isFalse, reason: h);
    }
    expect(names.any((n) => n.contains('SUPPLEMENT') || n.startsWith('(ADD')), isFalse);
    final stew = r.items.firstWhere((i) => i.dishName.contains('THAI'));
    expect(stew.proteins, [ProteinFamily.shellfish]);
    expect(stew.addOnProteins, [ProteinFamily.shellfish]);
    expect(stew.addOns, ['Lobster']);
    final bouill = r.items.firstWhere((i) => i.dishName == 'BOUILLABAISSE');
    expect(bouill.proteins.toSet(), {ProteinFamily.finfish, ProteinFamily.shellfish});
  });

  test('organic on seafood uses seafood wording', () {
    final r = interpreter.interpret([ocrPage()]);
    final salmon = r.items.firstWhere((i) => i.dishName.contains('SALMON'));
    final card = MenuClaimExplainer.cards(salmon, glossary, null).firstWhere((c) => c.entry?.key == 'organic');
    expect(card.meaning, startsWith('USDA has no organic standard for seafood'));
    expect(card.meaning, contains('Organic salmon is farmed'));
    expect(card.meaning, isNot(contains('7 CFR Part 205')));
    expect(card.authority, 'No USDA standard (European/UK organic certification)');
    expect(card.gap, 'The menu doesn’t say where the fish was farmed or who certified it.');
    expect(card.questions,
        ['Where is it farmed?', 'Who certified it organic?', 'Is the feed organic, or the whole farm?']);
    final chicken = interpreter.interpret([MenuPage.fromPlainText('Organic Roast Chicken 32')]).items.first;
    final meatCard = MenuClaimExplainer.cards(chicken, glossary, null).firstWhere((c) => c.entry?.key == 'organic');
    expect(meatCard.meaning, contains('7 CFR Part 205'));
  });

  test('organic salmon is farmed, and wild belongs to the shrimp', () {
    final r = interpreter.interpret([ocrPage()]);
    final salmon = r.items.firstWhere((i) => i.dishName.contains('SALMON'));
    expect([for (final t in MenuClaimExplainer.tags(salmon)) t.text],
        ['organic', 'Named source: Glen Cairn', 'salmon (farmed)', 'tiger shrimp (wild)']);
    final farmed = salmon.claims.firstWhere((c) => c.entryKey == 'farm_raised');
    expect(farmed.inferred, isTrue);
    expect(farmed.subject, 'salmon');
    final wild = salmon.claims.firstWhere((c) => c.entryKey == 'wild_caught');
    expect(wild.subject, 'tiger shrimp');
    expect(wild.appliesTo, ProteinFamily.shellfish);
    final card = MenuClaimExplainer.cards(salmon, glossary, null).firstWhere((c) => c.entry?.key == 'farm_raised');
    expect(card.title, 'Farmed (not printed)');
    expect(card.meaning, startsWith('The menu doesn’t say farmed, but organic salmon is farmed.'));

    // Only salmon-type species; a word other than a named source in between blocks it.
    for (final text in ['Organic King Salmon 40', 'Organic Kale Salad with Salmon 30', 'Organic Roast Chicken 32']) {
      final item = interpreter.interpret([MenuPage.fromPlainText(text)]).items.first;
      expect(item.claims.any((c) => c.entryKey == 'farm_raised'), isFalse, reason: text);
    }
    final plain = interpreter.interpret([MenuPage.fromPlainText('Organic Salmon 38')]).items.first;
    expect([for (final t in MenuClaimExplainer.tags(plain)) t.text], ['organic', 'salmon (farmed)']);
  });

  test('named source cards', () {
    final r = interpreter.interpret([ocrPage()]);
    MenuClaimCard card(String dish) => MenuClaimExplainer.cards(
            r.items.firstWhere((i) => i.dishName.contains(dish)), glossary, null)
        .firstWhere((c) => c.entry?.key == 'menu_named_source');
    final glen = card('SALMON');
    expect(glen.title, 'Named source: Glen Cairn');
    expect(glen.meaning,
        'The menu names a farm, ranch, brand or place. FAT can’t verify where this name sources from.');
    expect(glen.questions, ['Where is Glen Cairn located?', 'Is it the farm itself, or a distributor’s brand?']);
    expect(glen.sourceNote,
        'Listed by U.S. distributor The Educated Fish Co. as EU-certified Scottish organic salmon (distributor’s claim, not verified by FAT).');
    for (final (dish, name) in [('CHICKEN', 'Crystal Valley'), ('DUCK', 'Crescent Farms'), ('PORTERHOUSE', 'Allen Brothers')]) {
      final c = card(dish);
      expect(c.title, 'Named source: $name', reason: dish);
      expect(c.sourceNote, isNull, reason: 'no curated facts for $name');
    }
    // The curated table also matches the one-word spelling, and only on salmon.
    final one = interpreter.interpret([MenuPage.fromPlainText('GLENCAIRN SALMON 38')]).items.first;
    expect(one.claims.firstWhere((c) => c.entryKey == 'menu_named_source').matchedText, 'GLENCAIRN');
    expect(glossary.knownSource('Glen Cairn', 'chicken'), isNull);
  });

  test('named source heuristic false positives', () {
    List<String> names(String title) => [
          for (final i in interpreter.interpret([MenuPage.fromPlainText(title)]).items)
            for (final c in i.claims)
              if (c.entryKey == 'menu_named_source') c.matchedText
        ];
    expect(names('OVEN ROASTED CHICKEN'), isEmpty);
    expect(names('OVEN ROASTED CRYSTAL VALLEY CHICKEN (GF)'), ['CRYSTAL VALLEY']);
    expect(names('PROVENÇALE CRUSTED RACK OF LAMB*'), isEmpty);
    expect(names('PROVENÇALE CRUSTED SALMON'), isEmpty);
    expect(names('GRILLED BLACK ANGUS FILET MIGNON* (GF)'), isEmpty, reason: 'Black Angus is a breed claim');
    expect(names('SPAGHETTI AL NERO FRUTTI DI MARE'), isEmpty);
    expect(names('Spaghetti al Nero, calamari, shrimp'), isEmpty);
    expect(names('GRILLED PRIME ALLEN BROTHERS PORTERHOUSE FOR TWO* 32oz (GF)'), ['ALLEN BROTHERS']);
    expect(names('Royal Osetra Caviar 180'), isEmpty, reason: 'one word at the start of a title is not enough');
    expect(names('Jumbo Lump Crab Cakes 24'), isEmpty);
    expect(names('Half Roast Chicken 29'), isEmpty);
    expect(names('Roast Chicken 32\nCrystal Valley mushrooms, jus'), isEmpty, reason: 'descriptions are not read');
  });

  test('species word beats dish default', () {
    expect(MenuProteinClassifier.classify('CAVATELLI PASTA, BERKSHIRE PORK OSSO BUCO RAGU').proteins,
        [ProteinFamily.pork]);
    expect(MenuProteinClassifier.classify('Osso Buco, saffron risotto').proteins, [ProteinFamily.beef]);
    expect(MenuProteinClassifier.classify('Pappardelle, lamb ragù').proteins, [ProteinFamily.lamb]);
    expect(MenuProteinClassifier.classify('Tagliatelle Bolognese').proteins.toSet(),
        {ProteinFamily.beef, ProteinFamily.pork});
  });

  test('letter-spaced header', () {
    expect(MenuText.sectionHeader('C L A S S I C S'), 'CLASSICS');
    expect(MenuText.sectionHeader('S I D E S  T O  S H A R E'), 'SIDES TO SHARE');
    expect(MenuText.sectionHeader('BOUILLABAISSE'), isNull);
  });
}
