// Prepared / Multi-Ingredient lane — detection + transform behavior.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/interpreter/prepared_food.dart';
import 'package:fat_app/models/fat_models.dart';

void main() {
  const stewFsis = '''
DINTY MOORE BEEF STEW WITH POTATOES & CARROTS
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. 199
INGREDIENTS: BEEF BROTH, BEEF, POTATOES, CARROTS, WATER, TOMATOES,
MODIFIED CORNSTARCH, SALT, CARAMEL COLOR
''';

  const pizzaFda = '''
SUPREME PEPPERONI PIZZA
INGREDIENTS: CRUST (WHEAT FLOUR, WATER, YEAST), LOW-MOISTURE MOZZARELLA
CHEESE (MILK, CULTURES, SALT), PEPPERONI (PORK, BEEF, SALT, SPICES),
TOMATO SAUCE (TOMATOES, SALT, SPICES)
''';

  const soup = '''
CHICKEN NOODLE SOUP CONDENSED
INGREDIENTS: CHICKEN STOCK, ENRICHED EGG NOODLES (WHEAT FLOUR, EGGS),
CHICKEN MEAT, WATER, SALT, CARROTS, CELERY
P-EST 123 INSPECTED FOR WHOLESOMENESS
''';

  const ribeye = 'USDA CHOICE BEEF RIBEYE STEAK NET WT 1.02 LB';

  const sausage = '''
PORK SAUSAGE LINKS
INGREDIENTS: PORK, WATER, SALT, SPICES, SUGAR
U.S. INSPECTED AND PASSED EST. 999
''';

  const stewMeat = 'USDA CHOICE BEEF STEW MEAT NET WT 1.31 LB';

  test('canned beef stew routes prepared, FSIS lane', () {
    final ctx = PreparedFoodDetector.detect(stewFsis);
    expect(ctx.isPrepared, isTrue);
    expect(ctx.speciesMentioned, contains('Beef'));
    final est = LabelInterpreter.extractEstablishmentNumber(
        stewFsis.toLowerCase());
    expect(est, isNotNull);
    final cats = PreparedFoodDetector.apply(
      LabelInterpreter.interpret(stewFsis),
      ctx,
      fsisJurisdiction: true,
    );
    expect(cats[FATCategory.species]!.status, DisclosureStatus.known);
    expect(cats[FATCategory.species]!.value, contains('Beef'));
    for (final c in [
      FATCategory.breed,
      FATCategory.farmRanch,
      FATCategory.ageAtSlaughter,
      FATCategory.feed,
      FATCategory.animalWelfare,
      FATCategory.medicine,
      FATCategory.hormones,
    ]) {
      expect(cats[c]!.status, DisclosureStatus.notRequired,
          reason: 'per-animal category $c should be notRequired');
    }
    // FSIS lane: required language + processor stay real (legend + EST found).
    expect(cats[FATCategory.usdaFsisRequiredLanguage]!.status,
        DisclosureStatus.known);
    expect(cats[FATCategory.processor]!.status, DisclosureStatus.known);
    expect(cats[FATCategory.processor]!.credibilityNote,
        contains('final assembler'));
  });

  test('FDA frozen pizza: prepared, multi-species, no false EST accusation',
      () {
    final ctx = PreparedFoodDetector.detect(pizzaFda);
    expect(ctx.isPrepared, isTrue);
    expect(ctx.speciesMentioned, containsAll(['Beef', 'Pork']));
    final est = LabelInterpreter.extractEstablishmentNumber(
        pizzaFda.toLowerCase());
    expect(est, isNull);
    expect(PreparedFoodDetector.hasFsisLegend(pizzaFda), isFalse);
    final cats = PreparedFoodDetector.apply(
      LabelInterpreter.interpret(pizzaFda),
      ctx,
      fsisJurisdiction: false,
    );
    expect(cats[FATCategory.species]!.value, 'Contains: Beef, Pork');
    // FDA lane: legend + processor are notRequired, never red.
    expect(cats[FATCategory.usdaFsisRequiredLanguage]!.status,
        DisclosureStatus.notRequired);
    expect(cats[FATCategory.processor]!.status, DisclosureStatus.notRequired);
  });

  test('chicken noodle soup: prepared, chicken listed', () {
    final ctx = PreparedFoodDetector.detect(soup);
    expect(ctx.isPrepared, isTrue);
    expect(ctx.speciesMentioned, contains('Chicken'));
  });

  test('plain ribeye is NOT prepared', () {
    expect(PreparedFoodDetector.detect(ribeye).isPrepared, isFalse);
  });

  test('single-species sausage with curing staples is NOT prepared', () {
    expect(PreparedFoodDetector.detect(sausage).isPrepared, isFalse);
  });

  test('raw "beef stew meat" cut is NOT prepared (identity guard)', () {
    expect(PreparedFoodDetector.detect(stewMeat).isPrepared, isFalse);
  });

  test('voluntary disclosure survives the transform', () {
    const organicSoup = '''
ORGANIC CHICKEN NOODLE SOUP MADE WITH ORGANIC GRASS FED BEEF BONE BROTH
INGREDIENTS: ORGANIC CHICKEN, ORGANIC EGG NOODLES (WHEAT FLOUR), ORGANIC
CARROTS, ORGANIC CELERY, WATER, SALT
USDA ORGANIC CERTIFIED ORGANIC BY OREGON TILTH
''';
    final ctx = PreparedFoodDetector.detect(organicSoup);
    expect(ctx.isPrepared, isTrue);
    final cats = PreparedFoodDetector.apply(
      LabelInterpreter.interpret(organicSoup),
      ctx,
      fsisJurisdiction: false,
    );
    // Organic was disclosed — must remain credited, not flattened.
    expect(cats[FATCategory.organic]!.status, DisclosureStatus.known);
  });
}
