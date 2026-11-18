import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_explainer.dart';
import 'package:fat_app/menu/menu_interpreter.dart';
import 'package:fat_app/menu/menu_models.dart';
import 'package:fat_app/menu/menu_screens.dart';

/// "Ask about this dish": exactly two questions per dish on the fine-dining
/// fixture. test/menu_fine_dining_questions_expected.json and
/// test/menu_phrase_questions_expected.json are byte-identical to the iOS
/// copies (FATAppMVP2Tests/), so both apps ask the same questions for the same
/// menu and a deleted question can't come back unnoticed.
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

  List<String> ask(String text) => MenuClaimExplainer.askQuestions(
      interpreter.interpret([MenuPage.fromPlainText(text)]).items.first, glossary);

  // ── Question rules ──

  test('every dish gets two questions (one if add-on only), never two whys', () {
    for (final r in [ocrResult(), textResult()]) {
      for (final i in r.items) {
        final q = MenuClaimExplainer.askQuestions(i, glossary);
        // One question only for an add-on-only dish (no second applies).
        expect(q.length, i.dishName.startsWith('THAI') ? 1 : 2, reason: '${i.dishName}: $q');
        expect(q.toSet().length, q.length, reason: i.dishName);
        expect(q.where(MenuClaimExplainer.isWhyQuestion).length, lessThanOrEqualTo(1), reason: i.dishName);
        final countryQs = q.where((s) => s.toLowerCase().contains('country')).length;
        expect(countryQs, lessThanOrEqualTo(1), reason: i.dishName);
      }
    }
  });

  test('Berkshire pair is verbatim', () {
    const want = ['Why did you decide to feature Berkshire pork?', 'Who raises it, and are the animals outdoors?'];
    expect(qs(ocrResult(), 'BERKSHIRE'), want);
    expect(ask('Heritage Berkshire Pork Chop 38'), want);
  });

  test('Heritage meaning is verbatim', () {
    const want =
        'A traditional breed. Berkshires are black-colored pigs; Kurobuta is Japanese for ‘black pig.’ ‘Heritage’ has no federal definition.';
    for (final key in ['berkshire', 'heritage_breed']) {
      expect(glossary.entry(key)!.meaning, want, reason: key);
      expect(glossary.entry(key)!.gap, 'How the animal was raised, fed or housed.', reason: key);
    }
  });

  test('production claim leads and Q2 names the item', () {
    expect(ask('Grass-Fed Ribeye 58'),
        ['Why did you choose grass-fed for this dish?', 'Was the beef grass-finished, or finished on grain?']);
    expect(ask('Wild-Caught Gulf Shrimp 18'),
        ['Why did you choose wild-caught for this dish?', 'Where was the shrimp caught, and how — line, net or trap?']);
  });

  test('species fallback uses the bird word and a sourcing question', () {
    expect(ask('Roast Duck Breast 38'), ['Why did you choose this duck?', 'Who raises the duck?']);
    expect(ask('Ribeye Steak 52'), ['Why did you choose this beef?', 'Where was the beef raised?']);
  });

  test('add-on-only dish gets the single add-on question', () {
    expect(qs(ocrResult(), 'THAI'), ['If I add the lobster, where is it from?']);
  });

  test('filet does not ask about the foie gras add-on', () {
    for (final q in qs(ocrResult(), 'FILET')) {
      expect(q.toLowerCase().contains('foie'), isFalse, reason: q);
    }
  });

  // ── Glossary rules ──

  test('every glossary phrase has exactly two questions', () {
    for (final e in glossary.entries) {
      expect(e.questions.length, 2, reason: e.key);
      if (e.inferredQuestions != null) expect(e.inferredQuestions!.length, 2, reason: e.key);
      for (final v in e.variants) {
        expect(v.questions.length, 2, reason: e.key);
      }
    }
    glossary.fallbackAsk.forEach((k, v) => expect(v.length, 2, reason: k));
    expect(glossary.generalQuestions.length, 2);
  });

  test('phrase → questions snapshot shared with iOS', () {
    final got = {
      'addOnAsk': glossary.addOnAsk ?? '',
      'entries': {
        for (final e in glossary.entries)
          e.key: {
            'phrases': e.phrases,
            'questions': e.questions,
            if (e.questionsVerbatim) 'questionsVerbatim': true,
            if (e.inferredQuestions != null) 'inferredQuestions': e.inferredQuestions,
            if (e.variants.isNotEmpty)
              'variants': [
                for (final v in e.variants) {'proteins': [for (final p in v.proteins) p.name], 'questions': v.questions},
              ],
          },
      },
      'fallbackAsk': glossary.fallbackAsk,
      'generalQuestions': glossary.generalQuestions,
    };
    final want = jsonDecode(File('test/menu_phrase_questions_expected.json').readAsStringSync());
    expect(got, want, reason: const JsonEncoder.withIndent('  ').convert(got));
  });

  // ── Learn more ──

  test('learn-more links per species', () {
    final pork = interpreter.interpret([MenuPage.fromPlainText('Berkshire Pork Chop 38')]).items.first;
    final links = MenuLearnLinks.linksFor(pork);
    expect([for (final l in links) l.title],
        ['Ractopamine', 'Menu words, explained', 'How U.S. pork is raised and processed']);
    expect([for (final l in links) l.url], [
      'https://farmanimaltransparency.com/ractopamine-us-pork-labels-verification/',
      'https://farmanimaltransparency.com/how-fat-reads-menus/',
      'https://farmanimaltransparency.com/category/fatresearch/pork-industry-research-series/',
    ]);
    expect(MenuLearnLinks.ractopamine.blurb,
        'A growth drug that is legal and unlabeled in conventional U.S. pork, and banned in many export markets. ‘Never fed’ claims are verified under a USDA program; FAT lists who is on it.');
    for (final text in ['Ribeye Steak 52', 'Seared Scallops 34', 'Roast Chicken 28']) {
      final item = interpreter.interpret([MenuPage.fromPlainText(text)]).items.first;
      expect(MenuLearnLinks.linksFor(item), [MenuLearnLinks.menuWords], reason: text);
    }
  });

  // ── Wording guard ──

  /// Words the menu flow never uses (Nov 12 menu brief §1, §2, §3).
  final forbidden = RegExp(
      r'show to server|full screen|hand to your server|nobody checks|label|everything in this dish|(?<!processing )\bplants?\b',
      caseSensitive: false);
  // Dirk's verbatim ractopamine blurb ("unlabeled") is the one exception.
  final allowed = [MenuLearnLinks.ractopamine.blurb!];
  bool violates(String s) {
    if (allowed.contains(s)) return false;
    return forbidden.hasMatch(s.replaceAll(RegExp(r'https?://\S+'), ''));
  }

  void allStrings(Object? v, List<String> out) {
    if (v is String) {
      out.add(v);
    } else if (v is List) {
      for (final x in v) {
        allStrings(x, out);
      }
    } else if (v is Map) {
      for (final x in v.values) {
        allStrings(x, out);
      }
    }
  }

  test('menu glossary and copy avoid forbidden words', () {
    final strings = <String>[];
    allStrings(jsonDecode(File('assets/data/menu_claim_glossary.json').readAsStringSync()), strings);
    expect(strings.length, greaterThan(300));
    strings.addAll(MenuAskCopy.all);
    for (final l in [MenuLearnLinks.ractopamine, MenuLearnLinks.menuWords, MenuLearnLinks.porkResearch]) {
      strings.add(l.title);
      if (l.blurb != null) strings.add(l.blurb!);
    }
    for (final s in strings) {
      expect(violates(s), isFalse, reason: s);
    }
    expect(violates('Show to server'), isTrue);
    expect(violates('the plant that made it'), isTrue);
    expect(violates('the processing plant that made it'), isFalse);
  });

  test('no string literal in lib/menu uses a forbidden word', () {
    final literal = RegExp("'(?:[^'\\\\]|\\\\.)*'" r'|"(?:[^"\\]|\\.)*"');
    final files = Directory('lib/menu').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files.length, greaterThan(5));
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        for (final m in literal.allMatches(lines[i])) {
          final lit = m.group(0)!;
          if (violates(lit.substring(1, lit.length - 1))) hits.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'Menu string literals with a forbidden word: $hits');
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
    expect(find.text(MenuAskCopy.sheetTitle), findsOneWidget);
    expect(find.text(MenuAskCopy.closeWith), findsOneWidget);
    expect(find.text(MenuAskCopy.kitchenNote), findsOneWidget);
    expect(find.text(MenuAskCopy.copy), findsOneWidget);
    expect(find.text(MenuAskCopy.moreAboutDish), findsOneWidget);
    for (final q in MenuClaimExplainer.askQuestions(salmon, glossary)) {
      expect(find.text(q), findsOneWidget);
    }
    // The dish screen was not pushed underneath.
    expect(find.byType(MenuDishScreen), findsNothing);
  });

  // ── More questions (ASPCA ShopKind) ──

  const outdoors = 'Are the animals raised outdoors?';
  const antibiotics = 'Does the farm use antibiotics only when an animal is sick?';

  MenuItem dish(String text) => interpreter.interpret([MenuPage.fromPlainText(text)]).items.first;

  List<String> more(String text) {
    final item = dish(text);
    return MenuClaimExplainer.shopKindQuestions(
        item, glossary, MenuClaimExplainer.askQuestions(item, glossary));
  }

  test('ShopKind: pork dish', () {
    expect(more('Grilled Pork Chop 32'),
        [outdoors, 'Are the pigs’ tails docked, or their teeth cut?', antibiotics]);
  });

  test('ShopKind: chicken dish', () {
    expect(more('Roast Chicken 28'), [outdoors, 'What breed of chicken is it?', antibiotics]);
  });

  test('ShopKind: turkey dish asks about beaks', () {
    expect(more('Smoked Turkey Breast 24'), [outdoors, 'Are the turkeys’ beaks trimmed?', antibiotics]);
  });

  test('ShopKind: other land animals', () {
    for (final text in ['Ribeye Steak 52', 'Rack of Lamb 46', 'Roast Duck Breast 38']) {
      expect(more(text), [outdoors, antibiotics], reason: text);
    }
  });

  test('ShopKind: seafood has no section', () {
    for (final text in ['Grilled Salmon 34', 'Seared Scallops 34', 'Wild-Caught Gulf Shrimp 18']) {
      expect(more(text), isEmpty, reason: text);
    }
  });

  test('ShopKind skips what a main question already asks', () {
    // Berkshire's main question already asks "are the animals outdoors?".
    final main = MenuClaimExplainer.askQuestions(dish('Berkshire Pork Chop 38'), glossary);
    expect(main.any((q) => q.contains('outdoors')), isTrue, reason: '$main');
    expect(more('Berkshire Pork Chop 38'), ['Are the pigs’ tails docked, or their teeth cut?', antibiotics]);
  });

  test('ShopKind never duplicates a main question', () {
    for (final r in [ocrResult(), textResult()]) {
      for (final item in r.items) {
        final main = MenuClaimExplainer.askQuestions(item, glossary);
        for (final q in MenuClaimExplainer.shopKindQuestions(item, glossary, main)) {
          expect(main.contains(q), isFalse, reason: '${item.dishName}: $q');
          for (final topic in ['outdoor', 'antibiotic', 'breed', 'beak', 'tail']) {
            if (!q.toLowerCase().contains(topic)) continue;
            expect(main.any((m) => m.toLowerCase().contains(topic)), isFalse, reason: '${item.dishName}: $q');
          }
        }
      }
    }
  });

  test('ShopKind glossary source and copy', () {
    final sk = glossary.shopkindAsk!;
    expect(sk.url, 'https://www.aspca.org/shopkind/guide/findfarms');
    expect(sk.source, contains('ASPCA ShopKind'));
    expect(sk.source, contains(sk.url));
    expect(MenuAskCopy.shopKindURL, sk.url);
    expect(sk.questions['finfish'], isNull);
    expect(sk.questions['shellfish'], isNull);
  });

  test('copy includes ShopKind questions only when expanded', () {
    final item = dish('Grilled Pork Chop 32');
    final main = MenuClaimExplainer.askQuestions(item, glossary);
    final extra = MenuClaimExplainer.shopKindQuestions(item, glossary, main);
    final collapsed = MenuClaimExplainer.shareText(item, main);
    expect(collapsed.contains(MenuAskCopy.moreTitle), isFalse);
    expect(collapsed.contains(outdoors), isFalse);
    final expanded = MenuClaimExplainer.shareText(item, main, extra: extra);
    expect(expanded, contains('${MenuAskCopy.moreTitle} — ${MenuAskCopy.moreSubtitle}:'));
    for (final q in [...main, ...extra]) {
      expect(expanded, contains(q));
    }
  });

  testWidgets('More questions section is collapsed by default and expands', (tester) async {
    final item = dish('Grilled Pork Chop 32');
    final main = MenuClaimExplainer.askQuestions(item, glossary);
    final extra = MenuClaimExplainer.shopKindQuestions(item, glossary, main);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MenuAskSheet(item: item, questions: main, extraQuestions: extra))));
    expect(find.text(MenuAskCopy.moreTitle), findsOneWidget);
    expect(find.text(MenuAskCopy.moreSubtitle), findsOneWidget);
    expect(find.text(outdoors), findsNothing);
    await tester.tap(find.text(MenuAskCopy.moreTitle));
    await tester.pumpAndSettle();
    for (final q in extra) {
      expect(find.text(q), findsOneWidget);
    }
    expect(find.text(MenuAskCopy.shopKindNote), findsOneWidget);
    expect(find.text(MenuAskCopy.shopKindLink), findsOneWidget);
  });

  testWidgets('seafood sheet has no More questions section', (tester) async {
    final item = dish('Grilled Salmon 34');
    final main = MenuClaimExplainer.askQuestions(item, glossary);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MenuAskSheet(
                item: item,
                questions: main,
                extraQuestions: MenuClaimExplainer.shopKindQuestions(item, glossary, main)))));
    expect(find.text(MenuAskCopy.moreTitle), findsNothing);
  });

  test('new sheet copy has no regulatory acronyms', () {
    final re = RegExp(r'\b(?:COOL|SIMP|AMS|FSIS|HACCP|NOP|PACA)\b');
    for (final s in [...MenuAskCopy.all, glossary.addOnAsk!, ...glossary.fallbackAsk.values.expand((v) => v)]) {
      expect(re.hasMatch(s), isFalse, reason: s);
    }
  });
}
