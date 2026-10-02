// EST false positives from the Nutrition Facts panel ("Cholest. 80mg" read as
// EST 80) and retail-exemption misfires on national-brand packages.
// Mirrors iOS FATAppMVP2Tests/EstRetailExemptionTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/interpreter/retail_exemption.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  // Bianco & Sons-like chicken thighs: nutrition panel, no real EST.
  const bianco = '''
BIANCO & SONS PUMPKIN SPICE CHICKEN THIGHS
BONELESS SKINLESS CHICKEN THIGH MEAT
Nutrition Facts Serving size 4 oz (112g)
Calories 190 Total Fat 11g 14% Saturated Fat 3g 15%
Cholest. 80mg 27% Sodium 380mg 17%
Total Carb. 2g 1% Protein 20g
KEEP REFRIGERATED
''';

  // Pilgrim's Air Fryer BBQ wings: inspected, national brand, no EST read.
  const pilgrims = '''
PILGRIM'S AIR FRYER BBQ SEASONED CRISPY WINGS
FULLY COOKED CHICKEN WING SECTIONS
INSPECTED FOR WHOLESOMENESS BY U.S. DEPARTMENT OF AGRICULTURE
DISTRIBUTED BY PILGRIM'S PRIDE CORPORATION, GREELEY, CO 80634
KEEP FROZEN  BEST IF USED BY 08/2027
Nutrition Facts Calories 230 Total Fat 15g Cholest. 80mg 27% Sodium 640mg
PACKED BY PILGRIM'S PRIDE CORPORATION
''';

  // In-store Kroger scale label.
  const kroger = '''
KROGER
80% LEAN 20% FAT GROUND BEEF
GROUND IN STORE
PACKED ON 09/12 SELL BY 09/15
\$/LB 5.99 TOTAL PRICE 8.43
2 01234 56789 0
''';

  group('EST extraction — Nutrition Facts false positives', () {
    test('(1) Cholest. 80mg alone yields no EST', () {
      expect(LabelInterpreter.extractEstablishmentNumber(_norm(bianco)), isNull);
      expect(LabelInterpreter.extractEstablishmentNumber(bianco.toLowerCase()),
          isNull);
      expect(SeafoodInterpreter.extractEstablishmentNumber(_norm(bianco)),
          isNull);
    });

    test('(2) Cholest. 80mg plus EST. 4033 yields 4033', () {
      final t = _norm('$bianco\nEST. 4033');
      expect(LabelInterpreter.extractEstablishmentNumber(t), '4033');
      expect(SeafoodInterpreter.extractEstablishmentNumber(t), '4033');
    });

    test('(3) P-4033 yields 4033', () {
      expect(LabelInterpreter.extractEstablishmentNumber(
          _norm('$bianco\nP-4033')), '4033');
    });

    test('cholesterol variants and unit-suffixed numbers are rejected', () {
      for (final s in [
        'cholest 80mg', 'cholesterol 80mg', 'chol est. 80mg',
        'chol. est 80 mg', 'est. 80mg', 'est 80 %', 'est. 12 oz', 'est 5 g',
      ]) {
        expect(LabelInterpreter.extractEstablishmentNumber(s), isNull,
            reason: s);
        expect(SeafoodInterpreter.extractEstablishmentNumber(s), isNull,
            reason: 'seafood: $s');
      }
      // Words ending in "est" never act as the prefix.
      expect(LabelInterpreter.extractEstablishmentNumber('forest 12345'),
          isNull);
      expect(LabelInterpreter.extractEstablishmentNumber('highest 500'),
          isNull);
    });

    test('existing true positives still read', () {
      final cases = {
        'est. 38': '38',
        'usda est 245l': '245L',
        'est. 969g': '969G',
        'est#1234': '1234',
        'p-1250': '1250',
        'p 1250': '1250',
        'p1250': '1250',
        'establishment number 4033': '4033',
        'u.s. inspected and passed by department of agriculture est. 38': '38',
        'chicken noodle soup p-est 123 inspected for wholesomeness': '123',
        'cholest. 80mg 27% ... est. 4033': '4033',
      };
      cases.forEach((input, want) {
        expect(LabelInterpreter.extractEstablishmentNumber(input), want,
            reason: input);
      });
    });
  });

  group('Retail exemption — national packages vs in-store', () {
    test('(4) Pilgrim\'s wings: not exempt and no EST', () {
      final n = _norm(pilgrims);
      expect(LabelInterpreter.extractEstablishmentNumber(n), isNull);
      expect(
        RetailExemptionDetector.detect(n, estFound: false, isMeat: true)
            .isExempt,
        isFalse,
      );
      expect(LabelInterpreter.detectRetailExemption(pilgrims).isExempt,
          isFalse);
      expect(RetailExemptionDetector.nationalPackageEvidence(n), isNotNull);
    });

    test('(5) in-store Kroger ground beef: exempt', () {
      final r = LabelInterpreter.detectRetailExemption(kroger);
      expect(r.isExempt, isTrue);
      expect(r.storeName, 'Kroger');
    });

    test('freshly ground in our meat department: exempt', () {
      expect(
        RetailExemptionDetector.detect(
          _norm('Ground beef 85% lean. Freshly ground in our meat department.'),
          estFound: false,
          isMeat: true,
        ).isExempt,
        isTrue,
      );
    });

    test('bare "packed by" / "processed by" no longer exempts', () {
      for (final s in [
        'chicken breasts packed by acme poultry co',
        'pork chops processed by hometown meats',
      ]) {
        expect(
          RetailExemptionDetector.detect(s, estFound: false, isMeat: true)
              .isExempt,
          isFalse,
          reason: s,
        );
      }
    });

    test('"<verb> for/by <grocer>" still exempts', () {
      for (final s in [
        'beef stew meat packed for kroger',
        'ground beef ground fresh for safeway',
        'pork loin cut by publix',
      ]) {
        expect(
          RetailExemptionDetector.detect(s, estFound: false, isMeat: true)
              .isExempt,
          isTrue,
          reason: s,
        );
      }
    });

    test('two scale fields alone no longer exempt', () {
      expect(
        RetailExemptionDetector.detect(
          'chicken thighs sell by 10/02 packed on 09/28',
          estFound: false,
          isMeat: true,
        ).isExempt,
        isFalse,
      );
    });

    test('random-weight UPC needs a scale field', () {
      expect(
        RetailExemptionDetector.detect(
          'beef short ribs lot 212345678901',
          estFound: false,
          isMeat: true,
        ).isExempt,
        isFalse,
      );
      expect(
        RetailExemptionDetector.detect(
          'beef short ribs total price 9.12 212345678901',
          estFound: false,
          isMeat: true,
        ).isExempt,
        isTrue,
      );
    });

    test('distributed by a grocer does not block', () {
      expect(
        RetailExemptionDetector.detect(
          'ground beef ground in store distributed by the kroger co. cincinnati',
          estFound: false,
          isMeat: true,
        ).isExempt,
        isTrue,
      );
    });
  });
}
