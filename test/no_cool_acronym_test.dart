// Guard: unexplained regulatory acronyms must not appear in user-facing text.
// Covers COOL (country-of-origin labeling), SIMP (NOAA's Seafood Import
// Monitoring Program), AMS (USDA's Agricultural Marketing Service), FSIS
// (USDA meat and poultry inspection), HACCP (required food-safety plan) and
// NOP (USDA organic standards). Code identifiers and comments may still use
// them. Guideline identifiers (FSIS-GD-2024-0006) and the title of FAT
// Research Paper No. 6 are citations and stay verbatim.
// Mirrors iOS FATAppMVP2Tests/NoCOOLAcronymTests.swift.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/cell_cultivated_detail.dart';
import 'package:fat_app/interpreter/fish_name_lookup.dart';
import 'package:fat_app/interpreter/meter_card_text.dart';
import 'package:fat_app/interpreter/seafood_detail_lines.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/util/plain_language.dart';

import 'establishment_fixtures.dart';

final _acronym = RegExp(r'\b(?:COOL|SIMP|AMS|FSIS(?!-GD-)|HACCP|NOP)\b');

/// Citations quoted verbatim (titles of published works).
const _allowedCitations = [
  'Grass-Fed vs. Grass-Finished: What FSIS Actually Recognizes',
];

bool _hasAcronym(String s) {
  var t = s;
  for (final c in _allowedCitations) {
    t = t.replaceAll(c, '');
  }
  return _acronym.hasMatch(t);
}

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

/// Drops a trailing `//` comment that sits outside any string literal.
String _stripLineComment(String line) {
  final out = StringBuffer();
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < line.length) {
        out.write(line[++i]);
      } else if (c == quote) {
        quote = null;
      }
    } else {
      if (c == '/' && i + 1 < line.length && line[i + 1] == '/') break;
      if (c == "'" || c == '"') quote = c;
      out.write(c);
    }
  }
  return out.toString();
}

void main() {
  test('menu glossary has no standalone acronym in any field', () {
    final json = jsonDecode(
        File('assets/data/menu_claim_glossary.json').readAsStringSync());
    final strings = <MapEntry<String, String>>[];
    _allStrings(json, r'$', strings);
    expect(strings.length, greaterThan(100));
    for (final e in strings) {
      expect(_hasAcronym(e.value), isFalse, reason: '${e.key}: ${e.value}');
    }
  });

  test('main copy constants have no standalone acronym', () {
    final copy = <String>[
      FishNameLookup.coolTitle,
      FishNameLookup.coolRequirement,
      FishNameLookup.coolExemptions,
      FishNameLookup.simpTitle,
      FishNameLookup.simpCoveredDetail,
      FishNameLookup.snapperUnclear,
      FishNameLookup.crabUnclear,
      FishNameLookup.codNote,
      FishNameLookup.simpGroupsLine,
      FishNameLookup.unknownSectionTitle,
      FishNameLookup.bycatchTail,
      FishNameLookup.footer,
      MeterCardText.noRaisingClaimsLine,
      MeterCardText.noSourcingClaimsLine,
      MeterCardText.ingredientFoundLine,
      MeterCardText.ingredientNotFoundLine,
      SeafoodDetailLines.simpCovered,
      CellCultivatedDetail.line,
    ];
    // Category display names (incl. Cat 1 "USDA Required Language" and
    // Cat 15 "Organic (USDA)").
    copy.addAll(FATCategory.values.map((c) => c.displayName));
    copy.addAll(SeafoodCategory.values.map((c) => c.displayName));
    for (final t in ClaimCredibility.values) {
      copy.addAll([t.displayName, t.explanation, t.seafoodDisplayName]);
    }
    for (final q in ['grouper', 'tilapia', 'snapper', 'cod', 'asdfgh']) {
      final r = FishNameLookup.resolve(q);
      copy.add(r.title);
      copy.add(r.historyTitle);
      for (final s in r.sections) {
        copy.add(s.title);
        copy.addAll(s.lines.map((l) => l.text));
      }
    }
    for (final s in copy) {
      expect(_hasAcronym(s), isFalse, reason: s);
    }
  });

  // Feed/server text the app doesn't author is passed through PlainLanguage
  // before display.
  test('feed and server text is rewritten for display', () {
    final json = jsonDecode(
        File('assets/data/brand_data.json').readAsStringSync()) as Map;
    final caveats = (json['crosswalk'] as List)
        .map((e) => (e as Map)['app_display_caveat'])
        .whereType<String>()
        .toList();
    expect(caveats.any(_hasAcronym), isTrue,
        reason: 'fixture should exercise the rewrite');
    for (final c in caveats) {
      expect(_hasAcronym(PlainLanguage.consumerText(c)), isFalse, reason: c);
    }
    expect(
        PlainLanguage.consumerText(
            'Federal bridge for meat is FSIS (EST number on label), not FDA.'),
        'Federal bridge for meat is USDA (EST number on label), not FDA.');
    expect(
        PlainLanguage.consumerText(
            'Seafood HACCP violations; USDA/FSIS; FSIS-GD-2024-0006'),
        'Seafood food-safety plan violations; USDA; FSIS-GD-2024-0006');

    final r = EstablishmentsService.decode(r245)!;
    expect(_hasAcronym(r.note!), isFalse, reason: r.note);
  });

  // Source scan: no Dart string literal under lib/ contains a standalone
  // acronym (line and block comments are allowed).
  test('no Dart string literal in lib/ contains a standalone acronym', () {
    final literal = RegExp(
        "'(?:[^'\\\\]|\\\\.)*'" r'|"(?:[^"\\]|\\.)*"');
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // The rewriter's own patterns name the acronyms by design.
        .where((f) => !f.path.endsWith('plain_language.dart'))
        .toList();
    expect(files.length, greaterThan(20));
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      var inBlock = false;
      String? inTriple;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (inBlock) {
          if (line.contains('*/')) inBlock = false;
          continue;
        }
        if (inTriple != null) {
          if (_hasAcronym(line)) hits.add('${f.path}:${i + 1}');
          if (inTriple.allMatches(line).length.isOdd) inTriple = null;
          continue;
        }
        if (trimmed.startsWith('//')) continue;
        if (trimmed.startsWith('/*') && !trimmed.contains('*/')) {
          inBlock = true;
          continue;
        }
        for (final q in ["'''", '"""']) {
          if (q.allMatches(line).length.isOdd) inTriple = q;
        }
        if (inTriple != null && _hasAcronym(line)) {
          hits.add('${f.path}:${i + 1}');
        }
        for (final m in literal.allMatches(_stripLineComment(line))) {
          if (_hasAcronym(m.group(0)!)) hits.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'String literals containing an acronym: $hits');
  });
}
