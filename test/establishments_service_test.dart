// fat/v1/establishments client + scan disambiguation.
// Mirrors iOS FATAppMVP2Tests/EstablishmentsServiceTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/services/processor_service.dart';

import 'establishment_fixtures.dart';

EstablishmentsResponse resp(String s) => EstablishmentsService.decode(s)!;

ProcessorRecord website(
        {required String digits,
        required String prefix,
        required String street,
        required String city,
        required String state}) =>
    ProcessorRecord.fromJson({
      'establishment': {
        'est_number': digits,
        'est_prefix': prefix,
        'name': 'Website Plant',
        'address': street,
        'city': city,
        'state': state,
        'zip': '00000',
      },
      'enforcement': {
        'recalls': {'has_recalls': true, 'count': 7, 'items': []},
      },
    }, digits: digits);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decode', () {
    test('245 — three plants share the number, note present', () {
      final r = resp(r245);
      expect(r.mode, 'number');
      expect(r.count, 3);
      expect(r.note, contains('more than one FSIS establishment'));
      expect(r.establishments.map((e) => e.establishmentNumber).toList(),
          ['M245J', 'M245C+V245C', 'M245E']);
      expect(r.establishments.map((e) => e.city).toList(),
          ['Hillsdale', 'Dakota City', 'Amarillo']);
      final dakota = r.establishments[1];
      expect(dakota.numberTokens, ['M245C', 'V245C']);
      expect(dakota.digits, '245');
      expect(dakota.recalls, 1);
      expect(dakota.memorandaOfInterview, 1);
      expect(dakota.inspectionTasks, 933);
      expect(dakota.parentCompany, 'Tyson Foods');
      expect(dakota.latestRecall?.recallNumber, '085-2015');
      expect(dakota.latestRecall?.recallClass, 'Class I');
      expect(dakota.salmonella, isNull);
      expect(dakota.recordUrl,
          'https://farmanimaltransparency.com/processor/245/#est-3254');
    });

    test('245C — one plant, empty note treated as absent', () {
      final r = resp(r245C);
      expect(r.count, 1);
      expect(r.note, isNull);
      expect(r.establishments.first.establishmentNumber, 'M245C+V245C');
    });

    test('P-39928 — Mary\'s Harvest, no parent mapping', () {
      final p = resp(rP39928).establishments.single;
      expect(p.establishmentNumber, 'M40310+P39928');
      expect(p.name, "Mary's Harvest Fresh Foods, Inc.");
      expect(p.parentCompany, isNull);
    });

    test('Godshall — name search returns four plants', () {
      final r = resp(rGodshall);
      expect(r.mode, 'name');
      expect(r.count, 4);
      expect(r.establishments.every((e) => e.name.contains('Godshall')), isTrue);
    });

    test('4033 — salmonella category 0 reads as not categorized', () {
      final p = resp(r4033).establishments.single;
      expect(p.name, 'Bianco Inc.');
      expect(p.publicHealthAlerts, 1);
      expect(p.salmonella?.length, 2);
      expect(p.salmonella?.first.category, '0');
      expect(p.salmonellaLine, contains('not categorized'));
      expect(p.hasRecords, isTrue);
    });

    test('tolerates missing / null fields and garbage', () {
      final r = resp(
          '{"establishments":[{"establishment_number":"M1","name":null,"recalls":"2"},{"name":"no number"}]}');
      expect(r.count, 1);
      expect(r.establishments.first.name, '');
      expect(r.establishments.first.recalls, 2);
      expect(r.establishments.first.latestRecall, isNull);
      expect(r.note, isNull);
      expect(EstablishmentsService.decode('<html>'), isNull);
    });
  });

  group('disambiguation', () {
    test('scanned 245C → Dakota City', () {
      final a = EstablishmentsService.resolve('245C', resp(r245));
      expect(a.kind, ResolutionKind.single);
      expect(a.plant!.city, 'Dakota City');
      final b = EstablishmentsService.resolve('245C', resp(r245C));
      expect(b.plant!.establishmentNumber, 'M245C+V245C');
    });

    test('scanned 245 → ambiguous with 3', () {
      final r = EstablishmentsService.resolve('245', resp(r245));
      expect(r.kind, ResolutionKind.ambiguous);
      expect(r.plants.length, 3);
      expect(EstablishmentsService.sharedHeadline(3),
          "This number belongs to 3 FSIS plants — match the city on the package's USDA mark");
    });

    test('scanned 4033 → Bianco Inc.', () {
      final r = EstablishmentsService.resolve('4033', resp(r4033));
      expect(r.plant?.name, 'Bianco Inc.');
    });

    test('scanned P-39928 → plant whose number includes P39928', () {
      final r = EstablishmentsService.resolve('P-39928', resp(rP39928));
      expect(r.plant?.numberTokens, contains('P39928'));
    });

    test('name-mode responses never resolve a scan', () {
      expect(EstablishmentsService.resolve('Godshall', resp(rGodshall)).kind,
          ResolutionKind.notFound);
    });

    test('labelMark keeps P- prefix and letter suffix', () {
      expect(EstablishmentsService.labelMark('245', 'USDA EST. 245C keep'), '245C');
      expect(EstablishmentsService.labelMark('39928', 'INSPECTED P-39928'), 'P39928');
      expect(EstablishmentsService.labelMark('245', 'EST. 245 NET WT 12OZ'), '245');
      expect(EstablishmentsService.labelMark('245C', 'no context'), '245C');
    });
  });

  group('merge with digits-keyed website JSON', () {
    test('same plant keeps website enforcement detail', () {
      final plant = resp(r4033).establishments.single;
      final w = website(
          digits: '4033',
          prefix: 'M',
          street: '1 Brainard Avenue',
          city: 'Medford',
          state: 'MA');
      final out = EstablishmentsService.merge(w, plant);
      expect(out.endpointPlant, isNull);
      expect(out.recallCount, 7);
      expect(out.name, 'Bianco Inc.');
      expect(out.displayEstNumber, 'M4033+P4033');
    });

    test('website JSON for another plant → endpoint counts', () {
      // 245.json currently describes Lexington NE (ML) — not Dakota City.
      final plant = resp(r245C).establishments.single;
      final w = website(
          digits: '245',
          prefix: 'ML',
          street: '1500 Plum Creek Parkway',
          city: 'Lexington',
          state: 'NE');
      final out = EstablishmentsService.merge(w, plant);
      expect(out.endpointPlant?.establishmentNumber, 'M245C+V245C');
      expect(out.recallCount, 1);
      expect(out.city, 'Dakota City');
      expect(out.name, 'Tyson Fresh Meats, Inc.');
      expect(out.hasAnyConcern, isTrue);
    });

    test('prefix conflict rejects even in the same city', () {
      // 39928.json is Olympia Provisions (M39928), Portland; P-39928 is Mary's Harvest.
      final plant = resp(rP39928).establishments.single;
      final w = website(
          digits: '39928',
          prefix: 'M',
          street: '123 SE 2nd Ave.',
          city: 'Portland',
          state: 'OR');
      expect(EstablishmentsService.agrees(w, plant), isFalse);
      expect(EstablishmentsService.merge(w, plant).name,
          "Mary's Harvest Fresh Foods, Inc.");
    });
  });

  test('prefix agrees with any token carrying the digits', () {
    final plant = resp(r4033).establishments.single;
    final w = website(
        digits: '4033',
        prefix: 'P',
        street: '1 Brainard Avenue',
        city: 'Medford',
        state: 'MA');
    expect(EstablishmentsService.agrees(w, plant), isTrue);
  });

  group('scan outcome', () {
    final w = website(
        digits: '245',
        prefix: 'ML',
        street: '1500 Plum Creek Parkway',
        city: 'Lexington',
        state: 'NE');

    test('offline → website fallback', () {
      final o = EstablishmentsService.scanOutcome(w, '245', null);
      expect(o.record?.name, 'Website Plant');
      expect(o.shared, isEmpty);
    });

    test('ambiguous → no single plant', () {
      final o = EstablishmentsService.scanOutcome(w, '245', resp(r245));
      expect(o.record, isNull);
      expect(o.shared.length, 3);
    });

    test('245C → Dakota City', () {
      final o = EstablishmentsService.scanOutcome(null, '245C', resp(r245));
      expect(o.record?.city, 'Dakota City');
      expect(o.shared, isEmpty);
    });

    test('lookup returns null when the network fails (offline path)', () async {
      EstablishmentsService.clearCache();
      EstablishmentsService.clientOverride =
          MockClient((_) async => throw http.ClientException('offline'));
      expect(await EstablishmentsService.lookup('245'), isNull);
      EstablishmentsService.clientOverride =
          MockClient((_) async => http.Response(r245, 200));
      expect((await EstablishmentsService.lookup('245'))?.count, 3);
      EstablishmentsService.clientOverride = null;
      EstablishmentsService.clearCache();
    });
  });

  test('new user-facing strings avoid banned words', () {
    final plant = resp(r245).establishments[1];
    final strings = [
      EstablishmentsService.sharedHeadline(3),
      'No parent mapping on file',
      'Full FSIS record',
      plant.salmonellaLine ?? '',
      plant.latestRecallLine ?? '',
      'No FSIS establishment matched',
      'Check the number on the USDA mark of inspection (e.g. EST. 245C or P-39928), or try part of the plant name.',
      'Enter USDA Establishment Number or Plant Name',
      'Recalls:',
      'Public health alerts:',
      'Inspection tasks:',
      'noncompliance records:',
      'memoranda of interview:',
      'Residue violations:',
      'Salmonella category —',
      'Latest recall:',
      'Parent company:',
    ];
    const banned = [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy'
    ];
    for (final s in strings) {
      for (final b in banned) {
        expect(s.toLowerCase().contains(b), isFalse, reason: '$s contains $b');
      }
    }
  });
}
