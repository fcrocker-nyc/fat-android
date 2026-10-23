import 'dart:ui' show Rect;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/menu/menu_explainer.dart';
import 'package:fat_app/menu/menu_interpreter.dart';
import 'package:fat_app/menu/menu_models.dart';

/// Menu track: segmenter, protein classifier, claim extractor, explainer.
/// Mirrors the iOS MenuInterpreterTests so both platforms stay in step.
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

  MenuResult run(String text, {String? state}) =>
      interpreter.interpret([MenuPage.fromPlainText(text)], diningState: state);

  MenuItem dish(MenuResult r, String name) {
    final found = r.items.where((i) => i.dishName.toLowerCase().contains(name.toLowerCase()));
    expect(found, isNotEmpty, reason: 'No dish "$name". Got: ${r.items.map((i) => i.dishName).toList()}');
    return found.first;
  }

  Set<String> keys(MenuItem i) => i.claims.map((c) => c.entryKey).toSet();

  test('glossary loads and is well formed', () {
    expect(glossary.entries, isNotEmpty);
    expect(glossary.generalQuestions.length, 2);
    expect(glossary.entries.map((e) => e.key).toSet().length, glossary.entries.length);
    for (final e in glossary.entries) {
      // The heuristic named-source entry has no phrases; it's matched in code.
      if (e.key != MenuClaimExtractor.menuNamedSourceKey) expect(e.phrases, isNotEmpty, reason: e.key);
      expect(e.questions.length, inInclusiveRange(2, 3), reason: e.key);
      for (final p in e.patterns) {
        expect(() => RegExp(p, unicode: true), returnsNormally, reason: e.key);
      }
    }
  });

  test('priced menu splits into dishes', () {
    final r = run('''
STARTERS
Pink Moon Oysters 24
mignonette, lemon
Yellowfin Tuna Carpaccio 26
capers, olive oil
MAINS
Gently Poached Nova Scotia Halibut 52
leeks, beurre blanc
Grass-Fed Ribeye 68
bone marrow butter
Roasted Carrots 14
honey, dukkah
''');
    expect(r.items.length, 4, reason: '${r.items.map((i) => i.dishName).toList()}');
    expect(dish(r, 'halibut').section, 'MAINS');
    expect(r.items.where((i) => i.dishName.contains('Carrots')), isEmpty);
  });

  test('price on separate line closes block', () {
    final r = run('Halibut\nleeks, beurre blanc\n38\nChicken\njus, potatoes\n29');
    expect(r.items.map((i) => i.dishName).toList(), ['Halibut', 'Chicken']);
  });

  test('unpriced ALL-CAPS tasting menu', () {
    final r = run('CORNISH BLUE FIN TUNA\nkohlrabi, horseradish\nLOUËT-FEISSER OYSTER\napple, dill\nSALT MARSH LAMB');
    expect(r.items.length, 3, reason: '${r.items.map((i) => i.dishName).toList()}');
  });

  test('two-column layout reads column by column', () {
    MenuOCRLine l(String t, double x, double y) =>
        MenuOCRLine(t, Rect.fromLTRB(x, y, x + 0.35, y + 0.03));
    final r = interpreter.interpret([
      MenuPage(0, [
        l('Pork Chop 42', 0.05, 0.9), l('apples, mustard', 0.05, 0.86),
        l('Duck Breast 46', 0.05, 0.8), l('cherries', 0.05, 0.76),
        l('Scallops 44', 0.55, 0.9), l('corn, brown butter', 0.55, 0.86),
        l('Salmon 38', 0.55, 0.8), l('peas, lemon', 0.55, 0.76),
      ])
    ]);
    expect(r.items.map((i) => i.dishName).toList(), ['Pork Chop', 'Duck Breast', 'Scallops', 'Salmon']);
  });

  test('boilerplate advisory ignored', () {
    final r = run('Steak Frites 39\n*Consuming raw or undercooked meats, poultry, seafood may increase your risk of foodborne illness');
    expect(r.items.length, 1);
    expect(r.items.first.proteins, [ProteinFamily.beef]);
  });

  test('protein families and aliases', () {
    expect(MenuProteinClassifier.classify('Spaghetti Carbonara').proteins, [ProteinFamily.pork]);
    expect(MenuProteinClassifier.classify('Paella Valenciana').proteins.toSet(),
        {ProteinFamily.finfish, ProteinFamily.shellfish});
    expect(MenuProteinClassifier.classify('Surf and Turf: filet mignon, lobster tail').proteins.toSet(),
        {ProteinFamily.beef, ProteinFamily.shellfish});
    expect(MenuProteinClassifier.classify('Cornish Hen, lemon').proteins, [ProteinFamily.poultry]);
  });

  test('garnish-only protein is minor', () {
    expect(MenuProteinClassifier.classify('Little Gem Salad\nanchovy dressing, parmesan').minorOnly, isTrue);
    final main = MenuProteinClassifier.classify('Grilled Ribeye\nanchovy butter');
    expect(main.minorOnly, isFalse);
    expect(main.proteins, [ProteinFamily.beef]);
  });

  test('section header lends protein to bare items', () {
    final r = run('OYSTERS\nIsland Creek, MA 4\nKumamoto, WA 5');
    expect(r.items.length, 2);
    expect(r.items.first.proteins, [ProteinFamily.shellfish]);
    expect(keys(r.items.first), contains('named_source'));
  });

  test('core claims', () {
    final r = run('''
Wild Atlantic Black Bass 58
Grass-Fed Ribeye 68
Pasture-Raised Chicken 34
U10 Diver Scallops 44
Niman Ranch Pork Chop 46
USDA Prime New York Strip 72
American Wagyu Burger 28
Royal Osetra Caviar 180
Catch of the Day MP
''');
    expect(keys(dish(r, 'black bass')), containsAll(['wild_caught', 'sea_bass_branzino']));
    expect(keys(dish(r, 'ribeye')), contains('grass_fed'));
    expect(keys(dish(r, 'chicken')), contains('pasture_raised'));
    expect(keys(dish(r, 'scallops')), containsAll(['catch_method', 'scallop_form']));
    expect(keys(dish(r, 'pork chop')), contains('named_source'));
    expect(keys(dish(r, 'strip')), contains('usda_grade'));
    expect(keys(dish(r, 'wagyu')), contains('wagyu'));
    expect(keys(dish(r, 'caviar')), contains('caviar'));
    expect(keys(dish(r, 'catch of the day')), contains('catch_of_day'));
  });

  test('adjacency stops non-protein false positives', () {
    final r = run('Roast Chicken 32\nwild mushrooms, fresh herbs, local greens');
    final k = keys(dish(r, 'chicken'));
    expect(k, isNot(contains('wild_caught')));
    expect(k, isNot(contains('fresh')));
    expect(k, isNot(contains('local')));
  });

  test('"choice of side" is not a grade', () {
    expect(keys(dish(run('Steak Frites 39\nchoice of side'), 'steak')), isNot(contains('usda_grade')));
  });

  test('Gulf shrimp and state note', () {
    final r = run('Gulf Shrimp & Grits 28\nandouille, tasso gravy', state: 'LA');
    final d = dish(r, 'shrimp');
    expect(keys(d), containsAll(['gulf', 'shrimp']));
    expect(MenuClaimExplainer.cards(d, glossary, 'LA').any((c) => c.stateNote?.contains('Louisiana') ?? false), isTrue);
    expect(MenuClaimExplainer.cards(d, glossary, 'OR').every((c) => c.stateNote == null), isTrue);
  });

  test('species and market names', () {
    final r = run('''
Pan-Seared Filet of Antarctic Sea Bass 64
Spicy White Tuna Roll 18
Red Snapper Veracruz 36
Kani Salad 12
''');
    expect(keys(dish(r, 'antarctic')), contains('chilean_sea_bass'));
    expect(keys(dish(r, 'antarctic')), isNot(contains('sea_bass_branzino')));
    expect(keys(dish(r, 'white tuna')), contains('white_tuna'));
    expect(keys(dish(r, 'snapper')), contains('snapper_grouper'));
    expect(keys(dish(r, 'kani')), contains('crab_form'));
  });

  test('header statement is inherited by matching protein only', () {
    final r = run('FROM THE GRILL\nAll our beef is grass-fed and grass-finished.\nHanger Steak 38\nHalf Chicken 29');
    final inherited = dish(r, 'hanger').claims.where((c) => c.inheritedFromHeader).map((c) => c.entryKey).toList();
    expect(inherited.contains('grass_fed') || inherited.contains('grass_finished'), isTrue, reason: '$inherited');
    expect(dish(r, 'chicken').claims.where((c) => c.inheritedFromHeader), isEmpty);
  });

  test('footer statement applies to the page', () {
    final r = run('Lamb Shoulder 44\nPork Belly 32\nWe source our pork from Niman Ranch.');
    expect(dish(r, 'pork belly').claims.any((c) => c.inheritedFromHeader && c.entryKey == 'named_source'), isTrue);
  });

  test('no-claim dish gets general questions', () {
    final d = dish(run('Roast Chicken 32\njus, potatoes'), 'chicken');
    expect(d.claims, isEmpty);
    final cards = MenuClaimExplainer.cards(d, glossary, null);
    expect(cards.length, 1);
    expect(cards.first.title, 'No sourcing claim');
    final qs = MenuClaimExplainer.topQuestions(d, glossary);
    expect(qs.length, 2);
    expect(qs.first, contains('chicken'));
  });

  test('top questions prioritise species and origin', () {
    final d = dish(run('Sustainable Wild Salmon 42'), 'salmon');
    final qs = MenuClaimExplainer.topQuestions(d, glossary);
    expect(qs.length, 3);
    expect(qs.toSet().length, 3);
    expect(qs.first, glossary.entry('atlantic_salmon')!.questions.first);
  });

  test('result stamps glossary version', () {
    expect(run('Steak 40').glossaryVersion, glossary.version);
  });
}
