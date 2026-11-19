// Prepared / Multi-Ingredient lane audit — realistic OCR fixtures run through
// the same routing the Scan tab uses (LabelLaneRouter → meat or seafood
// pipeline → prepared transform). Mirrors iOS PreparedLaneAuditTests.swift;
// fixtures are identical.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/interpreter/meter_card_text.dart';
import 'package:fat_app/interpreter/prepared_food.dart';
import 'package:fat_app/interpreter/retail_exemption.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

const cannedBeefStew = '''
BEEF STEW
MADE WITH 100% REAL BEEF, POTATOES & CARROTS
NET WT 20 OZ (1 LB 4 OZ) 567g
INGREDIENTS: BEEF STOCK, BEEF, POTATOES, CARROTS, WATER,
CONTAINS LESS THAN 2% OF: MODIFIED CORNSTARCH, SALT, TOMATO
PASTE, SUGAR, CARAMEL COLOR, SPICE.
U.S.
INSPECTED
AND PASSED BY
DEPARTMENT OF
AGRICULTURE
EST. 199
Nutrition Facts 2 servings per container Serving size 1 cup (283g)
''';

const frozenPepperoniPizza = '''
RISING CRUST
PEPPERONI
PIZZA
NET WT 27.5 OZ (1 LB 11.5 OZ) 780g
INGREDIENTS: CRUST (ENRICHED FLOUR (WHEAT FLOUR, NIACIN, REDUCED IRON,
THIAMIN MONONITRATE, RIBOFLAVIN, FOLIC ACID), WATER, YEAST, SOYBEAN OIL,
SUGAR, SALT), LOW-MOISTURE MOZZARELLA CHEESE (PASTEURIZED MILK, CULTURES,
SALT, ENZYMES), SAUCE (TOMATO PUREE, SUGAR, SALT, SPICES, GARLIC),
PEPPERONI MADE WITH PORK, CHICKEN AND BEEF (PORK, MECHANICALLY SEPARATED
CHICKEN, BEEF, SALT, CONTAINS 2% OR LESS OF SPICES, DEXTROSE, PORK STOCK,
LACTIC ACID STARTER CULTURE, OLEORESIN OF PAPRIKA, SODIUM ASCORBATE,
SODIUM NITRITE).
CONTAINS: WHEAT, MILK.
INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. 1632A
''';

const chickenNoodleSoup = '''
CONDENSED
CHICKEN
NOODLE
SOUP
NET WT 10.75 OZ (305g)
INGREDIENTS: CHICKEN STOCK, ENRICHED EGG NOODLES (WHEAT FLOUR, EGGS,
NIACIN, FERROUS SULFATE, THIAMINE MONONITRATE, RIBOFLAVIN, FOLIC ACID),
CHICKEN MEAT, CONTAINS LESS THAN 2% OF: WATER, SALT, CHICKEN FAT,
CORNSTARCH, MONOSODIUM GLUTAMATE, VEGETABLE OIL, YEAST EXTRACT, SPICE,
CARROTS, CELERY, DEHYDRATED ONIONS.
CONTAINS: WHEAT, EGG
INSPECTED FOR WHOLESOMENESS BY U.S. DEPARTMENT OF AGRICULTURE P-7345
''';

const newEnglandClamChowder = '''
TRADITIONAL
NEW ENGLAND
CLAM CHOWDER
NET WT 18.5 OZ (1 LB 2.5 OZ) 524g
INGREDIENTS: WATER, CLAMS, POTATOES, CREAM, CLAM JUICE, CELERY,
MODIFIED CORN STARCH, BACON (CURED WITH WATER, SALT, SUGAR, SODIUM
PHOSPHATE, SODIUM NITRITE), ONIONS, BUTTER, WHEAT FLOUR, SALT,
SOYBEAN OIL, SPICE.
CONTAINS: MILK, WHEAT, CLAM.
''';

const breadedFishSticks = '''
CRUNCHY BREADED
FISH STICKS
WILD CAUGHT ALASKA POLLOCK
NET WT 24.5 OZ (1 LB 8.5 OZ) 694g
INGREDIENTS: ALASKA POLLOCK, WHEAT FLOUR, WATER, VEGETABLE OIL (SOYBEAN
AND/OR CANOLA), YELLOW CORN FLOUR, MODIFIED FOOD STARCH, SALT, YEAST,
SUGAR, DEXTROSE, LEAVENING (SODIUM ACID PYROPHOSPHATE, SODIUM BICARBONATE).
CONTAINS: FISH (POLLOCK), WHEAT.
PRODUCT OF CHINA
''';

const cheesePizza = '''
CLASSIC CRUST
FOUR CHEESE
PIZZA
NET WT 18.69 OZ (1 LB 2.69 OZ) 530g
INGREDIENTS: CRUST (ENRICHED FLOUR (WHEAT FLOUR, NIACIN, REDUCED IRON,
THIAMIN MONONITRATE, RIBOFLAVIN, FOLIC ACID), WATER, SOYBEAN OIL, YEAST,
SUGAR, SALT), LOW-MOISTURE PART-SKIM MOZZARELLA CHEESE (PASTEURIZED PART
SKIM MILK, CULTURES, SALT, ENZYMES), SAUCE (WATER, TOMATO PASTE, SUGAR,
SALT, SPICES), CHEDDAR CHEESE, PARMESAN CHEESE, ROMANO CHEESE MADE FROM
COW'S MILK.
CONTAINS: WHEAT, MILK.
''';

const vegetableSoupChickenBroth = '''
GARDEN VEGETABLE
SOUP
NET WT 19 OZ (1 LB 3 OZ) 538g
INGREDIENTS: WATER, CARROTS, POTATOES, TOMATOES, GREEN BEANS, CELERY,
CORN, PEAS, CHICKEN BROTH, CONTAINS LESS THAN 2% OF: SALT, MODIFIED
CORN STARCH, SUGAR, ONIONS, SOYBEAN OIL, SPICE, GARLIC.
''';

const minestroneBeefStock = '''
MINESTRONE
SOUP
INGREDIENTS: WATER, TOMATOES, CARROTS, KIDNEY BEANS, PASTA (WHEAT
FLOUR), CELERY, ZUCCHINI, GREEN BEANS, BEEF STOCK, SALT, SUGAR, SPICES.
CONTAINS: WHEAT.
''';

/// What the Scan tab would build for this text (scan_screen.dart routing).
class Scan {
  final LabelLane lane;
  final bool isPrepared;
  final bool fsisJurisdiction;
  final bool estMissing;
  final bool retailExempt;
  final Map<FATCategory, FATCategoryResult> meat;
  final Map<SeafoodCategory, FATCategoryResult> seafood;
  final String? ingredientLine;
  final String? naLine;
  Scan(this.lane, this.isPrepared, this.fsisJurisdiction, this.estMissing,
      this.retailExempt, this.meat, this.seafood, this.ingredientLine,
      this.naLine);
}

Scan scan(String text) {
  final lane = LabelLaneRouter.lane(text);
  if (lane == LabelLane.noAnimalIngredient) {
    return Scan(lane, false, false, false, false, const {}, const {}, null,
        null);
  }
  if (lane == LabelLane.seafood) {
    final si = SeafoodInterpreter.interpret(text);
    final p = SeafoodPreparedDetector.detect(text);
    final cats = p.isPrepared
        ? SeafoodPreparedDetector.apply(si.categories, p,
            processedOriginNote: SeafoodInterpreter.coolNotRequiredProcessed)
        : si.categories;
    return Scan(lane, p.isPrepared, false, false, false, const {}, cats, null,
        null);
  }
  var cats = LabelInterpreter.interpret(text);
  final est = LabelInterpreter.extractEstablishmentNumber(text.toLowerCase());
  final p = PreparedFoodDetector.detect(text);
  final fsis =
      p.isPrepared && (est != null || PreparedFoodDetector.hasFsisLegend(text));
  if (p.isPrepared) {
    cats = PreparedFoodDetector.apply(cats, p, fsisJurisdiction: fsis);
  }
  final isMeat = cats[FATCategory.species]?.status == DisclosureStatus.known;
  final exemption = LabelInterpreter.detectRetailExemption(text);
  final estMissing =
      isMeat && est == null && !exemption.isExempt && !p.isPrepared;
  return Scan(
    lane,
    p.isPrepared,
    fsis,
    estMissing,
    exemption.isExempt,
    cats,
    const {},
    MeterCardText.ingredientStatementLine(
        isPreparedFood: p.isPrepared, scannedText: text),
    MeterCardText.notApplicableLine(cats),
  );
}

const perAnimal = [
  FATCategory.breed,
  FATCategory.farmRanch,
  FATCategory.ageAtSlaughter,
  FATCategory.feed,
  FATCategory.animalWelfare,
  FATCategory.medicine,
  FATCategory.hormones,
];

void expectNoRetailExemption(Scan s) {
  expect(s.retailExempt, isFalse);
  for (final r in s.meat.values) {
    expect(r.value, isNot(RetailExemption.categoryNote));
  }
}

void expectMeatPrepared(Scan s, {required bool fsis}) {
  expect(s.lane, LabelLane.meat);
  expect(s.isPrepared, isTrue);
  expect(s.fsisJurisdiction, fsis);
  expect(s.estMissing, isFalse);
  for (final c in perAnimal) {
    expect(s.meat[c]!.status, DisclosureStatus.notRequired, reason: '$c');
  }
  expectNoRetailExemption(s);
}

void main() {
  test('canned beef stew (USDA mark) → meat lane, prepared, USDA side', () {
    final s = scan(cannedBeefStew);
    expectMeatPrepared(s, fsis: true);
    expect(s.meat[FATCategory.species]!.value, 'Contains: Beef');
    expect(s.meat[FATCategory.usdaFsisRequiredLanguage]!.status,
        DisclosureStatus.known);
    expect(s.meat[FATCategory.processor]!.status, DisclosureStatus.known);
    expect(s.meat[FATCategory.processor]!.credibilityNote,
        contains('final assembler'));
    expect(s.ingredientLine, 'Ingredient statement: on the label — lists: beef');
    expect(s.naLine, MeterCardText.preparedFoodLine(8));
  });

  test('frozen pepperoni pizza (USDA mark) → three species, USDA side', () {
    final s = scan(frozenPepperoniPizza);
    expectMeatPrepared(s, fsis: true);
    expect(s.meat[FATCategory.species]!.value, 'Contains: Beef, Pork, Chicken');
    expect(s.ingredientLine,
        'Ingredient statement: on the label — lists: beef, pork, chicken');
    expect(s.naLine, MeterCardText.preparedFoodLine(8));
  });

  test('chicken noodle soup (USDA poultry mark) → chicken, USDA side', () {
    final s = scan(chickenNoodleSoup);
    expectMeatPrepared(s, fsis: true);
    expect(s.meat[FATCategory.species]!.value, 'Contains: Chicken');
    expect(s.meat[FATCategory.processor]!.status, DisclosureStatus.known);
    expect(s.ingredientLine,
        'Ingredient statement: on the label — lists: chicken');
    expect(s.naLine, MeterCardText.preparedFoodLine(8));
  });

  test('New England clam chowder (no USDA mark) → seafood lane, prepared', () {
    final s = scan(newEnglandClamChowder);
    expect(s.lane, LabelLane.seafood);
    expect(s.isPrepared, isTrue);
    expect(s.seafood[SeafoodCategory.speciesIdentity]!.value,
        'Contains: Clam, Pork');
    for (final c in [
      SeafoodCategory.farmVesselFishery,
      SeafoodCategory.productionMethodFeed,
      SeafoodCategory.ageAtHarvest,
      SeafoodCategory.countryOrigin,
    ]) {
      expect(s.seafood[c]!.status, DisclosureStatus.notRequired, reason: '$c');
    }
  });

  test('breaded fish sticks (no USDA mark) → seafood lane, voluntary claims kept',
      () {
    final s = scan(breadedFishSticks);
    expect(s.lane, LabelLane.seafood);
    expect(s.isPrepared, isTrue);
    expect(s.seafood[SeafoodCategory.speciesIdentity]!.value,
        'Contains: Pollock');
    // "Wild caught" and "Product of China" are on the label: they still count.
    expect(s.seafood[SeafoodCategory.productionMethodFeed]!.status,
        DisclosureStatus.known);
    expect(s.seafood[SeafoodCategory.countryOrigin]!.status,
        DisclosureStatus.known);
    expect(s.seafood[SeafoodCategory.farmVesselFishery]!.status,
        DisclosureStatus.notRequired);
  });

  test('cheese pizza with no meat is NOT routed as meat', () {
    expect(LabelLaneRouter.namesNoAnimalIngredient(cheesePizza), isTrue);
    expect(scan(cheesePizza).lane, LabelLane.noAnimalIngredient);
    // Front-of-pack only (no ingredient list read): no "no meat" verdict.
    expect(LabelLaneRouter.namesNoAnimalIngredient('FOUR CHEESE PIZZA'),
        isFalse);
  });

  test('vegetable soup with chicken broth → FDA side, chicken listed', () {
    final s = scan(vegetableSoupChickenBroth);
    expectMeatPrepared(s, fsis: false);
    expect(s.meat[FATCategory.species]!.value, 'Contains: Chicken');
    expect(s.meat[FATCategory.usdaFsisRequiredLanguage]!.status,
        DisclosureStatus.notRequired);
    expect(s.meat[FATCategory.processor]!.status, DisclosureStatus.notRequired);
    expect(s.meat[FATCategory.processor]!.value,
        PreparedFoodDetector.fdaJurisdictionNote);
    expect(s.ingredientLine,
        'Ingredient statement: on the label — lists: chicken');
    expect(s.naLine, MeterCardText.preparedFoodLine(10));
  });

  test('minestrone with beef stock → FDA side, beef listed', () {
    final s = scan(minestroneBeefStock);
    expectMeatPrepared(s, fsis: false);
    expect(s.meat[FATCategory.species]!.value, 'Contains: Beef');
    expect(s.naLine, MeterCardText.preparedFoodLine(10));
  });

  test('the "no animal ingredient" gate never fires on a meat or seafood label',
      () {
    for (final t in [
      cannedBeefStew,
      frozenPepperoniPizza,
      chickenNoodleSoup,
      newEnglandClamChowder,
      breadedFishSticks,
      vegetableSoupChickenBroth,
      minestroneBeefStock,
      'PORK SAUSAGE LINKS INGREDIENTS: PORK, WATER, SALT, SPICES, SUGAR',
      'ITALIAN SAUSAGE PIZZA INGREDIENTS: CRUST, CHEESE, SAUSAGE, TOMATO, SALT',
      'USDA CHOICE BEEF RIBEYE STEAK NET WT 1.02 LB',
      'MEATBALLS INGREDIENTS: GROUND MEAT, BREAD CRUMBS, EGGS, CHEESE, SALT',
      'CHEESE PIZZA INGREDIENTS: CRUST, CHEESE, TOMATO, SALT EST. 1234',
    ]) {
      expect(LabelLaneRouter.namesNoAnimalIngredient(t), isFalse, reason: t);
    }
  });
}
