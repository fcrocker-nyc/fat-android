// Cell-cultivated (lab-grown) awareness line — mirrors iOS
// FATAppMVP2Tests/CellCultivatedDetailTests.swift (same fixtures, same
// expectations).
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/cell_cultivated_detail.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/interpreter/prepared_food.dart';
import 'package:fat_app/interpreter/seafood_detail_lines.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

const expectedLine =
    'This label says the product is cell-cultivated: grown from animal cells rather than from a slaughtered animal. USDA must preapprove the labels of cell-cultivated meat and poultry; FDA oversees cell-cultivated seafood.';

const positives = <String>[
  'Cell-Cultivated Chicken',
  'CELL-CULTIVATED CHICKEN',
  'cell cultivated chicken',
  'Cell-Cultured Salmon',
  'cell cultured pork fat',
  'Lab-Grown Meat',
  'lab grown',
  'Cultivated Chicken',
  'cultivated pork fat',
  'Cultured Meat',
  'cultured meats',
  'cultured salmon',
  'cultivated seafood',
  'cultured fish',
  'cultivated turkey',
  'cultured duck',
  'cultivated lamb',
  'cultured beef',
  'cultivated poultry',
  // OCR line breaks and hyphen variants
  'CELL-\nCULTIVATED CHICKEN',
  'CELL -\n CULTIVATED',
  'CELL\nCULTIVATED CHICKEN',
  'cell–cultivated chicken',
  'cell‑cultured',
  'cell‐cultivated',
  'cell—cultivated',
  'lab­grown',
  'CELL- CULTIVATED',
  'CULTI-\nVATED CHICKEN',
  'cultured\nchicken',
  'cultivated-chicken',
  'Ingredients: cell-cultivated chicken, salt.',
];

const negatives = <String>[
  'cultured celery',
  'cultured dextrose',
  'cultured milk',
  'cultured sugar',
  'cultured wheat',
  'cultivated mushrooms',
  'cultivated blueberries',
  'CULTURED CELERY POWDER',
  'Ingredients: pork, water, salt, cultured celery powder, cherry powder.',
  'Ingredients: chicken, water, cultured dextrose, vinegar.',
  'cultured celery juice powder, beef',
  'cultured buttermilk',
  'cultured pasteurized milk',
  'uncultured beef',
  'cellular chicken',
  'lab results',
  'boneless skinless chicken breast',
  '',
  'Real beef. Never lab-grown.',
  'NOT LAB-GROWN',
  '100% real chicken, not cell-cultivated',
  'Free of cell-cultured ingredients',
  'non-lab-grown beef',
];

// ── Fixture labels ──

const cellChicken = '''
CELL-CULTIVATED CHICKEN
INGREDIENTS: CELL-CULTIVATED CHICKEN, SALT.
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. P-47
KEEP REFRIGERATED''';

/// The same label without the cell-cultivated wording.
final plainChicken = cellChicken.replaceAll('CELL-CULTIVATED ', '');

const cellSoup = '''
CELL-CULTIVATED CHICKEN NOODLE SOUP
INGREDIENTS: CHICKEN BROTH, CELL-CULTIVATED CHICKEN, ENRICHED EGG NOODLES,
CARROTS, CELERY, SALT
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. P-47''';

const cellSalmon = '''
CELL-CULTIVATED SALMON SAKU
INGREDIENTS: CELL-CULTIVATED COHO SALMON CELLS
KEEP REFRIGERATED''';

/// Mirrors the scan flow: meat interpreter, then the prepared-lane transform
/// when the detector fires.
FATResult scanMeat(String text) {
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

FATResult scanSeafood(String text) {
  final si = SeafoodInterpreter.interpret(text);
  return FATResult(
    scannedText: text,
    categories: const {},
    productType: ProductType.seafood,
    seafoodCategories: si.categories,
    isSiluriformes: si.isSiluriformes,
    productionMethod: si.productionMethod,
    productionSystem: si.productionSystem,
    detectedEstablishmentNumber: si.detectedEstablishmentNumber,
  );
}

List<String> cat10(FATResult r) =>
    (SeafoodDetailLines.forResult(r)[SeafoodCategory.productionMethodFeed] ??
            const <SeafoodDetailLine>[])
        .map((l) => l.text)
        .toList();

void main() {
  group('detector', () {
    test('line text is exact', () {
      expect(CellCultivatedDetail.line, expectedLine);
    });

    for (final t in positives) {
      test('matches: ${t.replaceAll('\n', r'\n')}', () {
        expect(CellCultivatedDetail.detect(t), isTrue);
      });
    }

    for (final t in negatives) {
      test('does not match: ${t.replaceAll('\n', r'\n')}', () {
        expect(CellCultivatedDetail.detect(t), isFalse);
      });
    }
  });

  group('meat / poultry lane', () {
    test('line appears under Species for Cell-Cultivated Chicken', () {
      final r = scanMeat(cellChicken);
      expect(r.isPreparedFood, isFalse);
      expect(CellCultivatedDetail.meatLines(r), [expectedLine]);
      expect(CellCultivatedDetail.meatLines(scanMeat(plainChicken)), isEmpty);
    });

    test('statuses and count unchanged versus the plain label', () {
      final cell = scanMeat(cellChicken);
      final plain = scanMeat(plainChicken);
      CellCultivatedDetail.meatLines(cell);
      for (final c in FATCategory.values) {
        expect(cell.categories[c]?.status ?? DisclosureStatus.missing,
            plain.categories[c]?.status ?? DisclosureStatus.missing,
            reason: '$c changed');
      }
      expect(cell.knownCount, plain.knownCount);
      expect(cell.partialCount, plain.partialCount);
      expect(cell.missingCount, plain.missingCount);
    });

    test('meat lane never adds a seafood line', () {
      expect(SeafoodDetailLines.forResult(scanMeat(cellChicken)), isEmpty);
    });
  });

  test('prepared / multi-ingredient lane shows the line', () {
    final r = scanMeat(cellSoup);
    expect(r.isPreparedFood, isTrue);
    expect(CellCultivatedDetail.meatLines(r), [expectedLine]);
  });

  group('seafood lane', () {
    test('line appears under Feed / Production Method', () {
      final r = scanSeafood(cellSalmon);
      expect(cat10(r), contains(expectedLine));
      expect(CellCultivatedDetail.meatLines(r), isEmpty);
    });

    test('statuses unchanged versus the plain label', () {
      final plainText = cellSalmon.replaceAll('CELL-CULTIVATED ', '');
      final cell = scanSeafood(cellSalmon);
      final plain = scanSeafood(plainText);
      SeafoodDetailLines.forResult(cell);
      for (final c in SeafoodCategory.values) {
        expect(cell.seafoodCategories[c]?.status ?? DisclosureStatus.missing,
            plain.seafoodCategories[c]?.status ?? DisclosureStatus.missing,
            reason: '$c changed');
      }
      expect(cat10(plain), isNot(contains(expectedLine)));
    });
  });
}
