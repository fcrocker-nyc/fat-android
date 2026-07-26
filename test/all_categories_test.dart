import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

/// Comprehensive regression tests for all 16 FAT transparency categories.
/// Mirrors AllCategoriesTests.swift on iOS — one test per category.
void main() {
  // Convenience helpers
  Map<FATCategory, FATCategoryResult> interp(String text) =>
      LabelInterpreter.interpret(text);

  DisclosureStatus? status(String text, FATCategory cat) =>
      interp(text)[cat]?.status;

  String? value(String text, FATCategory cat) =>
      interp(text)[cat]?.value;

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 1 — USDA / FSIS Required Language
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 1 — USDA/FSIS Language', () {
    test('inspected and passed', () => expect(
        status('inspected and passed by department of agriculture',
            FATCategory.usdaFsisRequiredLanguage),
        DisclosureStatus.known));
    test('usda inspected', () => expect(
        status('USDA Inspected Ground Beef', FATCategory.usdaFsisRequiredLanguage),
        DisclosureStatus.known));
    test('federally inspected', () => expect(
        status('federally inspected', FATCategory.usdaFsisRequiredLanguage),
        DisclosureStatus.known));
    test('EST number satisfies Cat 1', () => expect(
        status('EST. 45029 Vermont Packinghouse', FATCategory.usdaFsisRequiredLanguage),
        DisclosureStatus.known));
    test('negative', () => expect(
        status('Organic Ranch Beef', FATCategory.usdaFsisRequiredLanguage),
        DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 2 — Species
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 2 — Species', () {
    test('ground beef', () => expect(value('ground beef', FATCategory.species), 'Beef'));
    test('brisket', () => expect(value('brisket flat cut', FATCategory.species), 'Beef'));
    test('pork loin', () => expect(value('pork loin chop', FATCategory.species), 'Pork'));
    test('whole chicken', () => expect(value('whole chicken', FATCategory.species), 'Chicken'));
    test('turkey breast', () => expect(value('turkey breast roast', FATCategory.species), 'Turkey'));
    test('lamb shoulder', () => expect(value('lamb shoulder', FATCategory.species), 'Lamb'));
    test('catfish fillet', () => expect(
        value('catfish fillet wild caught', FATCategory.species), contains('Catfish')));
    test('swai', () => expect(value('swai fillet', FATCategory.species), contains('Catfish')));
    test('negative', () => expect(
        status('fresh product natural', FATCategory.species), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 3 — Breed
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 3 — Breed', () {
    test('angus', () => expect(value('100% angus beef', FATCategory.breed), contains('Angus')));
    test('wagyu', () => expect(value('wagyu strip steak', FATCategory.breed), contains('Wagyu')));
    test('berkshire', () => expect(value('berkshire pork chop', FATCategory.breed), contains('Berkshire')));
    test('negative', () => expect(
        status('ground beef no antibiotics', FATCategory.breed), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 4 — Country / Origin
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 4 — Country/Origin', () {
    test('product of usa', () => expect(
        status('product of usa', FATCategory.countryOrigin), DisclosureStatus.known));
    test('made in usa', () => expect(
        status('made in usa', FATCategory.countryOrigin), DisclosureStatus.known));
    test('born in / raised in', () => expect(
        status('born in montana raised in wyoming', FATCategory.countryOrigin),
        DisclosureStatus.known));
    test('negative', () => expect(
        status('natural grass fed beef', FATCategory.countryOrigin), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 5 — Farm / Ranch (generic = Partial, not Known)
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 5 — Farm/Ranch', () {
    test('family farm = partial', () => expect(
        status('family farm raised angus beef', FATCategory.farmRanch), DisclosureStatus.partial));
    test('ranch raised = partial', () => expect(
        status('ranch raised', FATCategory.farmRanch), DisclosureStatus.partial));
    test('negative', () => expect(
        status('ground beef est 1234', FATCategory.farmRanch), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 6 — Age at Slaughter
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 6 — Age at Slaughter', () {
    test('broiler', () => expect(
        status('broiler chicken breast', FATCategory.ageAtSlaughter), DisclosureStatus.known));
    test('fryer', () => expect(
        status('fryer parts', FATCategory.ageAtSlaughter), DisclosureStatus.known));
    test('roaster', () => expect(
        status('roasting chicken', FATCategory.ageAtSlaughter), DisclosureStatus.known));
    test('cornish game hen', () => expect(
        status('cornish game hen', FATCategory.ageAtSlaughter), DisclosureStatus.known));
    test('stewing hen', () => expect(
        status('stewing hen', FATCategory.ageAtSlaughter), DisclosureStatus.known));
    test('veal = partial', () => expect(
        status('veal cutlet', FATCategory.ageAtSlaughter), DisclosureStatus.partial));
    test('lamb = partial', () => expect(
        status('lamb chop', FATCategory.ageAtSlaughter), DisclosureStatus.partial));
    test('plain chicken no class term = missing', () => expect(
        status('whole chicken no antibiotics', FATCategory.ageAtSlaughter),
        DisclosureStatus.missing));
    test('beef = missing', () => expect(
        status('ground beef product of usa', FATCategory.ageAtSlaughter),
        DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 7 — Processor
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 7 — Processor', () {
    test('EST present = known', () => expect(
        status('EST. 45029 Vermont Packinghouse Ground Beef', FATCategory.processor),
        DisclosureStatus.known));
    test('no EST = missing', () => expect(
        status('ground beef no est number', FATCategory.processor), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 10 — Feed
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 10 — Feed', () {
    test('grass fed', () => expect(
        status('grass fed ground beef', FATCategory.feed),
        isNot(DisclosureStatus.missing)));
    test('grassfed (one word)', () => expect(
        status('grassfed beef', FATCategory.feed),
        isNot(DisclosureStatus.missing)));
    test('100% grass fed', () => expect(
        status('100% grass fed walden local beef', FATCategory.feed),
        isNot(DisclosureStatus.missing)));
    test('grain fed', () => expect(
        status('grain fed beef', FATCategory.feed),
        isNot(DisclosureStatus.missing)));
    test('80% grass fed = partial', () => expect(
        status('80% grass fed beef', FATCategory.feed), DisclosureStatus.partial));
    test('no feed claim = missing', () => expect(
        status('ground beef est 1234', FATCategory.feed), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 11 — Animal Welfare
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 11 — Animal Welfare', () {
    test('certified humane', () => expect(
        status('certified humane raised and handled', FATCategory.animalWelfare),
        DisclosureStatus.known));
    test('animal welfare approved', () => expect(
        status('animal welfare approved by a greener world', FATCategory.animalWelfare),
        DisclosureStatus.known));
    test('global animal partnership', () => expect(
        status('global animal partnership step 4', FATCategory.animalWelfare),
        DisclosureStatus.known));
    test('cage free', () => expect(
        status('cage free eggs', FATCategory.animalWelfare), DisclosureStatus.known));
    test('negative', () => expect(
        status('ground beef product of usa', FATCategory.animalWelfare),
        DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 12 — Medicine / Antibiotics
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 12 — Medicine', () {
    test('no antibiotics ever', () => expect(
        status('no antibiotics ever', FATCategory.medicine), DisclosureStatus.known));
    test('raised without antibiotics', () => expect(
        status('raised without antibiotics', FATCategory.medicine), DisclosureStatus.known));
    test('antibiotic free', () => expect(
        status('antibiotic free chicken', FATCategory.medicine), DisclosureStatus.known));
    // Newly added medication terms (fix 2026-07-26)
    test('no medications', () => expect(
        status('no medications given', FATCategory.medicine), DisclosureStatus.known));
    test('no added medications', () => expect(
        status('no added medications', FATCategory.medicine), DisclosureStatus.known));
    test('medication free', () => expect(
        status('medication free beef', FATCategory.medicine), DisclosureStatus.known));
    test('negative', () => expect(
        status('natural grass fed beef', FATCategory.medicine), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 13 — Hormones
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 13 — Hormones', () {
    test('no hormones administered', () => expect(
        status('no hormones administered', FATCategory.hormones), DisclosureStatus.known));
    test('no added hormones', () => expect(
        status('no added hormones', FATCategory.hormones), DisclosureStatus.known));
    test('hormone free', () => expect(
        status('hormone free beef', FATCategory.hormones), DisclosureStatus.known));
    test('raised without hormones', () => expect(
        status('raised without hormones', FATCategory.hormones), DisclosureStatus.known));
    test('never ever hormones', () => expect(
        status('never ever hormones', FATCategory.hormones), DisclosureStatus.known));
    test('negative', () => expect(
        status('grass fed ground beef no antibiotics', FATCategory.hormones),
        DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 14 — Quality / Palatability
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 14 — Quality', () {
    test('usda prime', () => expect(
        status('usda prime ribeye steak', FATCategory.qualityPalatability),
        DisclosureStatus.known));
    test('usda choice', () => expect(
        status('usda choice ground beef', FATCategory.qualityPalatability),
        DisclosureStatus.known));
    test('usda select', () => expect(
        status('usda select sirloin', FATCategory.qualityPalatability),
        DisclosureStatus.known));
    test('negative', () => expect(
        status('angus ground beef', FATCategory.qualityPalatability),
        DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 15 — Organic
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 15 — Organic', () {
    test('usda organic', () => expect(
        status('usda organic chicken breast', FATCategory.organic), DisclosureStatus.known));
    test('certified organic', () => expect(
        status('certified organic grass fed beef', FATCategory.organic), DisclosureStatus.known));
    test('100% organic', () => expect(
        status('100% organic ground beef', FATCategory.organic), DisclosureStatus.known));
    test('bare organic = partial', () => expect(
        status('organic rancher beef', FATCategory.organic), DisclosureStatus.partial));
    test('negative', () => expect(
        status('natural grass fed beef', FATCategory.organic), DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cat 16 — Supply-Chain Intermediary
  // ─────────────────────────────────────────────────────────────────────────

  group('Cat 16 — Supply-Chain Intermediary', () {
    test('five rivers (packer-owned feedlot)', () => expect(
        status('finished at five rivers cattle feeding greeley co',
            FATCategory.supplyChainIntermediary),
        DisclosureStatus.known));
    test('days on feed', () => expect(
        status('days on feed 180', FATCategory.supplyChainIntermediary),
        DisclosureStatus.known));
    test('contract grower', () => expect(
        status('contract grower network', FATCategory.supplyChainIntermediary),
        DisclosureStatus.known));
    test('NPDES permit', () => expect(
        status('npdes co0050009', FATCategory.supplyChainIntermediary),
        DisclosureStatus.known));
    test('grain finished = partial', () => expect(
        status('grain finished angus beef', FATCategory.supplyChainIntermediary),
        DisclosureStatus.partial));
    test('negative', () => expect(
        status('grass fed ground beef no antibiotics ever',
            FATCategory.supplyChainIntermediary),
        DisclosureStatus.missing));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Full-label integration: Walden Local Grass Fed Ground Beef
  // ─────────────────────────────────────────────────────────────────────────

  group('Full label — Walden Local', () {
    const label = '''
walden local meat co
grass fed ground beef
est. 45029 vermont packinghouse
no antibiotics ever
no added hormones
pasture raised
product of usa
1 lb 80% lean
inspected and passed by department of agriculture
''';
    late Map<FATCategory, FATCategoryResult> cats;
    setUpAll(() => cats = LabelInterpreter.interpret(label));

    test('Cat 1 — USDA language', () =>
        expect(cats[FATCategory.usdaFsisRequiredLanguage]?.status, DisclosureStatus.known));
    test('Cat 2 — species = Beef', () =>
        expect(cats[FATCategory.species]?.value, 'Beef'));
    test('Cat 4 — country', () =>
        expect(cats[FATCategory.countryOrigin]?.status, DisclosureStatus.known));
    test('Cat 7 — processor (EST)', () =>
        expect(cats[FATCategory.processor]?.status, DisclosureStatus.known));
    test('Cat 10 — feed (grass fed)', () =>
        expect(cats[FATCategory.feed]?.status, isNot(DisclosureStatus.missing)));
    test('Cat 12 — medicine', () =>
        expect(cats[FATCategory.medicine]?.status, DisclosureStatus.known));
    test('Cat 13 — hormones', () =>
        expect(cats[FATCategory.hormones]?.status, DisclosureStatus.known));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Full-label integration: bare commodity beef (maximum unknowns)
  // ─────────────────────────────────────────────────────────────────────────

  group('Full label — commodity beef', () {
    const label = '80% lean 20% fat ground beef 1 lb';
    late Map<FATCategory, FATCategoryResult> cats;
    setUpAll(() => cats = LabelInterpreter.interpret(label));

    test('Cat 2 — species resolved', () =>
        expect(cats[FATCategory.species]?.value, 'Beef'));
    test('Cat 1 — missing', () =>
        expect(cats[FATCategory.usdaFsisRequiredLanguage]?.status, DisclosureStatus.missing));
    test('Cat 7 — missing', () =>
        expect(cats[FATCategory.processor]?.status, DisclosureStatus.missing));
    test('Cat 12 — missing', () =>
        expect(cats[FATCategory.medicine]?.status, DisclosureStatus.missing));
    test('Cat 13 — missing', () =>
        expect(cats[FATCategory.hormones]?.status, DisclosureStatus.missing));
    test('Cat 15 — missing', () =>
        expect(cats[FATCategory.organic]?.status, DisclosureStatus.missing));
  });
}
