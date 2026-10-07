// Shared-number follow-ups: EPA plant matching, Who/Owner when parents
// differ, CAFO-proximity location, pork-owner block by resolved plant.
// Mirrors the matching cases in iOS FATAppMVP2Tests/EstablishmentsServiceTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/data/pork_owner_database.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/services/epa_service.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/services/processor_service.dart';

import 'establishment_fixtures.dart';

EstablishmentsResponse resp(String s) => EstablishmentsService.decode(s)!;

// Real values from /245 on 2026-10-07 (trimmed to the fields under test).
const r245Geo =
    '{"query":"245","mode":"number","count":3,"establishments":[{"establishment_id":"2500","establishment_number":"M245J","name":"Tyson Fresh Meats, Inc.","city":"Hillsdale","state":"IL","county":"Rock Island County","latitude":41.555809998678,"longitude":-90.224720961519,"parent_company":"Tyson Foods"},{"establishment_id":"3254","establishment_number":"M245C+V245C","name":"Tyson Fresh Meats, Inc.","city":"Dakota City","state":"NE","county":"Dakota County","latitude":42.422540382641,"longitude":-96.415628550564,"parent_company":"Tyson Foods"},{"establishment_id":"4143","establishment_number":"M245E","name":"Tyson Fresh Meats, Inc.","city":"Amarillo","state":"TX","county":"Potter County","latitude":35.258954984722,"longitude":-101.649090033792,"parent_company":"Tyson Foods"}],"note":"shared"}';

FatEstablishment plant(String number, String city, String state,
        {String? parent, double? lat, double? lon}) =>
    FatEstablishment(
        establishmentNumber: number,
        name: 'Plant $number',
        city: city,
        state: state,
        parentCompany: parent,
        latitude: lat,
        longitude: lon);

ProcessorRecord website(
        {required String digits,
        required String prefix,
        required String street,
        required String city,
        required String state,
        Map<String, dynamic>? geo}) =>
    ProcessorRecord.fromJson({
      'establishment': {
        'est_number': digits,
        'est_prefix': prefix,
        'name': 'Website Plant',
        'address': street,
        'city': city,
        'state': state,
        'zip': '00000',
        'geolocation': ?geo,
      },
    }, digits: digits);

const epaIndexJson =
    '{"metadata":{},"index":{"244":"244","244v244":"244","244i":"244i","6620":"199g","199g":"199g","199gp6620":"199g","46071":"46071","717m":"717m"},"establishments":{"244":{"found":true,"match_confidence":"high","registry_id":"1","fac_name":"TYSON FRESH MEATS INC - STORM LAKE","fac_city":"STORM LAKE","fac_state":"IA","has_violations":true},"244i":{"found":true,"match_confidence":"high","registry_id":"2","fac_name":"TYSON FRESH MEATS INC","fac_city":"LOGANSPORT","fac_state":"IN","has_violations":true},"199g":{"found":true,"match_confidence":"high","registry_id":"3","fac_name":"HORMEL FOODS CORP.","fac_city":"TUCKER","fac_state":"GA","has_violations":true},"46071":{"found":true,"match_confidence":"high","registry_id":"4","fac_name":"SEABOARD TRIUMPH FOODS","fac_city":"CITY OF SIOUX CITY","fac_state":"IA","has_violations":true},"717m":{"found":true,"match_confidence":"medium","registry_id":"5","fac_name":"X","fac_city":"MILAN","fac_state":"MO","has_violations":true}}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('coordinates', () {
    test('decode county / latitude / longitude; older payloads still decode',
        () {
      final p = resp(r245Geo).establishments[1];
      expect(p.county, 'Dakota County');
      expect(p.latitude, closeTo(42.42254, 0.0001));
      expect(p.longitude, closeTo(-96.41563, 0.0001));
      expect(resp(r4033).establishments[0].latitude, isNull);
    });

    test('different-plant case uses the endpoint coordinates', () {
      final p = resp(r245Geo).establishments[1];
      final w = website(
          digits: '245',
          prefix: 'ML',
          street: '1500 Plum Creek Parkway',
          city: 'Lexington',
          state: 'NE',
          geo: {'lat': 40.78, 'lon': -99.74});
      final out = EstablishmentsService.merge(w, p);
      expect(out.endpointPlant, isNotNull);
      final pt = EstablishmentsService.proximityPoint(out, const [])!;
      expect(pt.$1, closeTo(42.42254, 0.0001));
      expect(pt.$2, closeTo(-96.41563, 0.0001));
    });

    test('same plant keeps the website geolocation when endpoint has none', () {
      final p = resp(r4033).establishments[0];
      final w = website(
          digits: '4033',
          prefix: 'M',
          street: '1 Brainard Avenue',
          city: 'Medford',
          state: 'MA',
          geo: {'lat': 42.4, 'lon': -71.1});
      final pt =
          EstablishmentsService.proximityPoint(EstablishmentsService.merge(w, p), const []);
      expect(pt, (42.4, -71.1));
    });

    test('shared number across states → no location guessed', () {
      expect(
          EstablishmentsService.proximityPoint(
              null, resp(r245Geo).establishments),
          isNull);
    });

    test('shared plants within 10 miles → first candidate', () {
      final near = [
        plant('M1A', 'Souderton', 'PA', lat: 40.3118, lon: -75.3252),
        plant('M1B', 'Telford', 'PA', lat: 40.3218, lon: -75.3279),
      ];
      expect(EstablishmentsService.proximityPoint(null, near),
          (40.3118, -75.3252));
      final missing = [
        plant('M1A', 'Souderton', 'PA', lat: 40.3118, lon: -75.3252),
        plant('M1B', 'Telford', 'PA'),
      ];
      expect(EstablishmentsService.proximityPoint(null, missing), isNull);
    });
  });

  group('Who / Owner when the number is shared', () {
    test('different parents → Partial "One of: …"', () {
      final r = EstablishmentsService.sharedOwnerResult([
        plant('M1A', 'A', 'IA', parent: 'Tyson Foods'),
        plant('M1B', 'B', 'NE', parent: 'JBS'),
        plant('M1C', 'C', 'TX'),
        plant('M1D', 'D', 'CO', parent: 'tyson foods'),
      ])!;
      expect(r.status, DisclosureStatus.partial);
      expect(r.value, 'One of: Tyson Foods; JBS; no parent mapping on file');
      expect(r.credibilityNote,
          "This number belongs to 4 FSIS plants with different owners — match the city on the package's USDA mark to know which.");
    });

    test('one shared parent (245) or no mapping at all → unchanged path', () {
      expect(EstablishmentsService.sharedOwnerResult(resp(r245).establishments),
          isNull);
      expect(
          EstablishmentsService.sharedOwnerResult(
              [plant('M1A', 'A', 'IA'), plant('M1B', 'B', 'NE')]),
          isNull);
    });

    test('Missing → Partial never changes the known count', () {
      final cats = <FATCategory, FATCategoryResult>{
        for (final c in FATCategory.values)
          c: const FATCategoryResult(status: DisclosureStatus.missing),
      };
      cats[FATCategory.species] =
          const FATCategoryResult(status: DisclosureStatus.known, value: 'Beef');
      cats[FATCategory.processor] = const FATCategoryResult(
          status: DisclosureStatus.known, value: 'EST. 1');
      final result = FATResult(scannedText: 'BEEF EST. 1', categories: cats);
      final known = result.knownCount, partial = result.partialCount;
      final ps = [
        plant('M1A', 'A', 'IA', parent: 'Tyson Foods'),
        plant('M1B', 'B', 'NE', parent: 'JBS'),
      ];
      expect(EstablishmentsService.applySharedOwner(result.categories, ps),
          isTrue);
      expect(result.knownCount, known);
      expect(result.partialCount, partial + 1);
      expect(result.categories[FATCategory.who]!.status,
          DisclosureStatus.partial);
      // A Who the label already disclosed is never replaced.
      result.categories[FATCategory.who] = const FATCategoryResult(
          status: DisclosureStatus.known, value: 'Label Co');
      expect(EstablishmentsService.applySharedOwner(result.categories, ps),
          isFalse);
      expect(result.categories[FATCategory.who]!.value, 'Label Co');
    });
  });

  group('EPA (ECHO) plant matching', () {
    final m = EpaService.parseIndex(epaIndexJson)!;

    test('index parsing: tokens, medium confidence never counts', () {
      expect(m['6620']!.city, 'TUCKER');
      expect(m['244v244']!.city, 'STORM LAKE');
      expect(m['717m']!.violating, isFalse);
      expect(m['244i']!.violating, isTrue);
    });

    test('matches only the resolved plant city + state', () {
      const stormLake = EpaPlant(['244'], 'Storm Lake', 'IA');
      const logansport = EpaPlant(['244i'], 'Logansport', 'IN');
      const waterloo = EpaPlant(['244w'], 'Waterloo', 'IA');
      expect(EpaService.evaluate(m, '244', plant: stormLake, numberShared: true),
          EpaOutcome.violation);
      expect(
          EpaService.evaluate(m, '244', plant: logansport, numberShared: true),
          EpaOutcome.violation);
      expect(EpaService.evaluate(m, '244', plant: waterloo, numberShared: true),
          EpaOutcome.clean);
      expect(
          EpaService.evaluate(m, '6620',
              plant: const EpaPlant(['6620'], 'Tucker', 'GA')),
          EpaOutcome.violation);
      expect(
          EpaService.evaluate(m, '46071',
              plant: const EpaPlant(['46071'], 'SIOUX CITY', 'IA')),
          EpaOutcome.violation);
    });

    test('shared number → neutral line or clean, never a violation', () {
      expect(
          EpaService.evaluate(m, '244', numberShared: true, sharedPlants: const [
            EpaPlant(['244'], 'Storm Lake', 'IA'),
            EpaPlant(['244w'], 'Waterloo', 'IA'),
          ]),
          EpaOutcome.sharedOnFile);
      expect(
          EpaService.evaluate(m, '244', numberShared: true, sharedPlants: const [
            EpaPlant(['244w'], 'Waterloo', 'IA'),
            EpaPlant(['244m'], 'Madison', 'NE'),
          ]),
          EpaOutcome.clean);
      final p245 = resp(r245)
          .establishments
          .map(EpaPlant.fromEstablishment)
          .toList();
      expect(p245.map((p) => p.cores).toList(), [
        ['245j'],
        ['245c'],
        ['245e']
      ]);
      expect(EpaService.evaluate(m, '245', sharedPlants: p245),
          EpaOutcome.clean);
    });

    test('entry without location needs an unshared number', () {
      final list = EpaService.parseViolationsList('{"cores":["244","244i"]}')!;
      const waterloo = EpaPlant(['244w'], 'Waterloo', 'IA');
      expect(
          EpaService.evaluate(list, '244', plant: waterloo, numberShared: true),
          EpaOutcome.clean);
      expect(
          EpaService.evaluate(list, '244',
              plant: waterloo, numberShared: false),
          EpaOutcome.violation);
      expect(
          EpaService.evaluate(list, '244',
              plant: const EpaPlant(['244i'], 'Logansport', 'IN'),
              numberShared: true),
          EpaOutcome.violation);
    });

    test('city normalization', () {
      expect(EpaService.sameLocation('SAINT JOSEPH', 'MO', 'St Joseph', 'MO'),
          isTrue);
      expect(EpaService.sameLocation('VINELAND CITY', 'NJ', 'Vineland', 'NJ'),
          isTrue);
      expect(
          EpaService.sameLocation(
              'CITY OF SIOUX CITY', 'IA', 'SIOUX CITY', 'IA'),
          isTrue);
      expect(EpaService.sameLocation('DANVILLE', 'AR', 'Austin', 'TX'), isFalse);
      expect(EpaService.sameLocation('CLINTON', 'NC', 'Clinton', 'IA'), isFalse);
    });

    test('EpaPlant from a resolved record', () {
      final p = resp(r245C).establishments[0];
      final rec = ProcessorRecord.fromEstablishment(p);
      final ep = EpaPlant.fromRecord(rec);
      expect(ep.cores, ['245c']);
      expect(ep.city, 'Dakota City');
      final w = website(
          digits: '4033',
          prefix: 'M',
          street: '1 Brainard Avenue',
          city: 'Medford',
          state: 'MA');
      expect(EpaPlant.fromRecord(w).cores, ['4033']);
    });
  });

  group('pork-owner block by resolved plant', () {
    test('full EST tokens, not bare digits', () {
      // 245 digits alone has no table entry; the resolved M245C plant does.
      expect(PorkOwnerDatabase.detectOwnerForPlantTokens(['M245C', 'V245C'])
          ?.owner
          .id, 'tyson_beef');
      // Suffix keys that the digit normaliser used to mangle ("717M" → "717").
      expect(PorkOwnerDatabase.detectOwnerForPlantTokens(['M717M'])?.owner.id,
          'whgroup');
      expect(PorkOwnerDatabase.detectOwnerForPlantTokens(['M3S', 'V3S'])
          ?.owner
          .id, 'jbs');
      // A plant whose own number isn't in the tables → no owner shown.
      expect(PorkOwnerDatabase.detectOwnerForPlantTokens(['M244W']), isNotNull);
      expect(PorkOwnerDatabase.detectOwnerForPlantTokens(['M99999']), isNull);
    });
  });

  test('new strings avoid banned words', () {
    final strings = [
      EpaService.sharedOnFileText,
      EstablishmentsService.sharedOwnerNote(3),
      'One of: Tyson Foods; JBS; ${EstablishmentsService.noParentMappingText}',
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
