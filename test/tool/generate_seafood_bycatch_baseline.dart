// Writes test/seafood_bycatch_baseline.json — per-category statuses, seafood
// index and Cat. 10 value for each bycatch fixture from the PRE-bycatch
// interpreter (run once, before the catch-method / bycatch change, and
// committed):
//
//   FAT_WRITE_BASELINE=1 flutter test test/tool/generate_seafood_bycatch_baseline.dart
//
// Without FAT_WRITE_BASELINE=1 it only prints the JSON. No `_test` suffix, so a
// plain `flutter test` never runs it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

import '../seafood_bycatch_fixtures.dart';
import 'generate_seafood_v11_baseline.dart' as v11;

void main() {
  test('generate seafood bycatch baseline', () {
    final out = <String, dynamic>{
      'generated': '2026-10-12',
      'note': 'Pre-bycatch SeafoodInterpreter output (before catch-method / bycatch lines). Brand resolver not loaded.',
      'fixtures': {
        for (final e in seafoodBycatchFixtures.entries)
          '${e.key}': {
            'text': e.value,
            ...v11.snapshot(e.value),
            'cat10Value': SeafoodInterpreter.interpret(e.value)
                .categories[SeafoodCategory.productionMethodFeed]
                ?.value,
          },
      },
    };
    final json = const JsonEncoder.withIndent('  ').convert(out);
    if (Platform.environment['FAT_WRITE_BASELINE'] == '1') {
      File('test/seafood_bycatch_baseline.json').writeAsStringSync('$json\n');
    } else {
      // ignore: avoid_print
      print(json);
    }
  });
}
