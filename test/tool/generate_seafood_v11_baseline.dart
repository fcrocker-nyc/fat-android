// Writes test/seafood_v11_baseline.json — the pre-v1.1 per-category statuses
// and seafood index for each Seafood v1.1 fixture. Run ONLY against the
// pre-v1.1 interpreter (it was run once, before Task 1, and committed):
//
//   FAT_WRITE_BASELINE=1 flutter test test/tool/generate_seafood_v11_baseline.dart
//
// Without FAT_WRITE_BASELINE=1 it only prints the JSON. The file name has no
// `_test` suffix, so a plain `flutter test` never runs it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

import '../seafood_v11_fixtures.dart';

Map<String, dynamic> snapshot(String text) {
  final si = SeafoodInterpreter.interpret(text);
  final r = FATResult(
    scannedText: text,
    categories: const {},
    productType: ProductType.seafood,
    seafoodCategories: si.categories,
    isSiluriformes: si.isSiluriformes,
    productionMethod: si.productionMethod,
    detectedEstablishmentNumber: si.detectedEstablishmentNumber,
  );
  return {
    'categories': {
      for (final c in SeafoodCategory.values)
        c.name: (si.categories[c]?.status ?? DisclosureStatus.missing).name,
    },
    'seafoodIndex': r.seafoodFatScore,
    'disclosurePercent': r.seafoodDisclosurePercent,
    'credibilityPercent': r.seafoodCredibilityPercent,
  };
}

void main() {
  test('generate seafood v1.1 baseline', () {
    final out = <String, dynamic>{
      'generated': '2026-09-29',
      'note': 'Pre-v1.1 SeafoodInterpreter output (branch seafood-v1.1-farmed-salmon, before Task 1). Brand resolver not loaded (brand/who reflect no alias match).',
      'fixtures': {
        for (final e in seafoodV11Fixtures.entries)
          '${e.key}': {'text': e.value, ...snapshot(e.value)},
      },
    };
    final json = const JsonEncoder.withIndent('  ').convert(out);
    if (Platform.environment['FAT_WRITE_BASELINE'] == '1') {
      File('test/seafood_v11_baseline.json').writeAsStringSync('$json\n');
    } else {
      // ignore: avoid_print
      print(json);
    }
  });
}
