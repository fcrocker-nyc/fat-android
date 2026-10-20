// "Hog Farms Near This Plant" / "Cattle Feedlots Near This Plant": the
// heading must never render with nothing under it.
// Mirrors iOS FATAppMVP2Tests/NearbyFarmsSectionTests.swift.
import 'package:fat_app/services/feedlot_proximity_service.dart';
import 'package:fat_app/widgets/nearby_farms_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProximityResult _zeroViolators() => ProximityResult.fromJson({
      // Shape captured from hog-proximity.php on 2026-10-20.
      'has_nearby_violators': false,
      'total_violators': 0,
      'radius_miles': 50,
      'summary': {'red': 0, 'orange': 0, 'yellow': 0},
      'data_source': 'EPA ECHO / NC DEQ / State Environmental Agencies',
      'data_date': '2026-03-26',
      'violators': <dynamic>[],
    });

Future<void> _pump(WidgetTester t,
    {required bool isHog,
    bool isLoading = false,
    bool lookupFinished = true,
    ProximityResult? result,
    List<String> permitLines = const []}) {
  return t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: NearbyFarmsSection(
          isHog: isHog,
          isLoading: isLoading,
          lookupFinished: lookupFinished,
          result: result,
          permitLines: permitLines,
          onOpenUrl: (_) {},
        ),
      ),
    ),
  ));
}

void main() {
  group('NearbyFarmsBody.resolve', () {
    test('pending or in-flight lookup is loading', () {
      expect(
          NearbyFarmsBody.resolve(
              isLoading: false,
              lookupFinished: false,
              hasData: false,
              hasPermitLines: false),
          NearbyFarmsBody.loading);
      expect(
          NearbyFarmsBody.resolve(
              isLoading: true,
              lookupFinished: false,
              hasData: false,
              hasPermitLines: false),
          NearbyFarmsBody.loading);
    });

    test('failed lookup: permits-only when permit lines exist, else unavailable',
        () {
      expect(
          NearbyFarmsBody.resolve(
              isLoading: false,
              lookupFinished: true,
              hasData: false,
              hasPermitLines: true),
          NearbyFarmsBody.permitsOnly);
      expect(
          NearbyFarmsBody.resolve(
              isLoading: false,
              lookupFinished: true,
              hasData: false,
              hasPermitLines: false),
          NearbyFarmsBody.unavailable);
    });

    test('exhaustive: permitsOnly needs permit lines, results needs data', () {
      for (final l in [false, true]) {
        for (final f in [false, true]) {
          for (final d in [false, true]) {
            for (final pl in [false, true]) {
              final b = NearbyFarmsBody.resolve(
                  isLoading: l, lookupFinished: f, hasData: d, hasPermitLines: pl);
              if (b == NearbyFarmsBody.permitsOnly) expect(pl, isTrue);
              if (b == NearbyFarmsBody.results) expect(d, isTrue);
            }
          }
        }
      }
    });
  });

  group('NearbyFarmsSection widget', () {
    testWidgets('pork, failed lookup, no permits: heading + explainer + unavailable card',
        (t) async {
      await _pump(t, isHog: true);
      expect(find.text(NearbyFarmsCopy.hogTitle), findsOneWidget);
      expect(find.text(NearbyFarmsCopy.hogExplainer), findsOneWidget);
      expect(find.text(NearbyFarmsCopy.unavailable), findsOneWidget);
      expect(find.text('Nearby Hog Farm Compliance'), findsNothing);
    });

    testWidgets('beef, failed lookup: feedlot heading + explainer + unavailable card',
        (t) async {
      await _pump(t, isHog: false);
      expect(find.text(NearbyFarmsCopy.feedlotTitle), findsOneWidget);
      expect(find.text(NearbyFarmsCopy.feedlotExplainer), findsOneWidget);
      expect(find.text(NearbyFarmsCopy.unavailable), findsOneWidget);
    });

    testWidgets('lookup pending shows the loading row, not a bare heading',
        (t) async {
      await _pump(t, isHog: true, lookupFinished: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(NearbyFarmsCopy.unavailable), findsNothing);
    });

    testWidgets('zero-violator response shows the no-violators line',
        (t) async {
      await _pump(t, isHog: true, result: _zeroViolators());
      expect(
          find.text(
              'No EPA-flagged hog CAFO operations with environmental violations within 50 miles of this plant.'),
          findsOneWidget);
      expect(find.text(NearbyFarmsCopy.unavailable), findsNothing);
    });

    testWidgets('failed lookup with permit lines shows the permit lines only',
        (t) async {
      await _pump(t, isHog: true, permitLines: const ['12 state permit records']);
      expect(find.text('12 state permit records'), findsOneWidget);
      expect(find.text(NearbyFarmsCopy.unavailable), findsNothing);
    });
  });
}
