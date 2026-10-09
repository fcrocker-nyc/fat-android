// Hog operations near a pork plant (informational only), from the published
// per-plant aggregate file (swine-permits/fat_swine_nearby.json) and real
// fat/v1/establishments fixtures. Numbers are pinned to that file.
// Mirrors iOS FATAppMVP2Tests/SwinePermitServiceTests.swift.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/services/swine_permit_service.dart';

import 'nc_hog_lagoon_notice_test.dart' show r413, r18079, r79, meat;

void main() {
  late SwinePermitData data;
  late String raw;

  setUpAll(() {
    raw = File('swine-permits/fat_swine_nearby.json').readAsStringSync();
    data = SwinePermitData.parse(raw)!;
  });

  String? key(String json, String mark) {
    final o = EstablishmentsService.scanOutcome(
        null, mark, EstablishmentsService.decode(json)!);
    return SwinePermitData.plantKey(o.record, o.shared);
  }

  test('dataset: states, sources, NPDES flags', () {
    expect(data.states.keys.toSet(),
        {'NC', 'MN', 'MO', 'IA', 'NE', 'IN', 'MI'});
    expect(data.radiusMiles, 50);
    expect(data.states['NC']!.count, 1987);
    expect(data.states['MN']!.count, 5543);
    expect(data.states['IA']!.count, 8816);
    expect(data.states['NC']!.lagoonData, isTrue);
    expect(data.states['MO']!.lagoonData, isTrue);
    expect(data.states['IA']!.lagoonData, isFalse);
    for (final s in ['NC', 'MN', 'MO', 'IA', 'IN', 'MI']) {
      expect(data.states[s]!.npdesData, isTrue, reason: s);
    }
    expect(data.states['NE']!.npdesData, isFalse);
  });

  test('privacy: aggregates only — no rows, names, coordinates or permit ids',
      () {
    expect(raw.contains('"r":'), isFalse);
    expect(raw.contains('"lat"'), isFalse);
    expect(raw.contains('"lon"'), isFalse);
    // Company names appear only in the method notes (the parent mapping).
    final plants = raw.substring(raw.lastIndexOf('"plants":{'));
    for (final s in [
      'Murphy', 'Seaboard Foods LLC', 'AWS3', 'AWI0', 'MNG44', 'MOG01',
      'MOGS1', 'ING80', 'MIG01', 'NCA2', 'Farm', 'LLC'
    ]) {
      expect(plants.contains(s), isFalse, reason: s);
    }
  });

  test('plant key: resolved plant, shared within 10 mi, mixed-state shared', () {
    expect(key(r413, '413'), '560');
    expect(key(r18079, '18079'), '728'); // both candidates in Tar Heel
    // Kapolei HI + Wilson NC candidates: no location guess, no count.
    expect(
        SwinePermitData.plantKey(
            null, EstablishmentsService.decode(r79)!.establishments),
        isNull);
    expect(data.summaryFor(null), isNull);
    expect(data.summaryFor('no-such-plant'), isNull);
  });

  test('Clinton NC (413): count, lagoons, NPDES, Murphy-Brown parent line', () {
    final s = data.summaryFor(key(r413, '413'),
        plantParentName: 'Smithfield Foods')!;
    expect(s.total, 1523);
    expect(s.lagoonCount, 1431);
    expect(s.npdesCount, 1);
    expect(s.parentHoldings, 70);
    expect(s.countLine,
        'State permit records list 1,523 hog operations within 50 miles of this plant (sources: NC DEQ, January 2024), 1,431 of them with at least one waste lagoon.');
    expect(s.npdesLine,
        "Of these, 1 holds a federal Clean Water Act (NPDES) permit; the other 1,522 don't appear in EPA's database.");
    // South Carolina is beyond 50 miles of Clinton, so no not-published note.
    expect(s.unpublishedLine, isNull);
    expect(s.parentLine,
        "The plant's parent company (Smithfield Foods) holds state permits for at least 70 hog farms within 50 miles (North Carolina permit records). Contract farms are listed under growers' own names, so this is a minimum.");
    expect(s.cardLines, [s.countLine, s.npdesLine]);
  });

  test('Tar Heel NC (shared 18079, both NC): first candidate + parent line', () {
    final s = data.summaryFor(key(r18079, '18079'),
        plantParentName: 'Smithfield Foods')!;
    expect(s.total, 952);
    expect(s.lagoonCount, 899);
    expect(s.npdesCount, 1);
    expect(s.parentHoldings, 86);
    expect(s.parentLine, contains('at least 86 hog farms within 50 miles'));
    expect(s.unpublishedLine,
        'Data not published by South Carolina — not counted.');
  });

  test('WH Group (on-device crosswalk name) maps to the same parent', () {
    final s = data.summaryFor('560', plantParentName: 'WH Group Limited')!;
    expect(s.parentHoldings, 70);
  });

  test('MN plant (Hormel, Austin): MPCA + Iowa DNR, NPDES line, no parent', () {
    final s = data.summaryFor('2938', plantParentName: 'Hormel Foods')!;
    expect(s.total, 1583);
    expect(s.byState['MN'], 1136);
    expect(s.byState['IA'], 447);
    expect(s.countLine,
        'State permit records list 1,583 hog operations within 50 miles of this plant (sources: Iowa DNR, April 2024; MPCA, October 2026).');
    expect(s.npdesLine,
        "Of these, 152 hold a federal Clean Water Act (NPDES) permit; the other 1,431 don't appear in EPA's database.");
    expect(s.parentLine, isNull);
    // Wisconsin is beyond 50 miles of Austin.
    expect(s.unpublishedLine, isNull);
  });

  test('IA plant (Seaboard Triumph, Sioux City): NE has no NPDES flag', () {
    final s = data.summaryFor('6163274', plantParentName: 'Seaboard Foods')!;
    expect(s.total, 1354);
    expect(s.byState, {'IA': 947, 'NE': 407});
    expect(s.npdesStates, ['IA']);
    expect(s.npdesLine,
        "In the Iowa records, 15 of 947 hold a federal Clean Water Act (NPDES) permit; the rest don't appear in EPA's database.");
    expect(s.unpublishedLine,
        'Data not published by South Dakota — not counted.');
    expect(s.parentLine, isNull);
  });

  test('OK plant (Seaboard, Guymon): not-published note only', () {
    final s = data.summaryFor('3907', plantParentName: 'Seaboard Foods')!;
    expect(s.total, 0);
    expect(s.countLine, isNull);
    expect(s.npdesLine, isNull);
    expect(s.parentLine, isNull);
    expect(s.unpublishedLine,
        'Data not published by Colorado, Kansas, Oklahoma, or Texas — not counted.');
  });

  test('NPDES sentence variants', () {
    SwinePermitSummary mk(Map<String, int> by, int k) => SwinePermitSummary(
          radiusMiles: 50,
          total: by.values.fold(0, (a, b) => a + b),
          byState: by,
          lagoonStates: const [],
          lagoonCount: 0,
          npdesStates: by.keys
              .where((c) => by[c]! > 0 && data.states[c]!.npdesData)
              .toList()
            ..sort(),
          npdesCount: k,
          sources: by.keys.map((c) => data.states[c]!).toList(),
          unpublished: const [],
          parent: null,
          parentHoldings: 0,
          parentStates: const [],
        );
    expect(mk({'MI': 3}, 3).npdesLine,
        'All 3 hold a federal Clean Water Act (NPDES) permit.');
    expect(mk({'MN': 2}, 1).npdesLine,
        "Of these, 1 holds a federal Clean Water Act (NPDES) permit; the other one doesn't appear in EPA's database.");
    expect(mk({'NE': 5}, 0).npdesLine, isNull);
    expect(mk({'IA': 4, 'NE': 2}, 0).npdesLine,
        "In the Iowa records, 0 of 4 hold a federal Clean Water Act (NPDES) permit; the rest don't appear in EPA's database.");
  });

  test('exact-name ownership: verified names map, look-alikes do not', () {
    for (final n in [
      'Murphy-Brown LLC',
      'MURPHY-BROWN OF MISSOURI LLC',
      'Murphy Brown of Missouri LLC',
      'Murphy-Brown of Missouri LLC d/b/a Smith',
      'Smithfield Hog Production',
    ]) {
      expect(SwinePermitOwnership.parentForOwner(n), SwineParent.smithfield,
          reason: n);
    }
    expect(SwinePermitOwnership.parentForOwner('Seaboard Foods LLC'),
        SwineParent.seaboard);
    for (final n in [
      'Tyson Five LLC',
      'Louis Tyson',
      'Triumph Associates LLC',
      'Hanor Multiplier',
      'Smithfield Ridge Lc',
      'Smithfield Enterprises LLC',
      'Clemens Unit',
      'Tyson Fresh Meats Inc',
      'Hormel Foods',
      'Chris Murphy',
      'Prestage Farms Inc',
      'Seaboard Foods LP',
      null,
      '',
    ]) {
      expect(SwinePermitOwnership.parentForOwner(n), isNull, reason: n);
    }
  });

  test('statuses and count unchanged by the permit lookup', () {
    final r = meat('Pork');
    final before =
        FATCategory.values.map((c) => r.categories[c]?.status).toList();
    final count = r.knownCount;
    final s = data.summaryFor('560', plantParentName: 'Smithfield Foods')!;
    expect(s.parentLine, isNotNull);
    expect(FATCategory.values.map((c) => r.categories[c]?.status).toList(),
        before);
    expect(r.knownCount, count);
  });

  test('copy: banned words absent; never says the pork came from the farms',
      () {
    final lines = <String>[];
    for (final id in ['560', '728', '2938', '6163274', '3907', '3228']) {
      final s = data.summaryFor(id, plantParentName: 'Smithfield Foods')!;
      lines.addAll([s.countLine, s.npdesLine, s.unpublishedLine, s.parentLine]
          .whereType<String>());
    }
    final all = lines.join(' ').toLowerCase();
    for (final w in [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy'
    ]) {
      expect(RegExp('\\b$w\\b').hasMatch(all), isFalse, reason: w);
    }
    expect(all.contains('came from'), isFalse);
    expect(all.contains('supplied'), isFalse);
  });
}
