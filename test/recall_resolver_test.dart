// Plant-specific recall display: the recall-check proxy is keyed by the
// printed number, which FSIS reuses across plants. Mirrors the recall cases
// in iOS FATAppMVP2Tests/EstablishmentsServiceTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/services/establishments_service.dart';
import 'package:fat_app/services/recall_service.dart';

import 'establishment_fixtures.dart';

EstablishmentsResponse resp(String s) => EstablishmentsService.decode(s)!;

// Real /244 values on 2026-10-07 (trimmed): 11 plants, only Plainville has a PHA.
const r244 =
    '{"query":"244","mode":"number","count":11,"establishments":[{"establishment_number":"V244D","name":"Farm Fresh Turkey Products","city":"New Oxford","state":"PA","recalls":0,"public_health_alerts":0},{"establishment_number":"P244+V244A","name":"Plainville Farms","city":"New Oxford","state":"PA","recalls":0,"public_health_alerts":1},{"establishment_number":"M244U+P244U","name":"Tyson Fresh Meats, Inc","city":"Eagle Mountain","state":"UT","recalls":0,"public_health_alerts":0},{"establishment_number":"M244I","name":"Tyson Fresh Meats, Inc","city":"Logansport","state":"IN","recalls":0,"public_health_alerts":0},{"establishment_number":"M244M","name":"Tyson Fresh Meats, Inc.","city":"Madison","state":"NE","recalls":0,"public_health_alerts":0},{"establishment_number":"M244G+P244G+V244G","name":"Tyson Fresh Meats, Inc.","city":"Goodlettsville","state":"TN","recalls":0,"public_health_alerts":0},{"establishment_number":"M244W","name":"Tyson Fresh Meats, Inc.","city":"Waterloo","state":"IA","recalls":0,"public_health_alerts":0},{"establishment_number":"M244S+P244S","name":"Tyson Fresh Meats, Inc.","city":"Sherman","state":"TX","recalls":0,"public_health_alerts":0},{"establishment_number":"M244+V244","name":"Tyson Fresh Meats, Inc.","city":"Storm Lake","state":"IA","recalls":0,"public_health_alerts":0},{"establishment_number":"M244C+P244C","name":"Tyson Fresh Meats, Inc.","city":"Council Bluffs","state":"IA","recalls":0,"public_health_alerts":0},{"establishment_number":"M244L+V244L","name":"Tyson Fresh Meats, Inc.","city":"Columbus Junction","state":"IA","recalls":0,"public_health_alerts":0}],"note":"shared"}';

// recall-check?est=244 returns the Plainville (New Oxford PA) turkey alert.
const plainville = RecallRecord(
  recallNumber: 'PHA-04102021',
  title:
      'FSIS Issues Public Health Alert for Raw Ground Turkey Products Linked to Salmonella Hadar Illness',
  url: '',
  date: '2021-04-10',
  classification: 'Public Health Alert',
  riskLevel: '',
  type: 'Public Health Alert',
  active: false,
  reason: ['Product Contamination'],
  states: [],
  establishment: ['Plainville Farms'],
  summary: 'Plainville Brands, LLC, a New Oxford, Pa. establishment, ...',
);

const dakota = RecallRecord(
  recallNumber: '085-2015',
  title:
      'Tyson Fresh Meats Recalls Beef Products Due To Possible E. Coli O157:H7 Contamination',
  url: 'u',
  date: '2015-06-03',
  classification: 'Class I',
  riskLevel: '',
  type: 'Closed Recall',
  active: false,
  reason: ['Product Contamination'],
  states: [],
  establishment: ['Tyson Fresh Meats, Inc.'],
  summary:
      'WASHINGTON, June 3, 2015 Tyson Fresh Meats, a Dakota City, Neb., establishment, is recalling ...',
);

RecallCheck check(List<RecallRecord> m) => RecallCheck(
    est: 'X', matchCount: m.length, activeCount: 0, matches: m);

void main() {
  test('244 ambiguous → neutral line, never the turkey alert', () {
    final plants = resp(r244).establishments;
    final d = RecallResolver.display(check([plainville]),
        domestic: true, shared: plants);
    expect(d.kind, RecallDisplayKind.sharedOnFile);
    expect(d.check, isNull);
    final clean = plants.where((p) => p.publicHealthAlerts == 0).toList();
    expect(
        RecallResolver.display(check([plainville]),
                domestic: true, shared: clean)
            .kind,
        RecallDisplayKind.hidden);
  });

  test('resolved plant drops another plant\'s notice', () {
    final stormLake = resp(r244).establishments[8];
    expect(stormLake.city, 'Storm Lake');
    expect(
        RecallResolver.display(check([plainville]),
                domestic: true, plant: stormLake)
            .kind,
        RecallDisplayKind.hidden);
    final newOxford = resp(r244).establishments[1];
    final d = RecallResolver.display(check([plainville]),
        domestic: true, plant: newOxford);
    expect(d.check!.matches.map((r) => r.recallNumber).toList(),
        ['PHA-04102021']);
  });

  test('245C resolved → Dakota City\'s own recall 085-2015', () {
    final plant = resp(r245C).establishments[0];
    expect(RecallResolver.lookupKey('245', plant), '245C');
    final d = RecallResolver.display(check([dakota, dakota]),
        domestic: true, plant: plant);
    expect(d.kind, RecallDisplayKind.records);
    expect(d.check!.matches.map((r) => r.recallNumber).toList(), ['085-2015']);
    // Proxy empty → the endpoint's own latest_recall for the plant.
    final e = RecallResolver.display(check(const []),
        domestic: true, plant: plant);
    expect(e.check!.matches.single.recallNumber, '085-2015');
    expect(e.check!.matches.single.classification, 'Class I');
    expect(e.check!.matches.single.active, isFalse);
    expect(e.check!.matches.single.url, contains('fsis.usda.gov'));
  });

  test('foreign mark and offline (no resolution) unchanged', () {
    expect(
        RecallResolver.display(check([plainville]), domestic: false).kind,
        RecallDisplayKind.records);
    expect(RecallResolver.display(check([plainville]), domestic: true).kind,
        RecallDisplayKind.records);
  });

  test('new string avoids banned words', () {
    const banned = [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy'
    ];
    for (final b in banned) {
      expect(RecallResolver.sharedOnFileText.toLowerCase().contains(b), isFalse);
    }
  });
}
