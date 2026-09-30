// Meat "seasoned / marinated" Cat. 14 detail line — mirrors iOS
// FATAppMVP2Tests/MeatSeasoningDetailTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/interpreter/meat_seasoning_detail.dart';
import 'package:fat_app/interpreter/prepared_food.dart';
import 'package:fat_app/models/fat_models.dart';

const pumpkinSpice = '''
READY TO COOK.
PUMPKIN SPICE BONELESS CHICKEN THIGHS
CHICKEN THIGHS WITH OIL AND PUMPKIN SPICE.
INGREDIENTS: CHICKEN, OIL (OLIVE OIL AND CANOLA OIL), SALT, SPICES, GARLIC,
ONION, BROWN SUGAR.
PREPARED FROM INSPECTED AND PASSED MEAT AND/OR POULTRY
BIANCO & SONS MEDFORD, MA 02155
KEEP REFRIGERATED
''';

const groundBeef = 'USDA INSPECTED GROUND BEEF 80/20';

const sausage = 'INGREDIENTS: PORK, WATER, SALT, SPICES';

const enhancedPork = '''
BONELESS PORK LOIN CHOPS
CONTAINING UP TO 15% OF A SOLUTION OF WATER, SALT, SODIUM PHOSPHATE
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. 17
''';

const beefStew = '''
DINTY MOORE BEEF STEW WITH POTATOES & CARROTS
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. 199
INGREDIENTS: BEEF BROTH, BEEF, POTATOES, CARROTS, WATER, TOMATOES,
MODIFIED CORNSTARCH, SALT, CARAMEL COLOR
''';

const productNameOnly = 'HERB MARINATED PORK TENDERLOIN EST. 123';

/// Mirrors the scan flow: meat interpreter, then the prepared-lane transform
/// when the detector fires.
FATResult scan(String text) {
  final prepared = PreparedFoodDetector.detect(text);
  var cats = LabelInterpreter.interpret(text);
  if (prepared.isPrepared) {
    cats = PreparedFoodDetector.apply(cats, prepared, fsisJurisdiction: true);
  }
  return FATResult(
    scannedText: text,
    categories: cats,
    isPreparedFood: prepared.isPrepared,
  );
}

void main() {
  test('pumpkin spice chicken thighs — exact Seasoned line, stays meat lane', () {
    expect(PreparedFoodDetector.detect(pumpkinSpice).isPrepared, isFalse);
    expect(MeatSeasoningDetail.forResult(scan(pumpkinSpice)), [
      'Seasoned: oil (olive oil and canola oil), salt, spices, garlic, onion, brown sugar.',
    ]);
  });

  test('plain ground beef — no line', () {
    expect(MeatSeasoningDetail.forResult(scan(groundBeef)), isEmpty);
  });

  test('sausage ingredient list — Seasoned: water, salt, spices.', () {
    expect(MeatSeasoningDetail.forResult(scan(sausage)),
        ['Seasoned: water, salt, spices.']);
  });

  test('added solution — solution line', () {
    expect(MeatSeasoningDetail.forResult(scan(enhancedPork)), [
      'Contains added solution: Containing up to 15% of a solution of water, salt, sodium phosphate.',
    ]);
  });

  test('seasoning named only in the product name — generic line', () {
    expect(MeatSeasoningDetail.forResult(scan(productNameOnly)),
        [MeatSeasoningDetail.seasonedNameOnly]);
  });

  test('prepared-food lane (beef stew) — no line', () {
    final r = scan(beefStew);
    expect(r.isPreparedFood, isTrue);
    expect(MeatSeasoningDetail.forResult(r), isEmpty);
    // Also silent for a persisted record saved without the prepared flag.
    final legacy = FATResult(
        scannedText: beefStew, categories: LabelInterpreter.interpret(beefStew));
    expect(MeatSeasoningDetail.forResult(legacy), isEmpty);
  });

  test('seafood — no line', () {
    final r = FATResult(
      scannedText: 'ATLANTIC SALMON FILLET INGREDIENTS: SALMON, SALT, PEPPER',
      categories: const {},
      productType: ProductType.seafood,
    );
    expect(MeatSeasoningDetail.forResult(r), isEmpty);
  });

  test('category statuses identical with and without the feature', () {
    for (final text in [
      pumpkinSpice, groundBeef, sausage, enhancedPork, beefStew, productNameOnly,
    ]) {
      final before = scan(text);
      final snapshot = {
        for (final c in FATCategory.values)
          c: before.categories[c]?.status ?? DisclosureStatus.missing,
      };
      final known = before.knownCount;
      final partial = before.partialCount;
      MeatSeasoningDetail.forResult(before);
      final after = scan(text);
      for (final c in FATCategory.values) {
        expect(after.categories[c]?.status ?? DisclosureStatus.missing,
            snapshot[c], reason: '$c changed for: $text');
        expect(before.categories[c]?.status ?? DisclosureStatus.missing,
            snapshot[c]);
      }
      expect(after.knownCount, known);
      expect(after.partialCount, partial);
    }
  });

  test('new strings stay neutral (banned-word check)', () {
    const banned = [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy',
    ];
    final strings = <String>[
      MeatSeasoningDetail.seasonedPrefix,
      MeatSeasoningDetail.seasonedNameOnly,
      MeatSeasoningDetail.solutionPrefix,
      for (final t in [pumpkinSpice, sausage, enhancedPork, productNameOnly])
        ...MeatSeasoningDetail.forResult(scan(t)),
    ];
    for (final s in strings) {
      for (final w in banned) {
        expect(RegExp('\\b$w\\b').hasMatch(s.toLowerCase()), isFalse,
            reason: '"$w" in: $s');
      }
    }
  });
}
