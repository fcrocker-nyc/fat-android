// Market-concentration block (species selection, no data → nothing) and the
// Send/Share payload (N color label photos + 1 color evaluation image).
// Mirrors iOS FATAppMVP2Tests/ShareAndConcentrationTests.swift.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/data/market_concentration.dart';
import 'package:fat_app/data/pork_owner_database.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/widgets/disclosure_share_card.dart';
import 'package:fat_app/widgets/share_card_renderer.dart';

void main() {
  group('MarketConcentrationSummary', () {
    test('Smithfield / WH Group on pork uses the pork table', () {
      final s = MarketConcentrationSummary.resolve(
          labelSpecies: 'Pork',
          brandCompany: 'WH Group (Shuanghui International)')!;
      expect(s.species, MeatSpecies.pork);
      expect(s.ownerId, 'whgroup');
      expect(s.basis, ConcentrationBasis.brand);
      expect(s.marketLine,
          'US pork processing: the top 3 firms handle about 61% of production (top 7 ≈ 80%). HHI ≈ 1,620 — moderately concentrated.');
      expect(s.companyLine,
          'WH Group (Shuanghui International): about 27% of US pork processing.');
      expect(s.foreignLine,
          'Foreign-owned: ultimately owned by a company headquartered in China.');
    });

    test('Tyson on a beef label uses the beef table, not pork', () {
      final s = MarketConcentrationSummary.resolve(
          labelSpecies: 'Beef', brandCompany: 'Tyson Foods, Inc.')!;
      expect(s.ownerId, 'tyson_beef');
      expect(s.marketLine,
          'US beef processing: the top 4 firms handle about 80% of production. HHI ≈ 2,000 — moderately concentrated.');
      expect(s.companyLine,
          'Tyson Fresh Meats (Beef): about 23% of US beef processing.');
      expect(s.foreignLine, isNull);
    });

    test('JBS beef is foreign-owned', () {
      final s = MarketConcentrationSummary.resolve(
          labelSpecies: 'Beef', brandCompany: 'JBS USA Food Company')!;
      expect(s.companyLine, 'JBS USA (Beef): about 25% of US beef processing.');
      expect(s.foreignLine,
          'Foreign-owned: ultimately owned by a company headquartered in Brazil.');
    });

    test('no data → nothing', () {
      expect(
          MarketConcentrationSummary.resolve(
              labelSpecies: 'Beef',
              brandCompany: 'WH Group (Shuanghui International)'),
          isNull);
      expect(
          MarketConcentrationSummary.resolve(
              labelSpecies: null, brandCompany: 'Tyson Foods, Inc.'),
          isNull);
      expect(
          MarketConcentrationSummary.resolve(
              labelSpecies: 'Lamb', brandCompany: 'Tyson Foods, Inc.'),
          isNull);
      expect(
          MarketConcentrationSummary.resolve(
              labelSpecies: 'Pork',
              brandCompany: 'Kroger Co.',
              scannedText: 'pork chops'),
          isNull);
    });

    test('parent from the establishment when no brand', () {
      final s = MarketConcentrationSummary.resolve(
          labelSpecies: 'Pork', estParentName: 'WH Group Limited')!;
      expect(s.ownerId, 'whgroup');
      expect(s.basis, ConcentrationBasis.establishment);
    });

    test('turkey and chicken lines', () {
      final t = MarketConcentrationSummary.resolve(
          labelSpecies: 'Turkey', scannedText: 'butterball whole turkey')!;
      expect(t.ownerId, 'butterball');
      expect(t.marketLine, contains('top 3 firms handle about 50%'));
      expect(t.marketLine, contains('unconcentrated'));
      final c = MarketConcentrationSummary.resolve(
          labelSpecies: 'Chicken', brandCompany: 'Tyson Foods, Inc.')!;
      expect(c.ownerId, 'tyson_chicken');
      expect(c.marketLine,
          startsWith('US broiler processing: the top 5 firms handle about 70% of production.'));
    });
  });

  group('Share payload', () {
    test('N label photos then 1 evaluation image', () {
      final files = buildShareFiles(
          labelImagePaths: ['/a.jpg', '/b.jpg'], evaluationImagePath: '/e.png');
      expect(files.map((f) => f.path).toList(), ['/a.jpg', '/b.jpg', '/e.png']);
      expect(files.last.mimeType, 'image/png');
    });

    test('caps label photos at 4', () {
      final files = buildShareFiles(
          labelImagePaths: List.generate(6, (i) => '/$i.jpg'),
          evaluationImagePath: '/e.png');
      expect(files.length, 5);
    });
  });

  testWidgets('evaluation card uses status colors, not the gray ramp',
      (tester) async {
    const text =
        'Smithfield Hickory Smoked Bacon. Pork. Product of USA. No antibiotics ever. USDA Inspected. EST. 18079';
    final result = FATResult(
        scannedText: text,
        categories: LabelInterpreter.interpret(text),
        detectedEstablishmentNumber: '18079');
    await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
            child: DisclosureShareCard(result: result))));
    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color ?? c.color)
        .whereType<Color>()
        .toSet();
    expect(colors, contains(DisclosureShareCard.disclosedGreen));
    expect(colors, contains(DisclosureShareCard.missingRed));
    expect(find.text('What This Label Discloses'), findsOneWidget);
  });
}
