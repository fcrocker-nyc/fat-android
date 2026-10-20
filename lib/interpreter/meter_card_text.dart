// Meter-card (at-a-glance card) text — pure functions so the strings are
// unit-testable. Mirrors iOS MeterCardText.swift; output strings are identical.
//
// Three lines are built here:
//   • the "N not applicable — …" reason, chosen from WHY each category is
//     not applicable (retail exemption vs prepared / multi-ingredient lane);
//   • the raising-claim pill, which names the claims and their credibility tier;
//   • the prepared-lane ingredient-statement line (informational only).
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
