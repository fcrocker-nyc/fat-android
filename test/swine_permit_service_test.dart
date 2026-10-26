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
    expect(s.cardLines, [s.countLine, s.npdesLine, ...s.ncLines]);
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
    expect(s.unpublishedLine, isNull);    expect(s.iowaLines, [
      'In the Iowa records, 200 of 447 hog operations received at least one notice of violation or letter of non-compliance from the Iowa Department of Natural Resources, 75 of them in the last five years.',
      '85 of these 200 had one from an inspection, complaint or spill; for the other 115, the notices were issued only after paperwork reviews, such as manure management plans.',
      'Manure spills are on record for 11 of the 447 Iowa hog operations.',
      "Source: Iowa DNR Field Office Compliance database, retrieved October 24, 2026. It tracks field-office actions since about 2009 and does not include enforcement by DNR's central office.",
    ]);
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
    expect(s.parentLine, isNull);    expect(s.iowa!.records, 947);
    expect(s.iowa!.cited, 440);
    expect(s.iowa!.citedFiveYears, 149);
    expect(s.iowa!.fieldCited, 152);
    expect(s.iowa!.manureSpills, 8);
    expect(s.cardLines.indexOf(s.iowaLines.first), 2);
  });

  test('Iowa compliance: only plants with Iowa operations; no Iowa lines elsewhere', () {
    expect(data.iowaComplianceRetrieved, '2026-10-24');
    expect(data.summaryFor('560', plantParentName: 'Smithfield Foods')!.iowaLines, isEmpty);
    expect(data.summaryFor('3907', plantParentName: 'Seaboard Foods')!.iowaLines, isEmpty);
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

  test('Iowa DNR compliance sentence variants', () {
    SwinePermitSummary mk(Map<String, int> by, SwineIowaCompliance c) =>
        SwinePermitSummary(
          radiusMiles: 50,
          total: by.values.fold(0, (a, b) => a + b),
          byState: by,
          lagoonStates: const [],
          lagoonCount: 0,
          npdesStates: const [],
          npdesCount: 0,
          sources: by.keys.map((c) => data.states[c]!).toList(),
          unpublished: const [],
          parent: null,
          parentHoldings: 0,
          parentStates: const [],
          iowa: c,
          iowaRetrieved: '2026-10-24',
        );
    const source =
        "Source: Iowa DNR Field Office Compliance database, retrieved October 24, 2026. It tracks field-office actions since about 2009 and does not include enforcement by DNR's central office.";
    expect(mk({'IA': 947}, const SwineIowaCompliance(947, 440, 149, 152, 8)).iowaLines, [
      'Iowa Department of Natural Resources field-office records show 440 of these 947 Iowa hog operations received at least one notice of violation or letter of non-compliance, 149 of them in the last five years.',
      '152 of these 440 had one from an inspection, complaint or spill; for the other 288, the notices were issued only after paperwork reviews, such as manure management plans.',
      'Manure spills are on record for 8 of the 947 Iowa hog operations.',
      source,
    ]);
    expect(mk({'IA': 447, 'MN': 1136}, const SwineIowaCompliance(447, 200, 75, 85, 0)).iowaLines.first,
        'In the Iowa records, 200 of 447 hog operations received at least one notice of violation or letter of non-compliance from the Iowa Department of Natural Resources, 75 of them in the last five years.');
    // Fewer record pages than Iowa operations: never says "these".
    expect(mk({'IA': 10}, const SwineIowaCompliance(9, 2, 0, 0, 0)).iowaLines.take(2), [
      'In the Iowa records, 2 of 9 hog operations received at least one notice of violation or letter of non-compliance from the Iowa Department of Natural Resources, none of them in the last five years.',
      'All of these notices were issued after paperwork reviews, such as manure management plans.',
    ]);
    expect(mk({'IA': 3}, const SwineIowaCompliance(3, 0, 0, 0, 1)).iowaLines, [
      'Iowa Department of Natural Resources field-office records show no notice of violation or letter of non-compliance for these 3 Iowa hog operations.',
      'Manure spills are on record for 1 of the 3 Iowa hog operations.',
      source,
    ]);
    expect(mk({'IA': 1}, const SwineIowaCompliance(1, 1, 1, 1, 0)).iowaLines.take(2), [
      'Iowa Department of Natural Resources field-office records show this Iowa hog operation received at least one notice of violation or letter of non-compliance, most recently within the last five years.',
      'It was issued after an inspection, complaint or spill, not a paperwork review.',
    ]);
    expect(mk({'IA': 4}, const SwineIowaCompliance(4, 2, 1, 2, 0)).iowaLines[1],
        'Each of these operations had one from an inspection, complaint or spill, not just a paperwork review.');
    // No Iowa object → no Iowa lines; card lines keep their order.
    final none = mk({'MN': 2}, const SwineIowaCompliance(0, 0, 0, 0, 0));
    expect(SwinePermitSummary(
      radiusMiles: 50, total: 2, byState: const {'MN': 2}, lagoonStates: const [],
      lagoonCount: 0, npdesStates: const [], npdesCount: 0,
      sources: [data.states['MN']!], unpublished: const [], parent: null,
      parentHoldings: 0, parentStates: const []).iowaLines, isEmpty);
    expect(none.cardLines.indexOf(none.iowaLines.first), 1);
    expect(SwineIowaCompliance.fromJson({'j': 0, 'v': 0}), isNull);
    expect(SwineIowaCompliance.fromJson('x'), isNull);
  });

  test('NC DEQ compliance: Clinton NC (560) and sentence variants', () {
    final s = data.summaryFor('560', plantParentName: 'Smithfield Foods')!;
    expect(data.ncComplianceRetrieved, '2026-10-24');
    expect(s.iowaLines, isEmpty);
    expect(s.ncLines, [
      'North Carolina Department of Environmental Quality records show 246 of these 1,523 North Carolina hog operations received at least one notice of violation, 134 of them in the last five years.',
      '45 operations were assessed a civil penalty. 458 operations received a notice of deficiency, a lesser finding, but no notice of violation.',
      'Source: NC DEQ Division of Water Resources document records, retrieved October 24, 2026. Itemized records begin around 2018; older files are scanned in bulk and not counted.',
    ]);
    expect(s.cardLines.indexOf(s.ncLines.first), greaterThan(0));
    SwinePermitSummary mk(Map<String, int> by, SwineNcCompliance c) =>
        SwinePermitSummary(
          radiusMiles: 50,
          total: by.values.fold(0, (a, b) => a + b),
          byState: by,
          lagoonStates: const [],
          lagoonCount: 0,
          npdesStates: const [],
          npdesCount: 0,
          sources: by.keys.map((c) => data.states[c]!).toList(),
          unpublished: const [],
          parent: null,
          parentHoldings: 0,
          parentStates: const [],
          nc: c,
          ncRetrieved: '2026-10-24',
        );
    expect(mk({'NC': 5, 'MN': 3}, const SwineNcCompliance(5, 2, 0, 1, 1)).ncLines.take(2), [
      'In the North Carolina records, 2 of 5 hog operations received at least one notice of violation from the North Carolina Department of Environmental Quality, none of them in the last five years.',
      '1 operation was assessed a civil penalty. 1 operation received a notice of deficiency, a lesser finding, but no notice of violation.',
    ]);
    expect(mk({'NC': 3}, const SwineNcCompliance(3, 0, 0, 0, 0)).ncLines.first,
        'North Carolina Department of Environmental Quality records show no notice of violation for these 3 North Carolina hog operations.');
    expect(mk({'NC': 3}, const SwineNcCompliance(3, 0, 0, 0, 0)).ncLines.length, 2);
    expect(mk({'NC': 1}, const SwineNcCompliance(1, 1, 1, 0, 0)).ncLines.first,
        'North Carolina Department of Environmental Quality records show this North Carolina hog operation received at least one notice of violation, most recently within the last five years.');
    expect(SwineNcCompliance.fromJson({'j': 0}), isNull);
  });

  test('IDEM compliance: Tyson Logansport (2484)', () {
    final s = data.summaryFor('2484', plantParentName: 'Tyson Foods')!;
    expect(data.inComplianceRetrieved, '2026-10-25');
    expect(s.indianaLines, [
      'Indiana Department of Environmental Management records show 41 of these 533 Indiana hog operations received a notice of violation or other formal enforcement action, 4 of them in the last five years.',
      "31 operations settled a case through an agreed order or were issued a commissioner's order.",
      'Source: IDEM Virtual File Cabinet, Confined Feeding enforcement documents, retrieved October 25, 2026. Scanned records are sparse before 2009.',
    ]);
    expect(s.missouriLines, isEmpty);
  });

  test('MoDNR compliance: Macon MO (3736) and a mixed Iowa/Missouri plant (3228)', () {
    final s = data.summaryFor('3736')!;
    expect(data.moComplianceRetrieved, '2026-10-25');
    expect(s.missouriLines, [
      'Missouri Department of Natural Resources records show at least 68 of these 82 Missouri hog operations received a letter of warning or notice of violation, 42 of them in the last five years.',
      '22 operations received a notice of violation, the more serious of the two.',
      'Source: Missouri DNR Letters of Warning and Notices of Violation search, retrieved October 25, 2026, matched by farm name and county. Records start in 2009, and DNR says the search holds most but not all of these letters.',
    ]);
    final m = data.summaryFor('3228')!;
    expect(m.missouriLines.first,
        'In the Missouri records, at least 25 of 31 hog operations received a letter of warning or notice of violation from the Missouri Department of Natural Resources, 12 of them in the last five years.');
    expect(m.iowaLines, isNotEmpty);
    expect(m.cardLines.indexOf(m.iowaLines.first) < m.cardLines.indexOf(m.missouriLines.first), isTrue);
    expect(SwineMoCompliance.fromJson({'j': 0}), isNull);
    expect(SwineInCompliance.fromJson({'j': 0}), isNull);
  });

  test('Nebraska DWEE compliance: Tyson Madison (8262); Seaboard Triumph adds NE after IA', () {
    final s = data.summaryFor('8262', plantParentName: 'Tyson Foods')!;
    expect(data.neComplianceRetrieved, '2026-10-26');
    expect(s.nebraskaLines, [
      'Nebraska Department of Water, Energy, and Environment records show 76 of these 1,167 Nebraska hog operations received a notice of violation, letter of noncompliance or other enforcement action, 8 of them in the last five years.',
      '33 operations faced formal legal action, such as an administrative or consent order.',
      'Source: Nebraska DWEE public document index, retrieved October 26, 2026. Documents are imaged from about 2011, and many operations have none on file, so these counts are minimums.',
    ]);
    final m = data.summaryFor('6163274', plantParentName: 'Seaboard Foods')!;
    expect(m.nebraskaLines.first,
        'In the Nebraska records, 29 of 407 hog operations received a notice of violation, letter of noncompliance or other enforcement action from the Nebraska Department of Water, Energy, and Environment, 4 of them in the last five years.');
    expect(m.cardLines.indexOf(m.iowaLines.first) < m.cardLines.indexOf(m.nebraskaLines.first), isTrue);
    expect(SwineNeCompliance.fromJson({'j': 0}), isNull);
  });

  test('Michigan EGLE compliance (via ECHO): Saranac (7173)', () {
    final s = data.summaryFor('7173')!;
    expect(data.miComplianceRetrieved, '2026-10-25');
    expect(s.michiganLines, [
      'Michigan Department of Environment, Great Lakes, and Energy records show 46 of these 52 Michigan hog operations received a violation notice or warning letter, 34 of them in the last five years.',
      '23 operations received a notice of violation, the more serious notice. 7 operations entered a consent order with the state.',
      "Source: Michigan EGLE actions on state-issued Clean Water Act permits, from EPA's ECHO enforcement data, as of October 25, 2026.",
    ]);
    expect(SwineMiCompliance.fromJson({'j': 0}), isNull);
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
    for (final id in ['560', '728', '2938', '6163274', '3907', '3228', '2484', '3736', '8262', '7173']) {
      final s = data.summaryFor(id, plantParentName: 'Smithfield Foods')!;
      lines.addAll([s.countLine, s.npdesLine, s.unpublishedLine, s.parentLine]
          .whereType<String>());
      lines.addAll(s.iowaLines);
      lines.addAll(s.ncLines);
      lines.addAll(s.indianaLines);
      lines.addAll(s.missouriLines);
      lines.addAll(s.nebraskaLines);
      lines.addAll(s.michiganLines);
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
