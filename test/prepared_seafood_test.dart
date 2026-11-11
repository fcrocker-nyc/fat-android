// Prepared / Multi-Ingredient lane — seafood side (chowder, crab cakes, fish
// sticks) and the routing guards that keep single-species seafood out.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/prepared_food.dart';
import 'package:fat_app/interpreter/product_type_detector.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

void main() {
  const chowder = '''
NEW ENGLAND CLAM CHOWDER
INGREDIENTS: CLAM BROTH, CLAMS, POTATOES, CREAM, CELERY, ONIONS,
WHEAT FLOUR, BUTTER, SALT, SPICES
CONTAINS: MILK, WHEAT, CLAMS
''';

  const fishSticks = '''
CRUNCHY BREADED FISH STICKS
INGREDIENTS: ALASKA POLLOCK, WHEAT FLOUR, WATER, VEGETABLE OIL, BREADING,
BATTER, SALT, YEAST
CONTAINS: FISH (POLLOCK), WHEAT
''';

  const crabCakes = '''
MARYLAND STYLE CRAB CAKES
INGREDIENTS: CRABMEAT, BREAD CRUMBS, MAYONNAISE, EGGS, MUSTARD, SPICES
CONTAINS: CRAB, EGG, WHEAT
''';

  const smokedSalmon = '''
COLD SMOKED ATLANTIC SALMON  FARM RAISED  PRODUCT OF NORWAY
INGREDIENTS: ATLANTIC SALMON, SALT, SUGAR, NATURAL HARDWOOD SMOKE
''';

  const sushiTuna = 'WILD CAUGHT SUSHI GRADE AHI TUNA STEAKS  PRODUCT OF VIETNAM';

  const cannedTuna = '''
CHUNK LIGHT TUNA IN WATER
INGREDIENTS: LIGHT TUNA, WATER, SALT
''';

  test('clam chowder routes seafood and is prepared', () {
    expect(ProductTypeDetector.detect(chowder).productType, ProductType.seafood);
    final ctx = SeafoodPreparedDetector.detect(chowder);
    expect(ctx.isPrepared, isTrue);
    expect(ctx.speciesMentioned, contains('Clam'));
  });

  test('fish sticks and crab cakes are prepared', () {
    expect(SeafoodPreparedDetector.detect(fishSticks).isPrepared, isTrue);
    expect(SeafoodPreparedDetector.detect(fishSticks).speciesMentioned,
        contains('Pollock'));
    expect(SeafoodPreparedDetector.detect(crabCakes).isPrepared, isTrue);
    expect(SeafoodPreparedDetector.detect(crabCakes).speciesMentioned,
        contains('Crab'));
  });

  test('single-species seafood is NOT prepared', () {
    expect(SeafoodPreparedDetector.detect(smokedSalmon).isPrepared, isFalse);
    expect(SeafoodPreparedDetector.detect(sushiTuna).isPrepared, isFalse);
    expect(SeafoodPreparedDetector.detect(cannedTuna).isPrepared, isFalse);
  });

  test('transform: per-fish categories not applicable, origin not required', () {
    final si = SeafoodInterpreter.interpret(chowder);
    final ctx = SeafoodPreparedDetector.detect(chowder);
    final out = SeafoodPreparedDetector.apply(si.categories, ctx,
        processedOriginNote: SeafoodInterpreter.coolNotRequiredProcessed);
    expect(out[SeafoodCategory.speciesIdentity]!.value, 'Contains: Clam');
    for (final c in [
      SeafoodCategory.farmVesselFishery,
      SeafoodCategory.productionMethodFeed,
      SeafoodCategory.ageAtHarvest,
      SeafoodCategory.animalWelfare,
    ]) {
      expect(out[c]!.status, DisclosureStatus.notRequired, reason: '$c');
    }
    expect(out[SeafoodCategory.countryOrigin]!.status, DisclosureStatus.notRequired);
  });

  test('voluntary disclosure survives the seafood transform', () {
    const wild = '$fishSticks\nMADE WITH WILD CAUGHT ALASKA POLLOCK  PRODUCT OF USA';
    final si = SeafoodInterpreter.interpret(wild);
    final out = SeafoodPreparedDetector.apply(
        si.categories, SeafoodPreparedDetector.detect(wild),
        processedOriginNote: SeafoodInterpreter.coolNotRequiredProcessed);
    expect(out[SeafoodCategory.productionMethodFeed]!.status,
        isNot(DisclosureStatus.notRequired));
  });

  test('meat-lane species list names seafood ingredients too', () {
    const gumbo = '''
CHICKEN AND SAUSAGE GUMBO WITH SHRIMP
INGREDIENTS: WATER, CHICKEN, PORK SAUSAGE, SHRIMP, RICE, OKRA, ONIONS
''';
    final ctx = PreparedFoodDetector.detect(gumbo);
    expect(ctx.isPrepared, isTrue);
    expect(ctx.speciesMentioned, containsAll(['Pork', 'Chicken', 'Shrimp']));
  });
}
