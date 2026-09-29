// Seafood v1.1 (farmed salmon) — Task 9 tests.
// Fixtures: test/seafood_v11_fixtures.dart. Baseline (pre-v1.1 interpreter):
// test/seafood_v11_baseline.json, written by
// test/tool/generate_seafood_v11_baseline.dart before any v1.1 change.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fat_app/interpreter/seafood_detail_lines.dart';
import 'package:fat_app/interpreter/seafood_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';
import 'package:fat_app/models/service_case_schema.dart';
import 'package:fat_app/services/scan_store.dart';

import 'seafood_v11_fixtures.dart';

class _Scan {
  final SeafoodInterpretation si;
  final FATResult result;
  final Map<SeafoodCategory, List<SeafoodDetailLine>> lines;
  _Scan(this.si, this.result, this.lines);

  List<String> linesFor(SeafoodCategory c) =>
      (lines[c] ?? const []).map((l) => l.text).toList();
  DisclosureStatus status(SeafoodCategory c) =>
      si.categories[c]?.status ?? DisclosureStatus.missing;
  String get text => result.scannedText;
}

_Scan scan(int n) {
  final text = seafoodV11Fixtures[n]!;
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
  return _Scan(si, r, SeafoodDetailLines.forResult(r));
}

const _cat1 = SeafoodCategory.regulatoryRequiredLanguage;
const _cat2 = SeafoodCategory.speciesIdentity;
const _cat4 = SeafoodCategory.countryOrigin;
const _cat5 = SeafoodCategory.farmVesselFishery;
const _cat7 = SeafoodCategory.processor;

const _salmonNotCovered =
    "Salmon is not one of the 13 species groups covered by NOAA's Seafood Import Monitoring Program.";
const _tripwire =
    'Label says wild Atlantic salmon; U.S. supply of Atlantic salmon is farm-raised (NOAA) — unverified.';

DisclosureStatus _sysStatus(_Scan s) => SeafoodInterpreter.productionSystemStatus(
    s.si.productionSystem!, s.text);

void main() {
  group('Fixtures', () {
    test('#1 farmed Atlantic, Chile, color added, ASC', () {
      final s = scan(1);
      expect(s.si.productionSystem, SeafoodProductionSystem.undisclosed);
      expect(_sysStatus(s), DisclosureStatus.missing);
      expect(s.linesFor(_cat5), [
        'Grown in: not stated on label — certified farm; site not identified from the label.'
      ]);
      expect(s.linesFor(_cat1), [SeafoodDetailLines.colorGeneric]);
      expect(s.linesFor(_cat7), [_salmonNotCovered]);
      expect(s.linesFor(_cat2), isEmpty);
      expect(s.linesFor(_cat4), isEmpty);
    });

    test('#2 open net pens, astaxanthin', () {
      final s = scan(2);
      expect(s.si.productionSystem, SeafoodProductionSystem.openNetPen);
      expect(_sysStatus(s), DisclosureStatus.known);
      expect(s.linesFor(_cat5), ['Grown in: open net pens (sea)']);
      expect(s.linesFor(_cat1), [
        'Color added (astaxanthin in feed) — declared as required by 21 CFR 73.35.'
      ]);
    });

    test('#3 land-based RAS, domestic', () {
      final s = scan(3);
      expect(s.si.productionSystem, SeafoodProductionSystem.landBasedRAS);
      expect(_sysStatus(s), DisclosureStatus.known);
      expect(s.linesFor(_cat5), ['Grown in: land-based tanks (recirculating)']);
      expect(s.linesFor(_cat7), isEmpty); // domestic → no SIMP line
    });

    test('#4 responsibly farmed only', () {
      final s = scan(4);
      expect(s.si.productionSystem, SeafoodProductionSystem.undisclosed);
      expect(_sysStatus(s), DisclosureStatus.partial);
      expect(s.linesFor(_cat1),
          ['No color-additive statement found on this label.']);
    });

    test('#5 wild Atlantic salmon → tripwire on Cat. 2 and Cat. 4', () {
      final s = scan(5);
      expect(s.linesFor(_cat2), [_tripwire]);
      expect(s.linesFor(_cat4), [_tripwire]);
      expect(s.lines[_cat2]!.single.kind, SeafoodDetailKind.flag);
      expect(s.si.productionSystem, SeafoodProductionSystem.notApplicableWild);
      expect(s.linesFor(_cat5), isEmpty);
      expect(s.linesFor(_cat1), isEmpty); // wild → no color line
    });

    test('#6 wild Atlantic cod → no tripwire; SIMP covered', () {
      final s = scan(6);
      expect(s.linesFor(_cat2), isEmpty);
      expect(s.linesFor(_cat4), isEmpty);
      expect(s.linesFor(_cat7),
          ["Covered by NOAA's Seafood Import Monitoring Program (SIMP)."]);
    });

    test('#7 cold smoked, no origin → Cat. 4 notRequired', () {
      final s = scan(7);
      expect(SeafoodInterpreter.isProcessedSeafood(s.text), isTrue);
      expect(s.status(_cat4), DisclosureStatus.notRequired);
      expect(s.si.categories[_cat4]!.value,
          'Not required for smoked or processed seafood (7 CFR Part 60). The brand may state it voluntarily.');
      expect(s.linesFor(_cat7), isEmpty); // origin unknown → no SIMP line
    });

    test('#8 smoked, farmed in Scotland → Cat. 4 Known + voluntary note', () {
      final s = scan(8);
      final c4 = s.si.categories[_cat4]!;
      expect(c4.status, DisclosureStatus.known);
      expect(c4.value, 'Farmed in Scotland');
      expect(c4.credibilityNote,
          'Stated voluntarily — not required for processed seafood.');
      expect(c4.credibility, isNull); // no credibility tier → index unaffected
    });

    test('#9 wild Alaska sockeye', () {
      final s = scan(9);
      expect(s.linesFor(_cat1), isEmpty);
      expect(s.si.productionSystem, SeafoodProductionSystem.notApplicableWild);
      expect(s.linesFor(_cat5), isEmpty);
      expect(s.linesFor(_cat2), isEmpty);
      expect(s.linesFor(_cat4), isEmpty);
    });

    test('#10 farm-raised trout, raceway', () {
      final s = scan(10);
      expect(s.si.productionSystem, SeafoodProductionSystem.landBasedFlowThrough);
      expect(_sysStatus(s), DisclosureStatus.known);
      expect(s.linesFor(_cat1), isNotEmpty); // salmonid → color rule applies
    });

    test('#11 channel catfish → fork unchanged, no new lines', () {
      final s = scan(11);
      expect(s.si.isSiluriformes, isTrue);
      expect(s.si.productionSystem, isNull);
      expect(s.lines, isEmpty);
    });

    test('#12 farm-raised shrimp, Ecuador', () {
      final s = scan(12);
      expect(s.linesFor(_cat7),
          ["Covered by NOAA's Seafood Import Monitoring Program (SIMP)."]);
      expect(s.linesFor(_cat1), isEmpty);
    });
  });

  group('Regression vs pre-v1.1 baseline', () {
    final baseline = (jsonDecode(
            File('test/seafood_v11_baseline.json').readAsStringSync())
        as Map<String, dynamic>)['fixtures'] as Map<String, dynamic>;

    // #7 is the intended Task 3 change. #8 also moves in Cat. 4 only: the
    // pre-v1.1 interpreter had no pattern for "Farmed in Scotland" (Missing),
    // and the handoff's Task 9 expectation for #8 (Known + voluntary note)
    // requires the processed-seafood voluntary-origin read.
    const cat4Allowed = {7, 8};

    for (final n in seafoodV11Fixtures.keys) {
      test('fixture #$n statuses and index', () {
        final b = baseline['$n'] as Map<String, dynamic>;
        final bc = b['categories'] as Map<String, dynamic>;
        final s = scan(n);
        for (final c in SeafoodCategory.values) {
          if (c == _cat4 && cat4Allowed.contains(n)) continue;
          expect(s.status(c).name, bc[c.name], reason: 'fixture #$n ${c.name}');
        }
        if (!cat4Allowed.contains(n)) {
          expect(s.result.seafoodFatScore, b['seafoodIndex'],
              reason: 'fixture #$n seafood index');
        }
      });
    }

    test('fixture #7: only Cat. 4 moved, Missing → notRequired', () {
      final bc = (baseline['7'] as Map)['categories'] as Map;
      expect(bc[_cat4.name], 'missing');
      expect(scan(7).status(_cat4), DisclosureStatus.notRequired);
    });

    test('fixture #8: only Cat. 4 moved, Missing → Known', () {
      final bc = (baseline['8'] as Map)['categories'] as Map;
      expect(bc[_cat4.name], 'missing');
      expect(scan(8).status(_cat4), DisclosureStatus.known);
    });
  });

  group('Edge cases', () {
    test('non-seafood words do not trip the processed check', () {
      expect(SeafoodInterpreter.isProcessedSeafood('procured and secured'),
          isFalse);
      expect(SeafoodInterpreter.isProcessedSeafood('uncooked lobster'), isFalse);
      expect(SeafoodInterpreter.isProcessedSeafood(
          'live lobster product of nova scotia'), isFalse);
    });

    test('longest production-system match wins', () {
      expect(
          SeafoodInterpreter.detectProductionSystem(
              'farm-raised trout from spring-fed raceway',
              SeafoodProductionMethod.farmRaised),
          SeafoodProductionSystem.landBasedFlowThrough);
      expect(
          SeafoodInterpreter.detectProductionSystem(
              'pond-raised catfish', SeafoodProductionMethod.farmRaised),
          SeafoodProductionSystem.pond);
    });

    test('canthaxanthin is named when that is the word found', () {
      expect(
          SeafoodDetailLines.colorLine(
              species: 'Rainbow Trout',
              method: SeafoodProductionMethod.farmRaised,
              scannedText: 'farm-raised rainbow trout canthaxanthin added'),
          'Color added (canthaxanthin in feed) — declared as required by 21 CFR 73.75.');
    });

    test('SIMP coverage map', () {
      for (final s in ['Yellowfin Tuna', 'Albacore Tuna', 'Atlantic Cod',
        'Pacific Cod', 'Red Snapper', 'Grouper', 'Mahi Mahi', 'Shrimp',
        'Prawns', 'Swordfish', 'King Crab', 'Blue Crab', 'Abalone',
        'Sea Cucumber', 'Shark']) {
        expect(SIMPCoverage.isCovered(s), isTrue, reason: s);
      }
      for (final s in ['Atlantic Salmon', 'Sardine', 'Tilapia', 'Rainbow Trout',
        'Pollock', 'Scallop']) {
        expect(SIMPCoverage.isCovered(s), isFalse, reason: s);
      }
    });
  });

  group('Persistence', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('pre-v1.1 saved scan (no productionSystem key) still loads', () async {
      final old = jsonEncode({
        'id': 'old-1',
        'scannedText': 'Atlantic Salmon Farm-Raised Product of Chile',
        'scannedAt': '2026-08-01T12:00:00.000',
        'categories': {},
        'productType': 'seafood',
        'seafoodCategories': {
          'speciesIdentity': {'status': 'known', 'value': 'Atlantic Salmon'},
        },
        'isSiluriformes': false,
        'productionMethod': 'farmRaised',
      });
      SharedPreferences.setMockInitialValues({
        'fat_scan_history': [old],
      });
      final all = await ScanStore.instance.loadAll();
      expect(all, hasLength(1));
      expect(all.single.productionSystem, isNull);
      expect(all.single.productionMethod, SeafoodProductionMethod.farmRaised);
    });

    test('productionSystem round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      await ScanStore.instance.saveResult(scan(2).result);
      final all = await ScanStore.instance.loadAll();
      expect(all.single.productionSystem, SeafoodProductionSystem.openNetPen);
    });
  });

  group('Language lint (new v1.1 strings)', () {
    const banned = [
      'score', 'grade', 'avoid', 'fails', 'poor', 'hides', 'conceals',
      'refuses', 'unsafe', 'unhealthy',
    ];
    final strings = <String>[
      SeafoodDetailLines.grownInPrefix,
      SeafoodDetailLines.grownInVague,
      SeafoodDetailLines.certifiedFarmSuffix,
      SeafoodDetailLines.colorAstaxanthin,
      SeafoodDetailLines.colorCanthaxanthin,
      SeafoodDetailLines.colorGeneric,
      SeafoodDetailLines.colorNotFound,
      SeafoodDetailLines.simpCovered,
      SeafoodDetailLines.simpNotCovered('Salmon'),
      SeafoodDetailLines.wildAtlanticSalmonTripwire,
      SeafoodInterpreter.coolNotRequiredProcessed,
      SeafoodInterpreter.coolVoluntaryNote,
      EstablishmentType.voluntaryDisclosureNote,
      for (final p in SeafoodProductionSystem.values) p.grownInLabel,
      // Every line actually rendered for the 12 fixtures.
      for (final n in seafoodV11Fixtures.keys)
        for (final ls in scan(n).lines.values)
          for (final l in ls) l.text,
    ];

    for (final s in strings) {
      test('no banned words: "$s"', () {
        for (final w in banned) {
          expect(RegExp('\\b$w\\b', caseSensitive: false).hasMatch(s), isFalse,
              reason: '"$w" in "$s"');
        }
      });
    }
  });

  test('Task 7 venue copy is verbatim', () {
    expect(EstablishmentType.voluntaryDisclosureNote,
        'Country of origin and wild/farmed are not required here. Any disclosure at a restaurant or fish market is voluntary — you can ask where the salmon came from and how it was farmed.');
    expect(EstablishmentType.exemptFoodservice.isVoluntaryDisclosureVenue, isTrue);
    expect(EstablishmentType.exemptFishmonger.isVoluntaryDisclosureVenue, isTrue);
    expect(EstablishmentType.exemptButcher.isVoluntaryDisclosureVenue, isFalse);
  });
}
