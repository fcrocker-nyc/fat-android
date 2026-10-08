// State swine permit records near a pork plant (informational only).
// Uses the published dataset itself (swine-permits/fat_swine_permits.json) and
// real fat/v1/establishments fixtures. Numbers are pinned to that file.
// Mirrors iOS FATAppMVP2Tests/SwinePermitServiceTests.swift.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/services/swine_permit_service.dart';

import 'nc_hog_lagoon_notice_test.dart' show r413, r18079, meat;

void main() {
  late SwinePermitData data;

  setUpAll(() {
    data = SwinePermitData.parse(
        File('swine-permits/fat_swine_permits.json').readAsStringSync())!;
  });

  (double, double) point(String json, String mark) {
    final o = EstablishmentsService.scanOutcome(
        null, mark, EstablishmentsService.decode(json)!);
    return EstablishmentsService.proximityPoint(o.record, o.shared)!;
  }

  test('dataset: per-state counts and sources', () {
    expect(data.states.keys.toSet(),
        {'NC', 'MN', 'MO', 'IA', 'NE', 'IN', 'MI'});
    expect(data.states['NC']!.count, 1962);
    expect(data.states['NC']!.date, '2026-04-23');
    expect(data.states['NC']!.lagoonData, isTrue);
    expect(data.states['MO']!.lagoonData, isTrue);
    expect(data.states['IA']!.ownerData, isFalse);
    expect(data.records.length,
        data.states.values.fold<int>(0, (a, s) => a + s.count));
    expect(data.stateAt(34.9938, -78.3101), 'NC');
    expect(data.stateAt(43.6773, -92.9671), 'MN');
  });

  test('Clinton NC (413): count, lagoons, Murphy-Brown parent line (50 mi)', () {
    final (lat, lon) = point(r413, '413');
    final s = data.summarize(lat, lon, plantParentName: 'Smithfield Foods');
    expect(s.total, 1484);
    expect(s.lagoonCount, 1470);
    expect(s.parentHoldings, 61);
    expect(s.radiusMiles, 50);
    expect(s.countLine,
        'State permit records list 1,484 hog operations within 50 miles of this plant (sources: NC DEQ, April 2026), 1,470 of them with at least one waste lagoon.');
    // South Carolina is beyond 50 miles of Clinton, so no not-published note.
    expect(s.unpublishedLine, isNull);
    expect(s.parentLine,
        "The plant's parent company (Smithfield Foods) holds state permits for at least 61 hog farms within 50 miles (North Carolina permit records). Contract farms are listed under growers' own names, so this is a minimum.");
  });

  test('Tar Heel NC (shared 18079, both NC): point + parent line', () {
    final (lat, lon) = point(r18079, '18079');
    final s = data.summarize(lat, lon, plantParentName: 'Smithfield Foods');
    expect(s.total, 935);
    expect(s.lagoonCount, 924);
    expect(s.parentHoldings, 75);
    expect(s.parentLine, contains('at least 75 hog farms within 50 miles'));
    expect(s.unpublishedLine,
        'Data not published by South Carolina — not counted.');
  });

  test('WH Group (on-device crosswalk name) maps to the same parent', () {
    final (lat, lon) = point(r413, '413');
    final s = data.summarize(lat, lon, plantParentName: 'WH Group Limited');
    expect(s.parentHoldings, 61);
  });

  test('MN plant (Austin, Hormel): MPCA count, no parent line', () {
    final s = data.summarize(43.677287001013, -92.967141965855,
        plantParentName: 'Hormel Foods');
    expect(s.total, 1409);
    expect(s.byState['MN'], 940);
    expect(s.byState['IA'], 469);
    expect(s.countLine, contains('MPCA, October 2026'));
    expect(s.countLine, isNot(contains('lagoon')));
    expect(s.parentLine, isNull);
    // Wisconsin is beyond 50 miles of Austin.
    expect(s.unpublishedLine, isNull);
  });

  test('OK plant (Guymon): not-published note, no count line', () {
    final s = data.summarize(36.71841292603, -101.449021704155,
        plantParentName: 'Seaboard Foods');
    expect(s.total, 0);
    expect(s.countLine, isNull);
    expect(s.parentLine, isNull);
    expect(s.unpublishedLine,
        'Data not published by Colorado, Kansas, Oklahoma, or Texas — not counted.');
  });

  test('KS / IL / OH / SD plants: not-published note', () {
    for (final (lat, lon, st) in [
      (37.9759, -100.8727, 'Kansas'), // Garden City KS
      (39.9938, -90.4045, 'Illinois'), // Beardstown IL
      (40.10, -82.98, 'Ohio'), // Columbus OH
      (43.5446, -96.7311, 'South Dakota'), // Sioux Falls SD
    ]) {
      final s = data.summarize(lat, lon);
      expect(s.unpublishedLine, contains(st), reason: st);
      expect(s.parentLine, isNull);
    }
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
    // MN Tyson buying stations and the Hormel Austin pens are not in the data.
    expect(
        data.records.where((r) =>
            r.state == 'MN' &&
            ((r.name ?? '').contains('Hog Buying Station') ||
                (r.name ?? '').contains('Austin Plant'))),
        isEmpty);
  });

  test('statuses and count unchanged by the permit lookup', () {
    final r = meat('Pork');
    final before =
        FATCategory.values.map((c) => r.categories[c]?.status).toList();
    final count = r.knownCount;
    final (lat, lon) = point(r413, '413');
    final s = data.summarize(lat, lon, plantParentName: 'Smithfield Foods');
    expect(s.parentLine, isNotNull);
    expect(FATCategory.values.map((c) => r.categories[c]?.status).toList(),
        before);
    expect(r.knownCount, count);
  });

  test('copy: banned words absent; never says the pork came from the farms',
      () {
    final lines = <String>[];
    for (final (lat, lon) in [
      (34.993816947096, -78.310104011702),
      (40.2, -93.12),
      (36.71841292603, -101.449021704155),
    ]) {
      final s = data.summarize(lat, lon, plantParentName: 'Smithfield Foods');
      lines.addAll([s.countLine, s.unpublishedLine, s.parentLine]
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
