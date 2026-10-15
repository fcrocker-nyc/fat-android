// Fish-name lookup (Lookup → Seafood → Fish name). Mirrors iOS
// FATAppMVP2Tests/FishNameLookupTests.swift. Both apps compare their resolver
// output against the same test/fish_name_lookup_baseline.json (written by the
// iOS test, copied verbatim here).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/fish_name_lookup.dart';
import 'package:fat_app/interpreter/seafood_bycatch.dart';
import 'package:fat_app/interpreter/seafood_detail_lines.dart';
import 'package:fat_app/models/fat_models.dart';

/// Shared fixture queries (identical list on iOS).
const fixtureQueries = [
  'grouper',
  'mahi mahi',
  'dolphinfish',
  'Mahi-Mahi',
  'salmon',
  'Atlantic salmon',
  'snapper',
  'red snapper',
  'rockfish',
  'Pacific snapper',
  'cod',
  'black cod',
  'crab',
  'king crab',
  'shrimp',
  'groupers',
  'tilapia',
  'asdfgh',
];

FishNameResult r(String q) => FishNameLookup.resolve(q);

List<String> texts(FishNameResult r, String title) {
  for (final s in r.sections) {
    if (s.title == title) return s.lines.map((l) => l.text).toList();
  }
  return const [];
}

void main() {
  setUpAll(() {
    MmpaBycatchData.bundled = MmpaBycatchData.fromJsonString(
      File('assets/data/mmpa_bycatch_pairs.json').readAsStringSync(),
    );
  });

  test('grouper: covered, bycatch Indonesia + Vietnam', () {
    final g = r('grouper');
    expect(g.title, 'Grouper');
    expect(g.simpStatus, FishSimpStatus.covered);
    expect(texts(g, FishNameLookup.simpTitle), [
      "Covered by NOAA's Seafood Import Monitoring Program (SIMP).",
      FishNameLookup.simpCoveredDetail,
    ]);
    expect(texts(g, FishNameLookup.bycatchTitle), [
      'NOAA has denied U.S. market access to some grouper fisheries because of marine-mammal bycatch (as of October 2026):',
      'Indonesia — gillnets',
      'Vietnam — gillnets, longlines or trawls',
      FishNameLookup.bycatchTail,
    ]);
    final bycatch = g.sections.firstWhere(
      (s) => s.title == FishNameLookup.bycatchTitle,
    );
    expect(
      bycatch.lines.last.link?.url,
      'https://farmanimaltransparency.com/seafood-research-series-7-bycatch-fda-noaa/',
    );
    expect(g.hasBycatch, isTrue);
    expect(
      texts(g, FishNameLookup.coolTitle).first,
      FishNameLookup.coolRequirement,
    );
    expect(g.historyTitle, 'Grouper — covered by SIMP');
  });

  test('mahi mahi / dolphinfish: covered + bycatch', () {
    for (final q in ['mahi mahi', 'dolphinfish', 'Mahi-Mahi', 'mahi']) {
      final m = r(q);
      expect(m.title, 'Mahi Mahi', reason: q);
      expect(m.simpStatus, FishSimpStatus.covered, reason: q);
      final b = texts(m, FishNameLookup.bycatchTitle);
      expect(b.sublist(1, b.length - 1), [
        'Ecuador — gillnets',
        'Indonesia — gillnets',
        'Vietnam — gillnets or longlines',
      ], reason: q);
    }
  });

  test('salmon: not covered, no bycatch', () {
    final s = r('salmon');
    expect(s.simpStatus, FishSimpStatus.notCovered);
    expect(texts(s, FishNameLookup.simpTitle), [
      "Salmon is not one of the 13 species groups covered by NOAA's Seafood Import Monitoring Program.",
    ]);
    expect(
      s.sections.any((x) => x.title == FishNameLookup.bycatchTitle),
      isFalse,
    );
    expect(s.hasBycatch, isFalse);
    expect(r('Atlantic salmon').simpStatus, FishSimpStatus.notCovered);
  });

  test('bare snapper is ambiguous', () {
    final s = r('snapper');
    expect(s.simpStatus, FishSimpStatus.unclear);
    expect(texts(s, FishNameLookup.simpTitle), [
      "SIMP covers red snapper only; a placard that just says 'snapper' doesn't say which species.",
    ]);
    expect(s.historyTitle, 'Snapper — SIMP coverage unclear');
  });

  test('red snapper covered', () {
    final s = r('red snapper');
    expect(s.title, 'Red Snapper');
    expect(s.simpStatus, FishSimpStatus.covered);
    expect(s.hasBycatch, isTrue);
  });

  test('rockfish / Pacific snapper carry the misbranding note', () {
    for (final q in ['rockfish', 'Pacific snapper', 'pacific red snapper']) {
      final s = r(q);
      expect(s.simpStatus, FishSimpStatus.notCovered, reason: q);
      expect(
        texts(s, FishNameLookup.simpTitle),
        contains(FishNameLookup.rockfishMisbranding),
        reason: q,
      );
      expect(s.hasBycatch, isFalse, reason: q);
      expect(s.hasMisbrandingNote, isTrue, reason: q);
    }
    expect(
      FishNameLookup.rockfishMisbranding,
      'FDA said in April 2026 that rockfish sold as "snapper" is misbranded (91 Fed. Reg. 16200, Apr. 1, 2026, as cited in FAT Seafood Paper No. 7).',
    );
  });

  test('cod covered; black cod is not', () {
    final c = r('cod');
    expect(c.simpStatus, FishSimpStatus.covered);
    expect(
      texts(c, FishNameLookup.simpTitle),
      contains(FishNameLookup.codNote),
    );
    expect(r('black cod').simpStatus, FishSimpStatus.notCovered);
  });

  test('crab ambiguous; king / blue crab covered', () {
    expect(r('crab').simpStatus, FishSimpStatus.unclear);
    expect(r('king crab').simpStatus, FishSimpStatus.covered);
    expect(r('blue crab').simpStatus, FishSimpStatus.covered);
    expect(r('snow crab').simpStatus, FishSimpStatus.notCovered);
  });

  test('gibberish is unknown', () {
    final u = r('asdfgh');
    expect(u.recognized, isFalse);
    expect(u.simpStatus, isNull);
    expect(
      u.sections.first.lines.first.text,
      "FAT doesn't recognize that fish name yet.",
    );
    expect(
      u.sections.first.lines.last.text,
      "NOAA's SIMP covers imports of 13 species groups: abalone, Atlantic cod, blue crab (Atlantic), dolphinfish (mahi mahi), grouper, king crab (red), Pacific cod, red snapper, sea cucumber, sharks, shrimp, swordfish and tuna.",
    );
    expect(u.historyTitle, 'Fish name not recognized');
  });

  test('no line claims "no bycatch" or calls SIMP FDA\'s', () {
    for (final q in fixtureQueries) {
      for (final s in r(q).sections) {
        for (final l in s.lines) {
          expect(
            l.text.toLowerCase().contains('no bycatch'),
            isFalse,
            reason: q,
          );
          expect(l.text.contains("FDA's Seafood Import"), isFalse, reason: q);
        }
      }
    }
  });

  group('scan behaviour (SIMPCoverage fix)', () {
    test('snapper rules', () {
      expect(SIMPCoverage.isCovered('Red Snapper'), isTrue);
      expect(SIMPCoverage.isCovered('Snapper'), isFalse);
      expect(SIMPCoverage.isCovered('Pacific Red Snapper'), isFalse);
      expect(SIMPCoverage.isCovered('Rockfish'), isFalse);
      expect(SIMPCoverage.isCovered('Black Cod'), isFalse);
      expect(SIMPCoverage.isCovered('Cod'), isTrue);
    });

    test('bare Snapper SIMP line', () {
      const imported = FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Indonesia',
      );
      expect(
        SeafoodDetailLines.simpLine(
          species: 'Snapper',
          origin: imported,
          scannedText: 'Wild Caught Snapper\nProduct of Indonesia',
        ),
        isNull,
      );
      expect(
        SeafoodDetailLines.simpLine(
          species: 'Snapper',
          origin: imported,
          scannedText: 'Wild Red Snapper fillets\nProduct of Indonesia',
        ),
        SeafoodDetailLines.simpCovered,
      );
      expect(
        SeafoodDetailLines.simpLine(
          species: 'Red Snapper',
          origin: imported,
          scannedText: 'Pacific Red Snapper\nProduct of Mexico',
        ),
        isNull,
      );
    });
  });

  test('matches the shared iOS/Android baseline', () {
    final doc =
        jsonDecode(
              File('test/fish_name_lookup_baseline.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(doc['queries'], fixtureQueries);
    final base = doc['results'] as Map<String, dynamic>;
    for (final q in fixtureQueries) {
      expect(FishNameLookup.snapshot(r(q)), base[q], reason: q);
    }
  });
}
