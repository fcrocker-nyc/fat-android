// Meter-card (at-a-glance card) text — pure functions so the strings are
// unit-testable. Mirrors iOS MeterCardText.swift; output strings are identical.
//
// Four lines are built here:
//   • the "N not applicable — …" reason, chosen from WHY each category is
//     not applicable (retail exemption vs prepared / multi-ingredient lane);
//   • the raising-claim pill, which names the claims and their credibility tier;
//   • the prepared-lane ingredient-statement line (informational only);
//   • the seafood sourcing-claim pill (same shape, seafood tier names).
// None of them changes a count, a category status, or the score.

import '../models/fat_models.dart';
import 'prepared_food.dart';
import 'retail_exemption.dart';

class MeterCardText {
  MeterCardText._();

  // ── 1. Not-applicable reason ─────────────────────────────────────────────

  static String retailExemptionLine(int n) =>
      '$n not applicable — retail exemption (no establishment number is required on an in-store cut)';

  static String preparedFoodLine(int n) =>
      '$n not applicable — prepared / multi-ingredient food: no U.S. labeling rule requires these details for ingredient meat';

  static String neutralLine(int n) => '$n not applicable (see each category)';

  /// The reason line for the `.notRequired` categories, or null when none.
  /// The cause is read from each category's own note: the retail-exemption
  /// note, or the prepared-lane notes (per-animal gap / FDA jurisdiction).
  /// Other structural notes (e.g. poultry has no intermediary stage) ride
  /// along with whichever single lane applies. Both lanes, or neither, gives
  /// the neutral line.
  static String? notApplicableLine(
      Map<FATCategory, FATCategoryResult> categories) {
    var total = 0, retail = 0, prepared = 0;
    for (final r in categories.values) {
      if (r.status != DisclosureStatus.notRequired) continue;
      total++;
      if (r.value == RetailExemption.categoryNote) {
        retail++;
      } else if (r.value == PreparedFoodDetector.gapNote ||
          r.value == PreparedFoodDetector.fdaJurisdictionNote) {
        prepared++;
      }
    }
    if (total == 0) return null;
    if (retail > 0 && prepared == 0) return retailExemptionLine(total);
    if (prepared > 0 && retail == 0) return preparedFoodLine(total);
    return neutralLine(total);
  }

  // ── 2. Raising-claim pill ────────────────────────────────────────────────

  static const String noRaisingClaimsLine =
      'No raising claims on this label (such as organic, grass-fed or no antibiotics)';

  /// Categories that carry how-the-animal-was-raised claims.
  static const List<FATCategory> raisingCategories = [
    FATCategory.farmRanch,
    FATCategory.feed,
    FATCategory.animalWelfare,
    FATCategory.medicine,
    FATCategory.hormones,
    FATCategory.organic,
  ];

  /// Interpreter value for "federal regulations prohibit hormones" — a
  /// statement of law, not a claim the producer added.
  static const String _statutoryHormoneValue = 'Statutory prohibition noted';

  /// The raising claims on the label, in category order, with their DISPLAY
  /// tier (tiers are read, never reassigned).
  static List<({String name, ClaimCredibility tier})> raisingClaims(
      Map<FATCategory, FATCategoryResult> categories) {
    final out = <({String name, ClaimCredibility tier})>[];
    for (final c in raisingCategories) {
      final r = categories[c];
      if (r == null) continue;
      if (r.status != DisclosureStatus.known &&
          r.status != DisclosureStatus.partial) {
        continue;
      }
      final tier = r.displayCredibility;
      final value = r.value;
      if (tier == null || value == null || value.isEmpty) continue;
      if (value == _statutoryHormoneValue) continue;
      out.add((name: shortClaimName(value), tier: tier));
    }
    return out;
  }

  /// "Grass Fed (100% forage)" → "Grass Fed"; "Mixed diet (grass + grain) —
  /// no credit" → "Mixed diet". Keeps the head of the interpreter's value.
  static String shortClaimName(String value) {
    var s = value;
    for (final sep in [' — ', ' (', ' | ', '; ']) {
      final i = s.indexOf(sep);
      if (i > 0) s = s.substring(0, i);
    }
    return s.trim();
  }

  static String tierName(ClaimCredibility tier, {bool seafood = false}) =>
      seafood ? tier.seafoodDisplayName : tier.displayName;

  /// Pill text: names up to two claims, then "+N more", then the tier (or
  /// "mixed verification" when the claims sit in different tiers).
  static String claimPillText(Map<FATCategory, FATCategoryResult> categories) {
    final claims = raisingClaims(categories);
    if (claims.isEmpty) return noRaisingClaimsLine;
    final n = claims.length;
    final names = claims.take(2).map((c) => '"${c.name}"').join(', ');
    final more = n > 2 ? ' +${n - 2} more' : '';
    final tiers = claims.map((c) => c.tier).toSet();
    final tierPart =
        tiers.length == 1 ? tierName(tiers.first) : 'mixed verification';
    return '$n raising claim${n == 1 ? '' : 's'}: $names$more — $tierPart';
  }

  /// Strongest tier among the named claims — drives the pill's existing
  /// color/icon mapping (verified → green, USDA program → amber, else gray).
  static ClaimCredibility? strongestClaimTier(
      Map<FATCategory, FATCategoryResult> categories) {
    final tiers = raisingClaims(categories).map((c) => c.tier).toSet();
    for (final t in const [
      ClaimCredibility.verified,
      ClaimCredibility.usdaApproved,
      ClaimCredibility.producerAffidavit,
      ClaimCredibility.labelClaimOnly,
    ]) {
      if (tiers.contains(t)) return t;
    }
    return null;
  }

  // ── 4. Seafood sourcing-claim pill ───────────────────────────────────────

  static const String noSourcingClaimsLine =
      'No sourcing claims on this label (such as MSC, ASC, BAP or "sustainably caught")';

  /// Cat. 5 values that are voluntary sourcing claims (marketing language).
  /// "Vessel name disclosed" / "Fishery disclosed" are source-identity
  /// disclosures, not claims, and are left out. Value → pill name.
  static const Map<String, String> _seafoodSourcingFarmValues = {
    'Responsibly Sourced': 'Responsibly Sourced',
    'Family farm disclosed': 'Family Farm',
  };

  /// Seafood categories whose tiered results are voluntary sourcing,
  /// sustainability or handling claims. Cat. 1 (required language), 2
  /// (species), 4 (origin / COOL), 10 (wild vs farmed, required by COOL),
  /// 14 (quality) and 16 (intermediaries named) are not claims.
  static const List<SeafoodCategory> sourcingCategories = [
    SeafoodCategory.farmVesselFishery,
    SeafoodCategory.animalWelfare,
    SeafoodCategory.medicineAntibioticsChemicals,
    SeafoodCategory.hormones,
    SeafoodCategory.organic,
  ];

  /// MSC on the label. The seafood interpreter records ASC / BAP / GlobalGAP
  /// (Cat. 11) and organic (Cat. 15) but has no MSC slot; the app's
  /// credibility model already rates MSC Third-Party Audited, so the pill
  /// reads it here. Pill-only: no category, count, status or tier changes.
  static final RegExp _msc =
      RegExp(r'\bmsc\b|marine stewardship council', caseSensitive: false);

  static bool labelShowsMSC(String scannedText) => _msc.hasMatch(scannedText);

  /// Dolphin-safe on the label. The term is defined by federal law (Dolphin
  /// Protection Consumer Information Act, 16 U.S.C. 1385) and verified by
  /// NOAA's Tuna Tracking and Verification Program, not a private auditor,
  /// so it sits in the government-program tier (seafood display name
  /// "USDA / FDA program"). OCR-tolerant: i/l/1 confusion, space, hyphen or
  /// no separator. Pill-only: no category, count, status or tier changes.
  static final RegExp _dolphinSafe = RegExp(
      r'\bdolph[il1]n[\s\-_]*(safe|fr[il1]endly)\b',
      caseSensitive: false);

  /// Certified Fair Trade (Fair Trade USA / Fairtrade) — Third-Party Audited.
  static final RegExp _fairTradeCertified = RegExp(
      r'\bfair[\s\-_]*trade[\s\-_]*(certified|usa)\b',
      caseSensitive: false);

  /// Bare "fair trade" with no certifier wording — Unverified Marketing.
  static final RegExp _fairTrade =
      RegExp(r'\bfair[\s\-_]*trade\b', caseSensitive: false);

  static bool labelShowsDolphinSafe(String scannedText) =>
      _dolphinSafe.hasMatch(scannedText);

  /// The Fair Trade claim on the label, if any. The certified form wins, so
  /// a certified label is never also counted as bare "Fair Trade".
  static ({String name, ClaimCredibility tier})? fairTradeClaim(
      String scannedText) {
    if (_fairTradeCertified.hasMatch(scannedText)) {
      return (name: 'Fair Trade Certified', tier: ClaimCredibility.verified);
    }
    if (_fairTrade.hasMatch(scannedText)) {
      return (name: 'Fair Trade', tier: ClaimCredibility.labelClaimOnly);
    }
    return null;
  }

  /// The sourcing claims on a seafood label, in category order (MSC, Dolphin
  /// Safe and Fair Trade sit with Cat. 15 Organic / Certification), with the
  /// interpreter's tiers.
  static List<({String name, ClaimCredibility tier})> sourcingClaims(
      Map<SeafoodCategory, FATCategoryResult> categories, String scannedText) {
    final out = <({String name, ClaimCredibility tier})>[];
    void add(String name, ClaimCredibility tier) {
      if (!out.any((c) => c.name == name)) out.add((name: name, tier: tier));
    }

    for (final c in sourcingCategories) {
      final r = categories[c];
      if (r != null &&
          (r.status == DisclosureStatus.known ||
              r.status == DisclosureStatus.partial)) {
        final tier = r.displayCredibility;
        final value = r.value;
        if (tier != null && value != null && value.isNotEmpty) {
          if (c == SeafoodCategory.farmVesselFishery) {
            final name = _seafoodSourcingFarmValues[value];
            if (name != null) add(name, tier);
          } else if (c == SeafoodCategory.organic) {
            add(value.startsWith('"Organic"') ? 'Organic' : shortClaimName(value),
                tier);
          } else {
            add(shortClaimName(value), tier);
          }
        }
      }
      if (c == SeafoodCategory.organic) {
        if (labelShowsMSC(scannedText)) {
          add('MSC Certified', ClaimCredibility.verified);
        }
        if (labelShowsDolphinSafe(scannedText)) {
          add('Dolphin Safe', ClaimCredibility.usdaApproved);
        }
        final ft = fairTradeClaim(scannedText);
        if (ft != null) add(ft.name, ft.tier);
      }
    }
    return out;
  }

  /// Seafood pill text — same shape as the meat pill, seafood tier names.
  static String seafoodClaimPillText(
      Map<SeafoodCategory, FATCategoryResult> categories, String scannedText) {
    final claims = sourcingClaims(categories, scannedText);
    if (claims.isEmpty) return noSourcingClaimsLine;
    final n = claims.length;
    final names = claims.take(2).map((c) => '"${c.name}"').join(', ');
    final more = n > 2 ? ' +${n - 2} more' : '';
    final tiers = claims.map((c) => c.tier).toSet();
    final tierPart = tiers.length == 1
        ? tierName(tiers.first, seafood: true)
        : 'mixed verification';
    return '$n sourcing claim${n == 1 ? '' : 's'}: $names$more — $tierPart';
  }

  /// Strongest tier among the named seafood claims — same color mapping as meat.
  static ClaimCredibility? seafoodStrongestClaimTier(
      Map<SeafoodCategory, FATCategoryResult> categories, String scannedText) {
    final tiers =
        sourcingClaims(categories, scannedText).map((c) => c.tier).toSet();
    for (final t in const [
      ClaimCredibility.verified,
      ClaimCredibility.usdaApproved,
      ClaimCredibility.producerAffidavit,
      ClaimCredibility.labelClaimOnly,
    ]) {
      if (tiers.contains(t)) return t;
    }
    return null;
  }

  // ── 3. Ingredient statement (prepared lane only) ─────────────────────────

  static const String ingredientFoundLine = 'Ingredient statement: on the label';
  static const String ingredientNotFoundLine =
      "Ingredient statement: not found in the photos (it may be on a panel you didn't photograph)";

  /// Informational line for the prepared / multi-ingredient lane (9 CFR
  /// 317.2(c)(2) and 381.118 require an ingredients statement). Null outside
  /// the lane. Species come from the lane's existing multi-species reader.
  static String? ingredientStatementLine({
    required bool isPreparedFood,
    required String scannedText,
  }) {
    if (!isPreparedFood) return null;
    if (!PreparedFoodDetector.hasIngredientStatement(scannedText)) {
      return ingredientNotFoundLine;
    }
    final species = PreparedFoodDetector.detect(scannedText).speciesMentioned;
    if (species.isEmpty) return ingredientFoundLine;
    return '$ingredientFoundLine — lists: '
        '${species.map((s) => s.toLowerCase()).join(', ')}';
  }
}
