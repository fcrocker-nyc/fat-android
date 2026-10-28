import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/cuts/cut_guide.dart';

/// Lookup → Cut — mirrors iOS CutGuideTests, so both apps find the same cuts.
void main() {
  late CutGuide guide;
  setUpAll(() {
    guide = CutGuide.fromJson(jsonDecode(File('assets/data/cuts.json').readAsStringSync()) as Map<String, dynamic>);
  });
  String? top(String q) {
    final r = guide.search(q);
    return r.isEmpty ? null : '${r.first.species}.${r.first.key}';
  }

  test('search finds cuts by name and other names', () {
    const cases = {
      'ribeye': 'beef.ribeye', 'Rib-Eye': 'beef.ribeye', 'NY strip': 'beef.strip',
      'Kansas City strip': 'beef.strip', 'delmonico': 'beef.ribeye', 'prime rib': 'beef.prime_rib',
      'tomahawk': 'beef.bone_in_ribeye', 'hanger steak': 'beef.hanger', 'picanha': 'beef.picanha',
      'galbi': 'beef.short_ribs', 'pork butt': 'pork.pork_butt', 'boston butt': 'pork.pork_butt',
      'baby back ribs': 'pork.baby_back', 'guanciale': 'pork.jowl', 'prosciutto': 'pork.ham',
      'thighs': 'chicken.thigh', 'drumettes': 'chicken.drumette', 'chicken breast': 'chicken.breast',
    };
    cases.forEach((q, want) => expect(top(q), want, reason: q));
  });

  test('a species word narrows or browses', () {
    expect(top('pork tenderloin'), 'pork.tenderloin');
    expect(top('chicken tenderloin'), 'chicken.tenders');
    expect(guide.search('tenderloin').map((c) => c.species).toSet(), containsAll(['beef', 'chicken']));
    expect(guide.search('beef').map((c) => c.species).toSet(), {'beef'});
    expect(guide.search('beef').length, guide.cutsOf('beef').length);
    expect(guide.search('zzzz'), isEmpty);
  });

  test('menu dishes name their cut', () {
    expect(guide.cutInDish('Dry Aged Ribeye', {'beef'})?.key, 'ribeye');
    expect(guide.cutInDish('Tomahawk Ribeye for two', {'beef'})?.key, 'bone_in_ribeye');
    expect(guide.cutInDish('Niman Ranch Ribeye', {'beef'})?.key, 'ribeye');
    expect(guide.cutInDish('Hanger Steak, frites', {'beef'})?.key, 'hanger');
    expect(guide.cutInDish('Crispy pork belly, kimchi', {'pork'})?.key, 'belly');
    expect(guide.cutInDish('Roast chicken thighs', {'chicken'})?.key, 'thigh');
    expect(guide.cutInDish('Oysters on the half shell', {}), isNull);
    expect(guide.cutInDish('Duck breast, cherries', {'beef', 'pork'}), isNull);
  });

  test('every cut and species has a diagram, and data matches iOS', () {
    expect(guide.cuts.length, greaterThanOrEqualTo(50));
    for (final c in guide.cuts) {
      expect(File(c.asset).existsSync(), isTrue, reason: c.asset);
      expect(guide.primalFor(c), isNotNull, reason: c.key);
    }
    for (final s in guide.species) {
      expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
    }
    final ios = File('${Platform.environment['HOME']}/Developer/FATAppMVP2/FATAppMVP2/Cuts/cuts.json');
    if (ios.existsSync()) {
      expect(File('assets/data/cuts.json').readAsStringSync(), ios.readAsStringSync());
    }
  });
}
