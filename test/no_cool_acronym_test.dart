// Guard: the unexplained acronym "COOL" (country-of-origin labeling) must not
// appear in user-facing text. Code identifiers and comments may still use it.
// Mirrors iOS FATAppMVP2Tests/NoCOOLAcronymTests.swift.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/fish_name_lookup.dart';
import 'package:fat_app/interpreter/meter_card_text.dart';

final _cool = RegExp(r'\bCOOL\b');

void _allStrings(Object? v, String path, List<MapEntry<String, String>> out) {
  if (v is String) {
    out.add(MapEntry(path, v));
  } else if (v is List) {
    for (var i = 0; i < v.length; i++) {
      _allStrings(v[i], '$path[$i]', out);
    }
  } else if (v is Map) {
    v.forEach((k, val) => _allStrings(val, '$path.$k', out));
  }
}

void main() {
  test('menu glossary has no standalone COOL in any field', () {
    final json = jsonDecode(
        File('assets/data/menu_claim_glossary.json').readAsStringSync());
    final strings = <MapEntry<String, String>>[];
    _allStrings(json, r'$', strings);
    expect(strings.length, greaterThan(100));
    for (final e in strings) {
      expect(_cool.hasMatch(e.value), isFalse, reason: '${e.key}: ${e.value}');
    }
  });

  test('main copy constants have no standalone COOL', () {
    final copy = <String>[
      FishNameLookup.coolTitle,
      FishNameLookup.coolRequirement,
      FishNameLookup.coolExemptions,
      FishNameLookup.simpTitle,
      FishNameLookup.simpCoveredDetail,
      FishNameLookup.bycatchTail,
      FishNameLookup.footer,
      MeterCardText.noRaisingClaimsLine,
      MeterCardText.noSourcingClaimsLine,
      MeterCardText.ingredientFoundLine,
      MeterCardText.ingredientNotFoundLine,
    ];
    for (final q in ['grouper', 'tilapia', 'asdfgh']) {
      final r = FishNameLookup.resolve(q);
      copy.add(r.title);
      for (final s in r.sections) {
        copy.add(s.title);
        copy.addAll(s.lines.map((l) => l.text));
      }
    }
    for (final s in copy) {
      expect(_cool.hasMatch(s), isFalse, reason: s);
    }
  });

  // Source scan: no Dart string literal under lib/ contains the standalone
  // word COOL (comments are allowed).
  test('no Dart string literal in lib/ contains standalone COOL', () {
    final literal = RegExp(
        "'(?:[^'\\\\]|\\\\.)*'" r'|"(?:[^"\\]|\\.)*"');
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.length, greaterThan(20));
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in literal.allMatches(line)) {
          if (_cool.hasMatch(m.group(0)!)) hits.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'String literals containing COOL: $hits');
  });
}
