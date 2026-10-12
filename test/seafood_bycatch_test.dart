// Catch method + bycatch context (Cat. 10 detail lines). Fixtures:
// test/seafood_bycatch_fixtures.dart (same texts as iOS). Baseline
// (pre-change interpreter): test/seafood_bycatch_baseline.json.
// Mirrors iOS FATAppMVP2Tests/SeafoodBycatchTests.swift.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/seafood_bycatch.dart';
import 'package:fat_app/interpreter/seafood_detail_lines.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

import 'seafood_bycatch_fixtures.dart';
import 'tool/generate_seafood_v11_baseline.dart' as v11;

class _Scan {
  final SeafoodInterpretation si;
  final List<String> cat10;
  _Scan(this.si, this.cat10);
  String? get cat10Value =>
      si.categories[SeafoodCategory.productionMethodFeed]?.value;
}

_Scan _lines(String text) {
  final si = SeafoodInterpreter.interpret(text);
  final r = FATResult(
    scannedText: text,
    categories: const {},
    productType: ProductType.seafood,
    seafoodCategories: si.categories,
    isSiluriformes: si.isSiluriformes,
    productionMethod: si.productionMethod,
    productionSystem: si.productionSystem,
    detectedEstablishmentNumber: si.detectedEstablishmentNumber,
  );
  final l = SeafoodDetailLines.forResult(r)[SeafoodCategory.productionMethodFeed] ??
      const <SeafoodDetailLine>[];
  return _Scan(si, l.map((e) => e.text).toList());
}

_Scan _fx(int n) => _lines(seafoodBycatchFixtures[n]!);

const _notStated = 'Catch method not stated on label';
String _lead(String country, String group, String gear) =>
    'NOAA has denied U.S. market access to some $country $group fisheries using $gear, because of marine-mammal bycatch (as of October 2026).';
const _deniedTail =
    " Products sold in the U.S. must come from fisheries that were not denied; this label doesn't name the fishery.";

void main() {
  setUpAll(() {
    MmpaBycatchData.bundled = MmpaBycatchData.fromJsonString(
        File('assets/data/mmpa_bycatch_pairs.json').readAsStringSync());
  });

  group('bundled data', () {
    test('ten Strong pairs, as of October 2026', () {
      final d = MmpaBycatchData.bundled!;
      expect(d.asOf, 'October 2026');
      expect(d.pairs.length, 10);
      expect(
          d.pairs.map((p) => '${p.country}|${p.speciesGroup}|${p.gearPhrase}').toSet(),
          {
            'Ecuador|mahi mahi|gillnets',
            'Indonesia|shrimp|trammel nets',
            'Indonesia|tuna|gillnets',
            'Indonesia|mahi mahi|gillnets',
            'Indonesia|grouper|gillnets',
            'Indonesia|snapper|gillnets',
            'Philippines|tuna|drift gillnets',
            'Vietnam|tuna|gillnets or purse seines',
            'Vietnam|mahi mahi|gillnets or longlines',
            'Vietnam|grouper|gillnets, longlines or trawls',
          });
    });

    test('asset is declared and loads through rootBundle', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final saved = MmpaBycatchData.bundled;
      MmpaBycatchData.bundled = null;
      await MmpaBycatchData.ensureLoaded();
      expect(MmpaBycatchData.bundled?.pairs.length, 10);
      MmpaBycatchData.bundled = saved;
    });
  });

  group('fixtures', () {
    test('Indonesia yellowfin, no gear → unknown-gear wording', () {
      expect(_fx(1).cat10, [
        _notStated,
        "${_lead('Indonesia', 'tuna', 'gillnets')} This label doesn't say how this yellowfin tuna was caught.",
      ]);
    });

    test('pole and line → context suppressed', () {
      final s = _fx(2);
      expect(s.cat10, ['Catch method: pole and line (stated on label)']);
      expect(s.cat10Value, 'Wild-Caught (pole and line)');
    });

    test('gillnet stated → denied-gear wording', () {
      expect(_fx(3).cat10, [
        'Catch method: gillnet (stated on label)',
        '${_lead('Indonesia', 'tuna', 'gillnets')}$_deniedTail',
      ]);
    });

    test('farmed Vietnam shrimp → no Cat. 10 lines', () {
      expect(_fx(4).cat10, isEmpty);
    });

    test('canned tuna, no country → catch method not stated only', () {
      expect(_fx(5).cat10, [_notStated]);
    });

    test('Alaska pollock → no context line', () {
      expect(_fx(6).cat10, [_notStated]);
    });

    test('Ecuador mahi mahi', () {
      expect(_fx(7).cat10, [
        _notStated,
        "${_lead('Ecuador', 'mahi mahi', 'gillnets')} This label doesn't say how this mahi mahi was caught.",
      ]);
    });

    test('FAD-free Philippines skipjack → suppressed', () {
      final s = _fx(8);
      expect(s.cat10, ['Catch method: FAD-free purse seine (stated on label)']);
      expect(s.cat10Value, 'Wild-Caught (FAD-free purse seine)');
    });

    test('method unknown, Indonesia shrimp', () {
      expect(_fx(9).cat10, [
        "${_lead('Indonesia', 'shrimp', 'trammel nets')} This label doesn't say how this shrimp was caught.",
      ]);
    });

    test('Vietnam grouper, longline is a denied gear', () {
      final s = _fx(10);
      expect(s.cat10, [
        'Catch method: longline (stated on label)',
        '${_lead('Vietnam', 'grouper', 'gillnets, longlines or trawls')}$_deniedTail',
      ]);
      expect(s.cat10Value, 'Wild-Caught (longline)');
    });

    test('troll albacore USA', () {
      final s = _fx(11);
      expect(s.cat10, ['Catch method: troll (stated on label)']);
      expect(s.cat10Value, 'Wild-Caught (troll)');
    });

    test('Indonesia snapper', () {
      expect(_fx(12).cat10, [
        _notStated,
        "${_lead('Indonesia', 'snapper', 'gillnets')} This label doesn't say how this snapper was caught.",
      ]);
    });

    test('Philippines tuna: no gear, drift gillnet, purse seine', () {
      const base = 'Skipjack Tuna\nWild-Caught\nProduct of the Philippines\n';
      expect(_lines(base).cat10.last,
          "${_lead('Philippines', 'tuna', 'drift gillnets')} This label doesn't say how this skipjack tuna was caught.");
      expect(_lines('${base}Drift gillnet caught').cat10, [
        'Catch method: drift gillnet (stated on label)',
        '${_lead('Philippines', 'tuna', 'drift gillnets')}$_deniedTail',
      ]);
      expect(_lines('${base}Purse seine caught').cat10,
          ['Catch method: purse seine (stated on label)']);
    });

    test('catfish → no lines', () {
      expect(_lines('Wild Caught Catfish\nProduct of Vietnam').cat10, isEmpty);
    });
  });

  test('gear detection', () {
    String? id(String t) => SeafoodGearDetector.detect(t.toLowerCase())?.id;
    String? phrase(String t) => SeafoodGearDetector.detect(t.toLowerCase())?.phrase;
    expect(id('chicken pot pie with tuna'), isNull);
    expect(id('tuna pot pies'), isNull);
    expect(id('potato and tuna salad'), isNull);
    expect(id('tuna hot pot'), isNull);
    expect(id('gift set net wt 12 oz'), isNull);
    expect(id('wild caught tuna'), isNull);
    expect(id('pot-caught dungeness crab'), 'trapPot');
    expect(id('caught in pots'), 'trapPot');
    expect(id('trap caught'), 'trapPot');
    expect(phrase('caught in traps'), 'trap or pot');
    expect(id('troll caught'), 'troll');
    expect(id('trolled albacore'), 'troll');
    expect(id('harpoon caught swordfish'), 'harpoon');
    expect(id('hand-line caught'), 'handline');
    expect(id('handline'), 'handline');
    expect(id('dredged sea scallops'), 'dredge');
    expect(id('caught with trammel nets'), 'trammelNet');
    expect(id('drift gillnet'), 'driftGillnet');
    expect(id('set net caught sockeye'), 'setNet');
    expect(id('gillnet caught'), 'gillnet');
    expect(id('gill net'), 'gillnet');
    expect(id('pole and line caught'), 'poleAndLine');
    expect(id('pole & line'), 'poleAndLine');
    expect(id('pole-caught'), 'poleAndLine');
    expect(id('hook and line caught'), 'hookAndLine');
    expect(id('line caught'), 'hookAndLine');
    expect(id('longline caught'), 'longline');
    expect(id('bottom trawl'), 'trawl');
    expect(id('purse seine'), 'purseSeine');
    expect(phrase('fad-free'), 'FAD-free purse seine');
    expect(phrase('purse seine, free school'), 'free school purse seine');
    expect(phrase('free-school skipjack'), 'free school purse seine');
    expect(id('pole and line caught, fad-free'), 'poleAndLine');
  });

  test('legacy Cat. 10 values unchanged', () {
    String? v(String t) => SeafoodInterpreter.interpret('Wild Caught Cod\n$t')
        .categories[SeafoodCategory.productionMethodFeed]
        ?.value;
    expect(v(''), 'Wild-Caught');
    expect(v('line caught'), 'Wild-Caught (line caught)');
    expect(v('line-caught'), 'Wild-Caught (line-caught)');
    expect(v('pole-caught'), 'Wild-Caught (pole-caught)');
    expect(v('trawl caught'), 'Wild-Caught (trawl)');
    expect(v('longline'), 'Wild-Caught (longline)');
    expect(v('gillnet'), 'Wild-Caught (gillnet)');
    expect(v('purse seine'), 'Wild-Caught (purse seine)');
    expect(v('hook and line'), 'Wild-Caught (hook and line)');
    expect(
        SeafoodInterpreter.interpret('Farm-Raised Shrimp')
            .categories[SeafoodCategory.productionMethodFeed]
            ?.value,
        'Farm-Raised');
  });

  test('statuses, index and count unchanged vs pre-change baseline', () {
    final doc = jsonDecode(
        File('test/seafood_bycatch_baseline.json').readAsStringSync()) as Map;
    final fixtures = Map<String, dynamic>.from(doc['fixtures'] as Map);
    expect(fixtures.length, seafoodBycatchFixtures.length);
    // Cat. 10 value changes only where a newly detected gear refines it.
    const newValues = {
      2: 'Wild-Caught (pole and line)',
      8: 'Wild-Caught (FAD-free purse seine)',
      10: 'Wild-Caught (longline)',
      11: 'Wild-Caught (troll)',
    };
    for (final e in seafoodBycatchFixtures.entries) {
      final base = Map<String, dynamic>.from(fixtures['${e.key}'] as Map);
      final now = v11.snapshot(e.value);
      expect(now['categories'], base['categories'], reason: 'fixture ${e.key} statuses');
      expect(now['seafoodIndex'], base['seafoodIndex'], reason: 'fixture ${e.key} index');
      expect(now['disclosurePercent'], base['disclosurePercent'],
          reason: 'fixture ${e.key} disclosure');
      expect(_fx(e.key).cat10Value, newValues[e.key] ?? base['cat10Value'],
          reason: 'fixture ${e.key} Cat. 10 value');
    }
  });

  test('new strings avoid banned words', () {
    const banned = [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy', 'banned', 'illegal', 'warning',
    ];
    final strings = <String>[SeafoodBycatch.catchMethodNotStated];
    for (final n in seafoodBycatchFixtures.keys) {
      strings.addAll(_fx(n).cat10);
    }
    for (final p in MmpaBycatchData.bundled!.pairs) {
      strings.add(SeafoodBycatch.contextUnknownGear(
          p.country, p.speciesGroup, p.gearPhrase, 'October 2026', p.speciesGroup));
      strings.add(SeafoodBycatch.contextDeniedGear(
          p.country, p.speciesGroup, p.gearPhrase, 'October 2026'));
    }
    for (final s in strings) {
      for (final w in banned) {
        expect(RegExp('\\b$w\\b', caseSensitive: false).hasMatch(s), isFalse,
            reason: '"$w" in "$s"');
      }
    }
  });
}
