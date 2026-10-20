// Meter-card text: not-applicable reason, raising-claim pill, and the
// prepared-lane ingredient-statement line. Mirrors iOS
// FATAppMVP2Tests/MeterCardTextTests.swift — strings must stay identical.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/interpreter/meter_card_text.dart';
import 'package:fat_app/interpreter/prepared_food.dart';
import 'package:fat_app/models/fat_models.dart';

/// Same meat-lane steps as ScanScreen: interpret → prepared transform.
({Map<FATCategory, FATCategoryResult> cats, bool prepared}) _evaluate(
    String text) {
  var cats = LabelInterpreter.interpret(text);
  final est = LabelInterpreter.extractEstablishmentNumber(text.toLowerCase());
  final ctx = PreparedFoodDetector.detect(text);
  if (ctx.isPrepared) {
    cats = PreparedFoodDetector.apply(cats, ctx,
        fsisJurisdiction:
            est != null || PreparedFoodDetector.hasFsisLegend(text));
  }
  return (cats: cats, prepared: ctx.isPrepared);
}

int _count(Map<FATCategory, FATCategoryResult> c, DisclosureStatus s) =>
    c.values.where((r) => r.status == s).length;

void main() {
  // Prepared item WITH an establishment number (not a store cut).
  const smithfieldPrepared = '''
SMITHFIELD PORK FRIED RICE SKILLET MEAL
INGREDIENTS: COOKED RICE, PORK, CARROTS, PEAS, SOY SAUCE, ONION, SALT
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. M34835+P34835+V34835
SMITHFIELD PACKAGED MEATS CORP., KANSAS CITY, MO
''';

  // Breaded chicken bites with an ingredients statement and an EST.
  const chickenBites = '''
PERDUE POWERED BREADED CHICKEN BITES
INGREDIENTS: CHICKEN BREAST WITH RIB MEAT, WATER, WHEAT FLOUR, YELLOW CORN FLOUR,
SALT, BREADING SET IN VEGETABLE OIL
INSPECTED FOR WHOLESOMENESS BY U.S. DEPARTMENT OF AGRICULTURE P-33944
''';

  // Prepared front panel only — no ingredients statement photographed.
  const stewFrontOnly = '''
BEEF STEW WITH POTATOES AND CARROTS
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. 199
''';

  // In-store Kroger scale label.
  const krogerStoreCut = '''
KROGER
80% LEAN 20% FAT GROUND BEEF
GROUND IN STORE
PACKED ON 09/12 SELL BY 09/15
\$/LB 5.99 TOTAL PRICE 8.43
2 01234 56789 0
''';

  group('not-applicable reason', () {
    test('prepared food with an EST never says "retail exemption"', () {
      final r = _evaluate(smithfieldPrepared);
      expect(r.prepared, isTrue);
      expect(LabelInterpreter.extractEstablishmentNumber(
              smithfieldPrepared.toLowerCase()),
          isNotNull);
      final n = _count(r.cats, DisclosureStatus.notRequired);
      expect(n, greaterThan(0));
      final line = MeterCardText.notApplicableLine(r.cats)!;
      expect(line, isNot(contains('retail exemption')));
      expect(line,
          '$n not applicable — prepared / multi-ingredient food: no U.S. labeling rule requires these details for ingredient meat');
    });

    test('prepared poultry (intermediary note rides with the lane)', () {
      final r = _evaluate(chickenBites);
      expect(r.prepared, isTrue);
      final line = MeterCardText.notApplicableLine(r.cats)!;
      expect(line, isNot(contains('retail exemption')));
      expect(line, contains('prepared / multi-ingredient food'));
    });

    test('store cut keeps the retail-exemption wording', () {
      final r = _evaluate(krogerStoreCut);
      expect(r.prepared, isFalse);
      final n = _count(r.cats, DisclosureStatus.notRequired);
      expect(MeterCardText.notApplicableLine(r.cats),
          '$n not applicable — retail exemption (no establishment number is required on an in-store cut)');
    });

    test('neither lane → neutral line; none → null', () {
      final cats = LabelInterpreter.interpret(
          'PERDUE BONELESS SKINLESS CHICKEN BREAST P-33944 '
          'INSPECTED FOR WHOLESOMENESS BY U.S. DEPARTMENT OF AGRICULTURE');
      final n = _count(cats, DisclosureStatus.notRequired);
      expect(n, 1);
      expect(MeterCardText.notApplicableLine(cats),
          '1 not applicable (see each category)');
      expect(
          MeterCardText.notApplicableLine({
            FATCategory.species: const FATCategoryResult(
                status: DisclosureStatus.known, value: 'Beef'),
          }),
          isNull);
    });

    test('both lanes → neutral line', () {
      final cats = {
        FATCategory.processor: const FATCategoryResult(
            status: DisclosureStatus.notRequired,
            value: 'Cut, ground, or packed in-store under the USDA retail exemption '
                '(9 CFR 303.1(d)). A store operating within the exemption is not an '
                'official establishment and has no establishment number to display, so '
                'this disclosure is structurally unanswerable at the point of sale — a '
                'gap in the regulatory design, not a failure by the store.'),
        FATCategory.feed: const FATCategoryResult(
            status: DisclosureStatus.notRequired,
            value: PreparedFoodDetector.gapNote),
      };
      expect(MeterCardText.notApplicableLine(cats),
          '2 not applicable (see each category)');
    });
  });

  group('raising-claim pill', () {
    test('no raising claims', () {
      final cats = LabelInterpreter.interpret(
          'USDA CHOICE BEEF RIBEYE STEAK EST. 245C');
      expect(MeterCardText.claimPillText(cats),
          'No raising claims on this label (such as organic, grass-fed or no antibiotics)');
      expect(MeterCardText.strongestClaimTier(cats), isNull);
    });

    test('one PVP-backed claim names the claim and tier', () {
      final cats = LabelInterpreter.interpret(
          'PERDUE CHICKEN BREAST NO ANTIBIOTICS EVER USDA PROCESS VERIFIED P-33944');
      expect(MeterCardText.claimPillText(cats),
          '1 raising claim: "No Antibiotics Ever" — USDA Process Verified Program');
      expect(MeterCardText.strongestClaimTier(cats),
          ClaimCredibility.usdaApproved);
    });

    test('statutory hormone statement is not a raising claim', () {
      final cats = LabelInterpreter.interpret(
          'CHICKEN BREAST FEDERAL REGULATIONS PROHIBIT THE USE OF HORMONES IN POULTRY P-33944');
      expect(MeterCardText.claimPillText(cats),
          'No raising claims on this label (such as organic, grass-fed or no antibiotics)');
    });

    test('several claims: two names, +N more, mixed verification', () {
      final cats = {
        FATCategory.feed: const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'Grass Fed (100% forage)',
            credibility: ClaimCredibility.producerAffidavit),
        FATCategory.animalWelfare: const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'Certified Humane',
            credibility: ClaimCredibility.verified),
        FATCategory.medicine: const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'No Antibiotics Ever',
            credibility: ClaimCredibility.producerAffidavit),
        FATCategory.qualityPalatability: const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'USDA Choice',
            credibility: ClaimCredibility.usdaApproved),
      };
      expect(MeterCardText.claimPillText(cats),
          '3 raising claims: "Grass Fed", "Certified Humane" +1 more — mixed verification');
      expect(MeterCardText.strongestClaimTier(cats), ClaimCredibility.verified);
    });

    test('two claims in one tier name the tier', () {
      final cats = {
        FATCategory.medicine: const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'No Antibiotics Ever',
            credibility: ClaimCredibility.producerAffidavit),
        FATCategory.hormones: const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'No Hormones Administered',
            credibility: ClaimCredibility.producerAffidavit),
      };
      expect(MeterCardText.claimPillText(cats),
          '2 raising claims: "No Antibiotics Ever", "No Hormones Administered" — Producer Affidavit');
    });
  });

  group('ingredient-statement line', () {
    test('prepared with INGREDIENTS lists the lane species; count unchanged',
        () {
      final r = _evaluate(chickenBites);
      final before = (
        _count(r.cats, DisclosureStatus.known),
        _count(r.cats, DisclosureStatus.notRequired),
      );
      expect(
          MeterCardText.ingredientStatementLine(
              isPreparedFood: r.prepared, scannedText: chickenBites),
          'Ingredient statement: on the label — lists: chicken');
      final after = _evaluate(chickenBites);
      expect((
        _count(after.cats, DisclosureStatus.known),
        _count(after.cats, DisclosureStatus.notRequired),
      ), before);
    });

    test('prepared without INGREDIENTS shows neutral not-found wording; '
        'count unchanged', () {
      final r = _evaluate(stewFrontOnly);
      expect(r.prepared, isTrue);
      final known = _count(r.cats, DisclosureStatus.known);
      final na = _count(r.cats, DisclosureStatus.notRequired);
      expect(
          MeterCardText.ingredientStatementLine(
              isPreparedFood: r.prepared, scannedText: stewFrontOnly),
          "Ingredient statement: not found in the photos (it may be on a panel you didn't photograph)");
      final again = _evaluate(stewFrontOnly);
      expect(_count(again.cats, DisclosureStatus.known), known);
      expect(_count(again.cats, DisclosureStatus.notRequired), na);
    });

    test('OCR-tolerant spelling is found; lane gate is unchanged', () {
      const ocr = 'BEEF STEW INGREDlENTS: BEEF, WATER';
      expect(PreparedFoodDetector.hasIngredientStatement(ocr), isTrue);
      expect(PreparedFoodDetector.detect(ocr).signals,
          isNot(contains('ingredient-statement')));
    });

    test('not on the prepared lane → no line', () {
      expect(
          MeterCardText.ingredientStatementLine(
              isPreparedFood: false,
              scannedText: 'INGREDIENTS: PORK, WATER, SALT'),
          isNull);
    });
  });
}
