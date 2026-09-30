// Seafood v1.1 (farmed salmon) detail lines.
//
// Every line here is a secondary line shown INSIDE an existing category row on
// the seafood results screen (and, for Cat. 5, on the share card). None of it
// changes a category status, the disclosure count, or the seafood index.
//
//   Cat. 1  Required Basics        — "Color added" line (21 CFR 73.35 / 73.75)
//   Cat. 2  Species Identity       — "wild Atlantic salmon" tripwire
//   Cat. 4  Country / Origin       — "wild Atlantic salmon" tripwire
//   Cat. 5  Farm / Vessel / Fishery — "Grown in: …" production-system line
//   Cat. 7  Processor              — SIMP coverage public-record line
//
// Spec: FAT_Seafood_Spec_Addendum_v1.1_2026-09-29 (changes A, C, D, F).

import '../models/fat_models.dart';
import 'seafood_interpreter.dart';

/// NOAA Fisheries' Seafood Import Monitoring Program covers imports of 13
/// species groups: abalone, Atlantic cod, blue crab (Atlantic), dolphinfish
/// (mahi mahi), grouper, king crab (red), Pacific cod, red snapper, sea
/// cucumber, sharks, shrimp, swordfish and tuna.
class SIMPCoverage {
  SIMPCoverage._();

  static final RegExp _covered = RegExp(
    r'\b(tuna|albacore|skipjack|ahi|bigeye|bluefin|yellowfin|cod|codfish|'
    r'red snapper|snapper|grouper|mahi mahi|mahi-mahi|mahi|dolphinfish|'
    r'king crab|blue crab|abalone|sea cucumbers?|sharks?|shrimp|prawns?|'
    r'swordfish)\b',
  );

  /// True when the detected species (e.g. "Yellowfin Tuna", "Atlantic Cod",
  /// "Shrimp") falls in one of the 13 SIMP species groups.
  static bool isCovered(String species) =>
      _covered.hasMatch(species.toLowerCase());
}

enum SeafoodDetailKind { info, flag }

class SeafoodDetailLine {
  final String text;
  final SeafoodDetailKind kind;
  const SeafoodDetailLine(this.text, [this.kind = SeafoodDetailKind.info]);

  @override
  String toString() => text;
}

class SeafoodDetailLines {
  SeafoodDetailLines._();

  // ── User-facing strings (kept verbatim for iOS parity) ──
  static const String grownInPrefix = 'Grown in: ';
  static const String grownInVague = 'not stated on label (marketing language only)';
  static const String certifiedFarmSuffix =
      ' — certified farm; site not identified from the label.';
  static const String colorAstaxanthin =
      'Color added (astaxanthin in feed) — declared as required by 21 CFR 73.35.';
  static const String colorCanthaxanthin =
      'Color added (canthaxanthin in feed) — declared as required by 21 CFR 73.75.';
  static const String colorGeneric =
      'Color added — declared as required by 21 CFR 73.35 / 73.75.';
  static const String colorNotFound =
      'No color-additive statement found on this label.';
  static const String simpCovered =
      "Covered by NOAA's Seafood Import Monitoring Program (SIMP).";
  static String simpNotCovered(String speciesGroup) =>
      "$speciesGroup is not one of the 13 species groups covered by NOAA's Seafood Import Monitoring Program.";
  static const String wildAtlanticSalmonTripwire =
      'Label says wild Atlantic salmon; U.S. supply of Atlantic salmon is farm-raised (NOAA) — unverified.';

  /// Header line of a service-case (placard) capture saved to History. Those
  /// records carry a summary, not label text, so no v1.1 label lines apply.
  static const String serviceCaseHeader =
      'FAT Service-Case Capture (loose seafood at a counter)';

  /// Federal-baseline line for the seafood at-a-glance card. Most seafood is
  /// FDA-regulated; only catfish / Siluriformes are FSIS-inspected; loose fish
  /// at a service case is held to the AMS retail placard.
  static String baselineLine(FATResult r) {
    if (r.scannedText.startsWith(serviceCaseHeader)) {
      return 'Meets AMS retail placard requirements — as is required of loose seafood.';
    }
    if (r.isSiluriformes) {
      return 'Meets USDA FSIS minimums — as is required of federally inspected catfish.';
    }
    return 'Meets FDA labeling requirements — as is required of all seafood sold in the United States.';
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static final RegExp _ascOrBap = RegExp(r'\b(asc|bap)\b');

  // ── Cat. 5 — production system ──

  /// "Grown in: …" line, or null (wild fish, catfish, or nothing to say).
  static String? grownInLine(SeafoodProductionSystem? system, String scannedText) {
    if (system == null || system == SeafoodProductionSystem.notApplicableWild) {
      return null;
    }
    final t = _norm(scannedText);
    final status = SeafoodInterpreter.productionSystemStatus(system, t);
    final label = status == DisclosureStatus.partial
        ? grownInVague
        : system.grownInLabel;
    var line = '$grownInPrefix$label';
    if (_ascOrBap.hasMatch(t)) line += certifiedFarmSuffix;
    return line;
  }

  // ── Cat. 1 — color added ──

  static bool _isSalmonid(String species, String t) {
    final s = species.toLowerCase();
    return s.contains('salmon') ||
        s.contains('trout') ||
        t.contains('steelhead') ||
        t.contains('arctic char') ||
        RegExp(r'\bchar\b').hasMatch(t);
  }

  /// Color-additive line for farmed salmonids, or null when the rule does not
  /// apply (wild fish, non-salmonids, unknown method on anything but Atlantic
  /// salmon).
  static String? colorLine({
    required String? species,
    required SeafoodProductionMethod? method,
    required String scannedText,
  }) {
    if (species == null) return null;
    final t = _norm(scannedText);
    if (!_isSalmonid(species, t)) return null;
    final applies = method == SeafoodProductionMethod.farmRaised ||
        (method == null && species.toLowerCase().contains('atlantic salmon'));
    if (!applies) return null;
    if (t.contains('astaxanthin')) return colorAstaxanthin;
    if (t.contains('canthaxanthin')) return colorCanthaxanthin;
    if (t.contains('color added') ||
        t.contains('colour added') ||
        t.contains('artificial color')) {
      return colorGeneric;
    }
    return colorNotFound;
  }

  // ── Cat. 7 — SIMP ──

  static const _domesticMarkers = [
    'usa', 'u.s', 'united states', 'alaska', 'america',
  ];

  static final RegExp _productOf = RegExp(r'\bproduct of (?:the )?');

  /// Imported = a country of origin is stated and it is not the USA. Uses the
  /// Cat. 4 value when Known, otherwise a "product of …" statement in the text.
  static bool? _isImported(FATCategoryResult? origin, String t) {
    if (origin != null &&
        origin.status == DisclosureStatus.known &&
        origin.value != null) {
      final v = origin.value!.toLowerCase();
      return !_domesticMarkers.any(v.contains);
    }
    final m = _productOf.firstMatch(t);
    if (m != null) {
      final rest = t.substring(m.end);
      if (rest.trim().isEmpty) return null;
      return !_domesticMarkers.any(rest.startsWith);
    }
    return null;
  }

  /// Species group named in the "not covered" line ("Salmon", "Trout",
  /// otherwise the detected species name).
  static String _speciesGroup(String species) {
    final s = species.toLowerCase();
    if (s.contains('salmon')) return 'Salmon';
    if (s.contains('trout')) return 'Trout';
    return species;
  }

  static String? simpLine({
    required String? species,
    required FATCategoryResult? origin,
    required String scannedText,
  }) {
    if (species == null) return null;
    final t = _norm(scannedText);
    if (_isImported(origin, t) != true) return null;
    // A generic "Crab" is covered only as king crab or blue crab; when the
    // label doesn't say which, stay silent rather than guess.
    if (species.toLowerCase() == 'crab') {
      if (t.contains('king crab') || t.contains('blue crab')) return simpCovered;
      return null;
    }
    return SIMPCoverage.isCovered(species)
        ? simpCovered
        : simpNotCovered(_speciesGroup(species));
  }

  // ── Cat. 2 / Cat. 4 — wild Atlantic salmon tripwire ──

  static bool wildAtlanticSalmon({
    required String? species,
    required SeafoodProductionMethod? method,
  }) =>
      species != null &&
      species.toLowerCase() == 'atlantic salmon' &&
      method == SeafoodProductionMethod.wildCaught;

  // ── All lines for a result ──

  /// Detail lines per category for a seafood result. Empty for meat, for
  /// catfish / Siluriformes (fork unchanged), and for service-case captures.
  static Map<SeafoodCategory, List<SeafoodDetailLine>> forResult(FATResult r) {
    final out = <SeafoodCategory, List<SeafoodDetailLine>>{};
    if (!r.isSeafood || r.isSiluriformes) return out;
    if (r.scannedText.startsWith(serviceCaseHeader)) return out;

    void add(SeafoodCategory c, SeafoodDetailLine l) =>
        (out[c] ??= []).add(l);

    final speciesResult = r.seafoodCategories[SeafoodCategory.speciesIdentity];
    final species = speciesResult?.status == DisclosureStatus.known
        ? speciesResult?.value
        : null;

    final color = colorLine(
        species: species,
        method: r.productionMethod,
        scannedText: r.scannedText);
    if (color != null) {
      add(SeafoodCategory.regulatoryRequiredLanguage, SeafoodDetailLine(color));
    }

    if (wildAtlanticSalmon(species: species, method: r.productionMethod)) {
      const flag = SeafoodDetailLine(
          wildAtlanticSalmonTripwire, SeafoodDetailKind.flag);
      add(SeafoodCategory.speciesIdentity, flag);
      add(SeafoodCategory.countryOrigin, flag);
    }

    final grown = grownInLine(r.productionSystem, r.scannedText);
    if (grown != null) {
      add(SeafoodCategory.farmVesselFishery, SeafoodDetailLine(grown));
    }

    final simp = simpLine(
        species: species,
        origin: r.seafoodCategories[SeafoodCategory.countryOrigin],
        scannedText: r.scannedText);
    if (simp != null) {
      add(SeafoodCategory.processor, SeafoodDetailLine(simp));
    }
    return out;
  }
}
