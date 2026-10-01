// Bundled FSIS plant-name fallback (assets/data/fsis_establishment_names.json)
// used when the FAT website record carries a blank establishment name / city /
// state. Mirrors iOS FATAppMVP2Tests/FSISPlantNamesTests.swift.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/services/fsis_plant_names.dart';
import 'package:fat_app/services/processor_service.dart';

Map<String, dynamic> websiteJson(
        {required String name, required String city, required String state}) =>
    {
      'establishment': {
        'est_number': '80',
        'est_prefix': 'I',
        'name': name,
        'dba': null,
        'address': '2825 E. 44th Street ',
        'city': city,
        'state': state,
        'zip': '',
        'size': 'N / A',
        'activities': '',
      },
      'species': <String, dynamic>{},
      'pathogen_testing': <String, dynamic>{},
      'enforcement': <String, dynamic>{},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FsisPlantNames.ensureLoaded();
    expect(FsisPlantNames.isLoaded, isTrue);
  });

  test('I80 → Lineage Logistics - Vernon Area #8 (Vernon, CA)', () {
    final info = FsisPlantNames.lookup(prefix: 'I', digits: '80');
    expect(info?.name, 'Lineage Logistics - Vernon Area #8');
    expect(info?.city, 'Vernon');
    expect(info?.state, 'CA');
  });

  test('4033 / M4033 / P4033 → Bianco Inc. (Medford, MA)', () {
    for (final c in [
      [null, '4033'],
      ['M', '4033'],
      ['P', '4033'],
      [null, 'P4033'],
    ]) {
      final info = FsisPlantNames.lookup(prefix: c[0], digits: c[1]!);
      expect(info?.name, 'Bianco Inc.', reason: '${c[0] ?? ''}${c[1]}');
      expect(info?.city, 'Medford');
      expect(info?.state, 'MA');
    }
  });

  test('1 → Vienna Beef Ltd.', () {
    expect(FsisPlantNames.lookup(digits: '1')?.name, 'Vienna Beef Ltd.');
  });

  test('P1250 → Fieldale Farms Corporation, DBA Springer Mountain Farms', () {
    final info = FsisPlantNames.lookup(prefix: 'P', digits: '1250');
    expect(info?.name, 'Fieldale Farms Corporation');
    expect(info?.dba, 'Springer Mountain Farms');
  });

  test('unknown number → null', () {
    expect(FsisPlantNames.lookup(prefix: 'M', digits: '99999999'), isNull);
  });

  test('parse fills blank name / city / state from the bundle', () {
    final rec = ProcessorRecord.fromJson(
        websiteJson(name: '', city: '', state: ''));
    expect(rec.name, 'Lineage Logistics - Vernon Area #8');
    expect(rec.city, 'Vernon');
    expect(rec.state, 'CA');
    expect(rec.fullAddress, '2825 E. 44th Street, Vernon, CA');
    expect(rec.displayName, 'Lineage Logistics - Vernon Area #8');
  });

  test('parse keeps a real website name unchanged', () {
    final rec = ProcessorRecord.fromJson(
        websiteJson(name: 'Some Real Plant LLC', city: 'Somewhere', state: 'TX'));
    expect(rec.name, 'Some Real Plant LLC');
    expect(rec.city, 'Somewhere');
    expect(rec.state, 'TX');
    expect(rec.fullAddress, '2825 E. 44th Street, Somewhere, TX');
    expect(rec.dba, isNull);
  });

  test('unknown plant shows the neutral placeholder', () {
    final j = websiteJson(name: '', city: '', state: '');
    (j['establishment'] as Map)['est_number'] = '99999999';
    final rec = ProcessorRecord.fromJson(j);
    expect(rec.resolvedName, isNull);
    expect(rec.displayName, 'Plant name not on file');
  });
}
