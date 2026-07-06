// Models — direct port of FATCategory.swift, FATCategoryResult.swift,
// ClaimCredibility.swift, and FATResult.swift
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// MARK: - ClaimCredibility
// ─────────────────────────────────────────────

enum ClaimCredibility {
  verified,        // Third-party audited (weight 1.0)
  usdaApproved,    // USDA-reviewed / NPDES permit (weight 0.7)
  producerAffidavit, // Producer affidavit only (weight 0.4)
  labelClaimOnly;  // Unverified marketing (weight 0.2)

  String get displayName {
    switch (this) {
      case verified:          return 'Third-Party Audited';
      case usdaApproved:      return 'USDA-Reviewed';
      case producerAffidavit: return 'Producer Affidavit';
      case labelClaimOnly:    return 'Unverified Marketing';
    }
  }

  String get explanation {
    switch (this) {
      case verified:
        return 'Independently audited on-farm by a third-party certifier.';
      case usdaApproved:
        return 'USDA-reviewed under a federal program with audit teeth (Process Verified, USDA grade marks, organic verification) — or identity-substantiated via EPA NPDES CAFO permit or qualifying state CAFO permit (per FAT DSA v1.1).';
      case producerAffidavit:
        return 'FSIS approved the label language; the producer\'s affidavit is the only backing — no independent on-farm audit.';
      case labelClaimOnly:
        return 'Printed on the label with no known third-party audit and no government label-language approval.';
    }
  }

  String get iconData {
    switch (this) {
      case verified:          return 'verified';
      case usdaApproved:      return 'approval';
      case producerAffidavit: return 'description';
      case labelClaimOnly:    return 'info';
    }
  }

  double get scoreWeight {
    switch (this) {
      case verified:          return 1.0;
      case usdaApproved:      return 0.7;
      case producerAffidavit: return 0.4;
      case labelClaimOnly:    return 0.2;
    }
  }
}

// ─────────────────────────────────────────────
// MARK: - CaptivityStatus
// ─────────────────────────────────────────────

enum CaptivityStatus {
  packerOwned,
  packerContracted,
  independent,
  undisclosed;

  String get displayName {
    switch (this) {
      case packerOwned:       return 'Packer-Owned';
      case packerContracted:  return 'Captive Supply (Contracted)';
      case independent:       return 'Independent';
      case undisclosed:       return 'Captivity Not Disclosed';
    }
  }
}

// ─────────────────────────────────────────────
// MARK: - FATCategoryResult
// ─────────────────────────────────────────────

enum DisclosureStatus { known, partial, missing, notRequired }

class FATCategoryResult {
  final DisclosureStatus status;
  final String? value;
  final ClaimCredibility? credibility;
  final String? credibilityNote;
  final CaptivityStatus? captivityStatus;

  const FATCategoryResult({
    required this.status,
    this.value,
    this.credibility,
    this.credibilityNote,
    this.captivityStatus,
  });

  static const FATCategoryResult missing = FATCategoryResult(status: DisclosureStatus.missing);
}

// ─────────────────────────────────────────────
// MARK: - FATCategory
// ─────────────────────────────────────────────

enum FATCategory {
  usdaFsisRequiredLanguage,
  species,
  breed,
  countryOrigin,
  farmRanch,
  supplyChainIntermediary,
  processor,
  feed,
  animalWelfare,
  pasture,
  regenerative,
  qualityPalatability,
  dietaryAttributes,
  medicine,
  hormones,
  ageAtSlaughter,
  organic;

  String get displayName {
    switch (this) {
      case usdaFsisRequiredLanguage: return 'USDA / FSIS Required Language';
      case species:                  return 'Species';
      case breed:                    return 'Breed';
      case countryOrigin:            return 'Country / Origin';
      case farmRanch:                return 'Farm / Ranch';
      case supplyChainIntermediary:  return 'Feedlot / Contract Grower';
      case processor:                return 'Processor';
      case feed:                     return 'Feed';
      case animalWelfare:            return 'Animal Welfare';
      case pasture:                  return 'Pasture / Outdoor Access';
      case regenerative:             return 'Regenerative / Land Use';
      case qualityPalatability:      return 'Quality / Palatability';
      case dietaryAttributes:        return 'Dietary Attributes';
      case medicine:                 return 'Medicine / Antibiotics';
      case hormones:                 return 'Hormones';
      case ageAtSlaughter:           return 'Age at Slaughter';
      case organic:                  return 'Organic (USDA NOP)';
    }
  }
}

// ─────────────────────────────────────────────
// MARK: - Seafood — product type, production method, categories
// ─────────────────────────────────────────────

enum ProductType { meat, seafood }

enum SeafoodProductionMethod {
  wildCaught,
  farmRaised;

  String get displayName {
    switch (this) {
      case wildCaught: return 'Wild-Caught';
      case farmRaised: return 'Farm-Raised';
    }
  }
}

/// 16 FAT seafood transparency categories (port of iOS SeafoodCategory).
enum SeafoodCategory {
  regulatoryRequiredLanguage,
  speciesIdentity,
  strainVariety,
  countryOrigin,
  farmVesselFishery,
  processor,
  productionMethodFeed,
  animalWelfare,
  qualityHandling,
  dietaryAttributesAdditives,
  medicineAntibioticsChemicals,
  ageAtHarvest,
  enforcementCompliance,
  supplyChainIntermediary,
  environmentalImpact,
  economicConcentration;

  String get displayName {
    switch (this) {
      case regulatoryRequiredLanguage:   return 'Regulatory Required Language';
      case speciesIdentity:              return 'Species Identity';
      case strainVariety:                return 'Strain / Variety';
      case countryOrigin:                return 'Country / Origin';
      case farmVesselFishery:            return 'Farm / Vessel / Fishery';
      case processor:                    return 'Processor';
      case productionMethodFeed:         return 'Production Method & Feed';
      case animalWelfare:                return 'Fish Welfare';
      case qualityHandling:              return 'Quality & Handling';
      case dietaryAttributesAdditives:   return 'Dietary Attributes & Additives';
      case medicineAntibioticsChemicals: return 'Medicine / Antibiotics / Chemicals';
      case ageAtHarvest:                 return 'Age / Grow-Out Period';
      case enforcementCompliance:        return 'Enforcement & Compliance';
      case supplyChainIntermediary:      return 'Supply-Chain Intermediaries';
      case environmentalImpact:          return 'Environmental Impact';
      case economicConcentration:        return 'Economic Concentration / Foreign Ownership';
    }
  }

  /// Whether the category is app-scored (vs website-only / hidden).
  bool get isAppSupported {
    switch (this) {
      case environmentalImpact:
      case economicConcentration:
      case ageAtHarvest:
        return false;
      default:
        return true;
    }
  }
}

// ─────────────────────────────────────────────
// MARK: - FATResult
// ─────────────────────────────────────────────

class FATResult {
  final String id;
  final String scannedText;
  final DateTime scannedAt;
  final Map<FATCategory, FATCategoryResult> categories;
  final String? detectedEstablishmentNumber;
  final bool estMissing;
  final bool estSpeciesMismatch;
  final String? estSpeciesMismatchNote;
  final String? speciesClaimMisuseNote;

  // ── Seafood (populated when productType == seafood) ──
  final ProductType productType;
  final Map<SeafoodCategory, FATCategoryResult> seafoodCategories;
  final bool isSiluriformes;
  final SeafoodProductionMethod? productionMethod;

  FATResult({
    String? id,
    required this.scannedText,
    DateTime? scannedAt,
    required this.categories,
    this.detectedEstablishmentNumber,
    this.estMissing = false,
    this.estSpeciesMismatch = false,
    this.estSpeciesMismatchNote,
    this.speciesClaimMisuseNote,
    this.productType = ProductType.meat,
    this.seafoodCategories = const {},
    this.isSiluriformes = false,
    this.productionMethod,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        scannedAt = scannedAt ?? DateTime.now();

  bool get isSeafood => productType == ProductType.seafood;

  Iterable<FATCategoryResult> get _activeValues =>
      isSeafood ? seafoodCategories.values : categories.values;

  int get knownCount   => _activeValues.where((r) => r.status == DisclosureStatus.known).length;
  int get partialCount => _activeValues.where((r) => r.status == DisclosureStatus.partial).length;
  int get missingCount => _activeValues.where((r) => r.status == DisclosureStatus.missing).length;

  bool get regulatoryPassed =>
      categories[FATCategory.usdaFsisRequiredLanguage]?.status == DisclosureStatus.known;

  /// 0–100 FAT Score: 70% Disclosure + 30% Credibility.
  /// Cat 1 (Required Basics), Cat 2 (Species — mandatory common/usual name), and
  /// the Processor identifier are scored pass/fail (present = full credit,
  /// absent = 0; no partial). `oshaViolation` /
  /// `epaViolation` apply Cat 7 enforcement penalties against the disclosure
  /// pillar, stacking: EPA −3, OSHA −2. EPA is data-pending at the call site.
  double fatScoreWith({bool oshaViolation = false, bool epaViolation = false}) {
    final allCats = FATCategory.values;
    // Per-category max weight: Breed = 3, Farm/Ranch = 6, every other = 5.
    double weightOf(FATCategory c) =>
        c == FATCategory.breed ? 3.0 : (c == FATCategory.farmRanch ? 6.0 : 5.0);
    // All-or-nothing (present-or-absent, no partial credit): the three mandatory
    // disclosures (Required Basics, Species, Processor) plus Breed, Country of
    // Origin, Farm/Ranch, and Age at Slaughter — full credit only for a specific
    // disclosure; vague marketing terms ("family farm", "young") earn 0.
    bool allOrNothing(FATCategory c) =>
        c == FATCategory.usdaFsisRequiredLanguage ||
        c == FATCategory.species ||
        c == FATCategory.processor ||
        c == FATCategory.breed ||
        c == FATCategory.countryOrigin ||
        c == FATCategory.farmRanch ||
        c == FATCategory.ageAtSlaughter;
    // Pillar 1 — Disclosure (70 pts)
    double disclosurePoints = 0;
    double maxDisclosure = 0;
    for (final cat in allCats) {
      final w = weightOf(cat);
      maxDisclosure += w;
      final r = categories[cat];
      if (r == null) continue;
      switch (r.status) {
        case DisclosureStatus.known:    disclosurePoints += w; break;
        case DisclosureStatus.partial:  disclosurePoints += allOrNothing(cat) ? 0 : w * 0.4; break;
        default: break;
      }
    }
    double disclosurePillar = (disclosurePoints / maxDisclosure) * 70;
    final penalty = (epaViolation ? 3.0 : 0) + (oshaViolation ? 2.0 : 0);
    disclosurePillar = (disclosurePillar - penalty).clamp(0, 70).toDouble();

    // Pillar 2 — Credibility (30 pts)
    final credWeights = categories.values
        .where((r) => r.credibility != null)
        .map((r) => r.credibility!.scoreWeight)
        .toList();
    double credPillar = 0;
    if (credWeights.isNotEmpty) {
      final avg = credWeights.reduce((a, b) => a + b) / credWeights.length;
      credPillar = avg * 30;
    }

    return (disclosurePillar + credPillar).clamp(0, 100).toDouble();
  }

  double get fatScore => fatScoreWith();

  static String gradeFor(double s) {
    if (s >= 80) return 'A';
    if (s >= 65) return 'B';
    if (s >= 50) return 'C';
    if (s >= 35) return 'D';
    return 'F';
  }

  static Color gradeColorFor(double s) {
    switch (gradeFor(s)) {
      case 'A': return const Color(0xFF34A853);
      case 'B': return const Color(0xFF64B446);
      case 'C': return const Color(0xFFFBC02D);
      case 'D': return const Color(0xFFEA8600);
      default:  return const Color(0xFFDC2626);
    }
  }

  String get grade => gradeFor(fatScore);
  Color get gradeColor => gradeColorFor(fatScore);

  // ── Seafood FAT Score (mirrors iOS SeafoodScore) ──
  // 70 pts disclosure + 30 pts credibility, scored ONLY over app-supported
  // seafood categories. `.notRequired` excluded from both numerator and
  // denominator. strainVariety capped at 2 pts (mirrors meat breed).

  double get seafoodDisclosurePercent => _seafoodPillars().$1;
  double get seafoodCredibilityPercent => _seafoodPillars().$2;

  (double, double, double) _seafoodPillars(
      {bool oshaViolation = false, bool epaViolation = false}) {
    final scored =
        SeafoodCategory.values.where((c) => c.isAppSupported).toList();
    double maxPossible = 0, earned = 0;
    for (final cat in scored) {
      // Strain/Variety (breed-equiv) = 3, Farm/Vessel/Fishery (source) = 6,
      // every other = 5.
      final w = cat == SeafoodCategory.strainVariety
          ? 3.0
          : (cat == SeafoodCategory.farmVesselFishery ? 6.0 : 5.0);
      // All-or-nothing (present-or-absent, no partial credit): the mandatory
      // disclosures (Required Basics, Species Identity, Processor) plus Strain/
      // Variety, Country of Origin, Farm/Vessel/Fishery, and Age/Grow-Out.
      final allOrNothing = cat == SeafoodCategory.regulatoryRequiredLanguage ||
          cat == SeafoodCategory.speciesIdentity ||
          cat == SeafoodCategory.processor ||
          cat == SeafoodCategory.strainVariety ||
          cat == SeafoodCategory.countryOrigin ||
          cat == SeafoodCategory.farmVesselFishery ||
          cat == SeafoodCategory.ageAtHarvest;
      switch (seafoodCategories[cat]?.status ?? DisclosureStatus.missing) {
        case DisclosureStatus.known:    maxPossible += w; earned += w; break;
        case DisclosureStatus.partial:  maxPossible += w; earned += allOrNothing ? 0 : w * 0.4; break;
        case DisclosureStatus.missing:  maxPossible += w; break;
        case DisclosureStatus.notRequired: break;
      }
    }
    final disclosurePct = maxPossible > 0 ? (earned / maxPossible).clamp(0, 1).toDouble() : 0.0;

    final disclosed = scored
        .map((c) => seafoodCategories[c])
        .whereType<FATCategoryResult>()
        .where((r) => r.status == DisclosureStatus.known || r.status == DisclosureStatus.partial)
        .toList();
    double credPct = 0;
    if (disclosed.isNotEmpty) {
      double sum = 0;
      for (final d in disclosed) {
        sum += d.credibility?.scoreWeight ?? 0.5;
      }
      credPct = (sum / disclosed.length).clamp(0, 1).toDouble();
    }
    // Enforcement penalties against the Processor disclosure score, stacking:
    // EPA −3, OSHA −2. Floored at 0. (disclosurePct stays raw for the bar.)
    final penalty = (epaViolation ? 3.0 : 0) + (oshaViolation ? 2.0 : 0);
    final disclosurePillarPts = (disclosurePct * 70 - penalty).clamp(0, 70).toDouble();
    final total = (disclosurePillarPts + credPct * 30).clamp(0, 100).toDouble();
    return (disclosurePct, credPct, total);
  }

  int get seafoodFatScore => _seafoodPillars().$3.round();
  int seafoodFatScoreWith({bool oshaViolation = false, bool epaViolation = false}) =>
      _seafoodPillars(oshaViolation: oshaViolation, epaViolation: epaViolation).$3.round();

  String get seafoodGrade {
    final s = seafoodFatScore;
    if (s >= 80) return 'A';
    if (s >= 65) return 'B';
    if (s >= 50) return 'C';
    if (s >= 35) return 'D';
    return 'F';
  }

  Color get seafoodGradeColor {
    switch (seafoodGrade) {
      case 'A': return const Color(0xFF34A853);
      case 'B': return const Color(0xFF64B446);
      case 'C': return const Color(0xFFFBC02D);
      case 'D': return const Color(0xFFEA8600);
      default:  return const Color(0xFFDC2626);
    }
  }
}
