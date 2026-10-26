import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_explainer.dart';
import 'package:fat_app/menu/menu_interpreter.dart';
import 'package:fat_app/menu/menu_models.dart';
import 'package:fat_app/menu/menu_screens.dart';

/// "Ask about this dish": the ranked 2–3 questions per dish on the
/// fine-dining fixture. test/menu_fine_dining_questions_expected.json is
/// byte-identical to the iOS copy (FATAppMVP2Tests/), so both apps produce the
/// same questions for the same menu.
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

  MenuResult ocrResult() {
    final f = jsonDecode(File('test/menu_fine_dining_ocr.json').readAsStringSync()) as Map<String, dynamic>;
    return interpreter.interpret([
      MenuPage(0, [
        for (final l in (f['lines'] as List).cast<Map<String, dynamic>>())
          MenuOCRLine(
            l['text'] as String,
            Rect.fromLTWH((l['x'] as num).toDouble(), (l['y'] as num).toDouble(),
                (l['w'] as num).toDouble(), (l['h'] as num).toDouble()),
          ),
      ]),
    ]);
  }

  MenuResult textResult() => interpreter
      .interpret([MenuPage.fromPlainText(File('test/menu_fine_dining.txt').readAsStringSync())]);

  List<Map<String, Object>> snapshot(MenuResult r) => [
        for (final i in r.items) {'dish': i.dishName, 'questions': MenuClaimExplainer.askQuestions(i, glossary)},
      ];

  final expected = jsonDecode(File('test/menu_fine_dining_questions_expected.json').readAsStringSync());

  List<String> qs(MenuResult r, String dish) =>
      MenuClaimExplainer.askQuestions(r.items.firstWhere((i) => i.dishName.contains(dish)), glossary);

  test('shared expectation: OCR fixture', () {
    final got = snapshot(ocrResult());
    expect(got, expected, reason: const JsonEncoder.withIndent('  ').convert(got));
  });

  test('shared expectation: plain-text fixture', () {
    final got = snapshot(textResult());
    expect(got, expected, reason: const JsonEncoder.withIndent('  ').convert(got));
  });

  test('organic salmon asks where it is farmed and who certified it, not wild or farmed', () {
    final q = qs(ocrResult(), 'SALMON');
    expect(q.any((s) => s.contains('Where is it farmed')), isTrue, reason: '$q');
    expect(q.any((s) => s.contains('who certified it organic')), isTrue, reason: '$q');
    for (final s in q) {
      expect(s.toLowerCase().contains('wild or farmed'), isFalse, reason: s);
    }
  });

  test('Crystal Valley chicken asks about the named source', () {
    final q = qs(ocrResult(), 'CRYSTAL VALLEY');
    expect(
        q.contains('Where is Crystal Valley located?') ||
            q.contains('Where does the chicken come from?'),
        isTrue,
        reason: '$q');
  });

  test('Thai vegetable stew asks about the lobster add-on', () {
    expect(qs(ocrResult(), 'THAI'), contains('If I add the lobster, where is it from?'));
  });

  test('every dish gets 1–3 questions, no near-duplicates', () {
    for (final r in [ocrResult(), textResult()]) {
      for (final i in r.items) {
        final q = MenuClaimExplainer.askQuestions(i, glossary);
        expect(q.length, inInclusiveRange(1, 3), reason: i.dishName);
        expect(q.toSet().length, q.length, reason: i.dishName);
        final countryQs = q.where((s) => s.toLowerCase().contains('country')).length;
        expect(countryQs, lessThanOrEqualTo(1), reason: i.dishName);
      }
    }
  });

  test('species fallback uses the bird word and the beef pair', () {
    final duck = interpreter.interpret([MenuPage.fromPlainText('Roast Duck Breast 38')]).items.first;
    expect(MenuClaimExplainer.askQuestions(duck, glossary), ['Where does the duck come from?']);
    final steak = interpreter.interpret([MenuPage.fromPlainText('Ribeye Steak 52')]).items.first;
    expect(MenuClaimExplainer.askQuestions(steak, glossary),
        ['Where does the beef come from?', 'Is it grass-fed or grain-finished?']);
  });

  test('related glossary questions merge into one', () {
    final shrimp = interpreter.interpret([MenuPage.fromPlainText('Garlic Shrimp 24')]).items.first;
    expect(MenuClaimExplainer.askQuestions(shrimp, glossary).first,
        'Is the shrimp wild or farmed, and which country is it from?');
  });

  testWidgets('row button opens the ask sheet without opening the dish', (tester) async {
    final r = ocrResult();
    await tester.pumpWidget(MaterialApp(home: MenuDishesScreen(result: r, glossary: glossary)));
    expect(find.text(MenuAskCopy.rowButton), findsWidgets);
    final salmon = r.items.firstWhere((i) => i.dishName.contains('SALMON'));
    final button = find.byKey(ValueKey('menu-ask-${salmon.id}'));
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(MenuAskCopy.showToServer), findsOneWidget);
    expect(find.text(MenuAskCopy.copy), findsOneWidget);
    expect(find.text(MenuAskCopy.moreAboutDish), findsOneWidget);
    for (final q in MenuClaimExplainer.askQuestions(salmon, glossary)) {
      expect(find.text(q), findsOneWidget);
    }
    // The dish screen was not pushed underneath.
    expect(find.byType(MenuDishScreen), findsNothing);

    await tester.tap(find.text(MenuAskCopy.showToServer));
    await tester.pumpAndSettle();
    expect(find.byType(MenuServerView), findsOneWidget);
    await tester.tap(find.byType(MenuServerView));
    await tester.pumpAndSettle();
    expect(find.byType(MenuServerView), findsNothing);
  });

  test('new sheet copy has no regulatory acronyms', () {
    final re = RegExp(r'\b(?:COOL|SIMP|AMS|FSIS|HACCP|NOP|PACA)\b');
    for (final s in [...MenuAskCopy.all, glossary.addOnAsk!, ...glossary.fallbackAsk.values.expand((v) => v)]) {
      expect(re.hasMatch(s), isFalse, reason: s);
    }
  });
}
