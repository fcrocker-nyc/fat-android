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
///   menu_fine_dining_expected.json — dish → species → add-on species → claims
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
    expect(card.meaning, contains('no standard for seafood'));
    expect(card.meaning, isNot(contains('7 CFR Part 205')));
    final chicken = interpreter.interpret([MenuPage.fromPlainText('Organic Roast Chicken 32')]).items.first;
    final meatCard = MenuClaimExplainer.cards(chicken, glossary, null).firstWhere((c) => c.entry?.key == 'organic');
    expect(meatCard.meaning, contains('7 CFR Part 205'));
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
