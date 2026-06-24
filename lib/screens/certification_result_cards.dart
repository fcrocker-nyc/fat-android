// certification_result_cards.dart
// FAT App (Android) — consumer-facing certification result cards.
//
// Flutter port of the four iOS "result view" components:
//   • GrassFedResultView.swift      → GrassFedResultCard
//   • CertificationResultView.swift → CertificationResultCard
//   • PastureResultView.swift       → PastureResultCard
//   • RegenerativeResultView.swift  → RegenerativeResultCard
//
// Each card is a self-contained StatelessWidget with a static
// `maybeFrom(FATResult result, String scannedText)` entry point that runs the
// same keyword detection the iOS detectors run, derives its claim list from the
// scanned OCR text, and returns null when there is nothing to show. The knowledge
// base text (consumer alerts, explanations, FSIS requirements) is ported verbatim
// from the iOS *Certification.swift files so the Android cards read identically.
//
// These cards do NOT depend on the Android LabelInterpreter's coarse single-value
// detection (which collapses, e.g., all grass claims to one "Grass Fed" value).
// They re-run the finer-grained iOS keyword logic here so the multi-claim,
// credibility-tiered iOS layouts can be reproduced faithfully. The Android
// FATResult is used only to read the detected species (for pasture/regen
// species-specific framing).

import 'package:flutter/material.dart';
import '../models/fat_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local color tokens — mirror the FATTheme.swift names the iOS views reference
// but that the Android FATTheme (theme/fat_theme.dart) does not expose. Hex
// values are matched to the iOS asset catalog / FATTheme definitions.
// ─────────────────────────────────────────────────────────────────────────────

class _CertColors {
  _CertColors._();

  // Greens
  static const Color successGreen = Color(0xFF27AE60);
  static const Color successGreenSoft = Color(0xFFE7F6EE);

  // Ambers / oranges
  static const Color fatAmber = Color(0xFFCA8A04);
  static const Color fatAmberTint = Color(0xFFFBF3DC);
  static const Color fatOrange = Color(0xFFE67E22);
  static const Color fatOrangeTint = Color(0xFFFDEEE0);

  // Reds
  static const Color danger = Color(0xFFDC2626);
  static const Color fatRedTint = Color(0xFFFCE7E7);

  // Blues
  static const Color fatBlue = Color(0xFF2563EB);
  static const Color certBlue = Color(0xFF1D4ED8);
  static const Color certLightBlue = Color(0xFF3B82F6);
  static const Color certPaleBlue = Color(0xFFDCE6FB);

  // Text / neutrals
  static const Color fatDarkBlue = Color(0xFF1F2A44);
  static const Color fatBodyText = Color(0xFF333333);
  static const Color fatGray = Color(0xFF6B7280);
  static const Color fatLightGray = Color(0xFF9CA3AF);
  static const Color fatPaleGray = Color(0xFFB0B6BE);
  static const Color secondary = Color(0xFF6B7280);

  // systemGray equivalents used as card backgrounds in the iOS views
  static const Color systemGray6 = Color(0xFFF2F2F7);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemBackground = Color(0xFFFFFFFF);

  // Welfare tier colors (WelfareRating.colorHex in the iOS knowledge base)
  static const Color tierHighest = Color(0xFF2C5F2D);
  static const Color tierHigh = Color(0xFF17A589);
  static const Color tierMeaningful = Color(0xFF7CB342);
  static const Color tierModerate = Color(0xFFF39C12);
  static const Color tierMarginal = Color(0xFFF1C40F);
  static const Color tierMisleading = Color(0xFFE74C3C);

  static const Color green = Color(0xFF34A853);
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═════════════════════════════════════════════════════════════════════════════

/// Normalize OCR text the way the iOS detectors do: lowercase, dashes → spaces,
/// newlines → spaces, collapse whitespace.
String _normalize(String text) => text
    .toLowerCase()
    .replaceAll('-', ' ')
    .replaceAll('\n', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Read the detected species value from the Android FATResult (Title-case, e.g.
/// "Beef", "Pork", "Chicken"). Returns null when species was not detected.
String? _detectedSpecies(FATResult result) {
  final v = result.categories[FATCategory.species]?.value;
  if (v == null) return null;
  // Strip the "(Siluriformes)" suffix on catfish so equality checks stay simple.
  return v.split('(').first.trim();
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. GRASS-FED  (port of GrassFedResultView.swift + GrassFedCertification.swift)
// ═════════════════════════════════════════════════════════════════════════════

enum _GrassFedClaimType {
  grassFed100,
  grassFinished,
  grainFedGrassFinished,
  partialGrassFed,
  grassFedAGA,
  grassFedAGW,
  grassFedPVP,
  grassFedUnspecified,
}

enum _GrassFedCredibility {
  thirdPartyAudited,
  usdaProcessVerified,
  fsisApproved,
  partialClaim,
  weakerThanExpected,
}

extension _GrassFedCredibilityLabel on _GrassFedCredibility {
  String get displayLabel {
    switch (this) {
      case _GrassFedCredibility.thirdPartyAudited:
        return 'Third-Party Audited';
      case _GrassFedCredibility.usdaProcessVerified:
        return 'USDA Process Verified';
      case _GrassFedCredibility.fsisApproved:
        return 'FSIS Label Approved (Affidavit Only)';
      case _GrassFedCredibility.partialClaim:
        return 'Partial Claim';
      case _GrassFedCredibility.weakerThanExpected:
        return 'Weaker Than Most Consumers Expect';
    }
  }
}

class _GrassFedClaimMatch {
  final _GrassFedClaimType claimType;
  final _GrassFedCredibility credibility;
  final double confidence;
  final String consumerAlert;
  final String detailedExplanation;
  final String fsisRequirement;
  final int? percentage;

  const _GrassFedClaimMatch({
    required this.claimType,
    required this.credibility,
    required this.confidence,
    required this.consumerAlert,
    required this.detailedExplanation,
    required this.fsisRequirement,
    this.percentage,
  });
}

/// Verbatim knowledge-base strings from GrassFedCertification.swift.
class _GrassFedKB {
  _GrassFedKB._();

  static const alertGrassFedNoCert =
      'This label says "grass-fed" but has no third-party certification. '
      'Under FSIS rules, this claim is backed only by a producer affidavit — no audit.';

  static const alertGrassFinished =
      '"Grass-finished" is the WEAKER claim under FSIS rules. '
      'The animal may have been fed grain for most of its life. '
      'Only the final finishing phase was on grass.';

  static const alertGrainFedGrassFinished =
      'This label explicitly states the animal was fed grain and finished on grass. '
      'This is a mixed-diet program, not 100% grass-fed.';

  static const alertPartialGrassFed =
      'This is a partial grass-fed claim. The animal received grain for a portion of its diet. '
      'FSIS permits this labeling as long as the percentage is disclosed.';

  static const alertAGACertified =
      'AGA-certified: 100% forage diet, no feedlot, no antibiotics, no hormones, '
      'born and raised in the USA. Independently audited every 15 months.';

  static const alertAGWCertified =
      'Certified Grassfed by A Greener World: 100% forage diet with full birth-to-slaughter '
      'traceability. Requires Animal Welfare Approved certification as a prerequisite.';

  static const alertPVP =
      'USDA Process Verified: The producer defined their own grass-fed standard '
      'and USDA audits for compliance with that self-defined standard. '
      'No uniform baseline — two PVP operations may have different practices.';

  static const explainGrassFedFSIS =
      'Under current FSIS guidance (FSIS-GD-2024-0006), "grass-fed" requires that cattle '
      'were fed exclusively forage after weaning. The diet must be 100% derived from grass, '
      'forbs, legumes, hay, haylage, baleage, silage, corn silage (vegetative stage), and '
      'other roughage. Animals cannot be fed grain or grain by-products, must have continuous '
      'access to pasture during the growing season, and cannot be confined to a feedlot. '
      'However, FSIS approval is based on a producer affidavit — most farms are never audited.';

  static const explainGrassFinishedFSIS =
      'FSIS treats "grass-finished" as a distinct and weaker claim than "grass-fed." '
      'Under FSIS rules, grass-finished animals CAN receive grain during their lifetime — '
      'only the final finishing phase must be on grass. A label stating "Grain Fed, Grass '
      'Finished" is considered truthful and not misleading by FSIS. This is the inverse of '
      'how most consumers interpret these terms.';

  static const explainPartialClaim =
      'FSIS permits partial grass-fed claims when producers disclose the percentage: '
      '"90 percent grassfed," "75 percent grassfed," or even "10 percent grassfed." '
      'While technically transparent, these partial claims appear alongside 100% grass-fed '
      'products on store shelves with no standardized visual hierarchy.';

  static const explainAGA =
      'The American Grassfed Association certification (est. 2009) requires: 100% forage diet '
      'from weaning to harvest; raised on pasture, never confined; no antibiotics or added '
      'hormones; born and raised on American family farms. Producers are inspected by '
      'independent third parties at least every 15 months. If an animal needs antibiotics, '
      'it is treated but removed from the certified program.';

  static const explainAGW =
      'Certified Grassfed by A Greener World cannot stand alone — it is an add-on to the '
      'Animal Welfare Approved (AWA) certification. Producers must first meet AWA\'s comprehensive '
      'welfare standards. The diet must be solely derived from grass and forage throughout the '
      'animal\'s entire life. Animals must be traceable from birth to slaughter. No grain, grain '
      'by-products, or feed concentrates are permitted.';

  static const explainPVP =
      'The USDA Process Verified Program is not a standard — it is an audit framework. '
      'The producer defines what "grass-fed" means within their operation, and USDA verifies '
      'compliance with that self-defined standard. Two PVP-verified operations may have '
      'materially different practices while both carrying USDA verification.';

  static const fsisReqGrassFed =
      'FSIS requires: 100% forage diet after weaning; no grain or grain by-products; '
      'continuous pasture access during growing season; no feedlot confinement.';

  static const fsisReqGrassFinished =
      'FSIS requires only that the finishing phase be on grass/forage. '
      'Grain feeding earlier in life is permitted.';

  static const fsisReqPartial =
      'FSIS requires the percentage of grass in the diet to be disclosed on the label.';
}

/// Port of GrassFedDetector.detect(in:).
List<_GrassFedClaimMatch> _detectGrassFed(String text) {
  final claims = <_GrassFedClaimMatch>[];

  // 1. AGA
  bool agaMatched = false;
  for (final p in [
    'american grassfed',
    'american grass fed',
    'aga certified',
    'aga grassfed',
  ]) {
    if (text.contains(p)) {
      claims.add(const _GrassFedClaimMatch(
        claimType: _GrassFedClaimType.grassFedAGA,
        credibility: _GrassFedCredibility.thirdPartyAudited,
        confidence: 0.95,
        consumerAlert: _GrassFedKB.alertAGACertified,
        detailedExplanation: _GrassFedKB.explainAGA,
        fsisRequirement: _GrassFedKB.fsisReqGrassFed,
      ));
      agaMatched = true;
      break;
    }
  }

  // 2. AGW Certified Grassfed
  bool agwMatched = false;
  for (final p in [
    'certified grassfed by agw',
    'certified grass fed by agw',
    'grassfed by a greener world',
    'certified grassfed by a greener world',
  ]) {
    if (text.contains(p)) {
      claims.add(const _GrassFedClaimMatch(
        claimType: _GrassFedClaimType.grassFedAGW,
        credibility: _GrassFedCredibility.thirdPartyAudited,
        confidence: 0.95,
        consumerAlert: _GrassFedKB.alertAGWCertified,
        detailedExplanation: _GrassFedKB.explainAGW,
        fsisRequirement: _GrassFedKB.fsisReqGrassFed,
      ));
      agwMatched = true;
      break;
    }
  }
  if (!agwMatched &&
      (text.contains('animal welfare approved') || text.contains('agw')) &&
      (text.contains('grass fed') || text.contains('grassfed'))) {
    claims.add(const _GrassFedClaimMatch(
      claimType: _GrassFedClaimType.grassFedAGW,
      credibility: _GrassFedCredibility.thirdPartyAudited,
      confidence: 0.75,
      consumerAlert: _GrassFedKB.alertAGWCertified,
      detailedExplanation: _GrassFedKB.explainAGW,
      fsisRequirement: _GrassFedKB.fsisReqGrassFed,
    ));
    agwMatched = true;
  }

  // 3. USDA Process Verified + grass-fed
  final hasPVP =
      text.contains('process verified') || text.contains('usda process verified');
  final hasGrassFed = text.contains('grass fed') || text.contains('grassfed');
  if (hasPVP && hasGrassFed) {
    claims.add(const _GrassFedClaimMatch(
      claimType: _GrassFedClaimType.grassFedPVP,
      credibility: _GrassFedCredibility.usdaProcessVerified,
      confidence: 0.88,
      consumerAlert: _GrassFedKB.alertPVP,
      detailedExplanation: _GrassFedKB.explainPVP,
      fsisRequirement: _GrassFedKB.fsisReqGrassFed,
    ));
  }

  // 4. Partial grass-fed (e.g., "75% grass fed")
  bool partialMatched = false;
  for (final pattern in [
    r'(\d{1,3})\s*%\s*grass\s*fed',
    r'(\d{1,3})\s*percent\s*grass\s*fed',
    r'(\d{1,3})\s*%\s*grassfed',
    r'(\d{1,3})\s*percent\s*grassfed',
  ]) {
    final m = RegExp(pattern).firstMatch(text);
    if (m != null) {
      final pct = int.tryParse(m.group(1) ?? '') ?? 0;
      claims.add(_GrassFedClaimMatch(
        claimType: _GrassFedClaimType.partialGrassFed,
        credibility: _GrassFedCredibility.partialClaim,
        confidence: 0.90,
        consumerAlert: _GrassFedKB.alertPartialGrassFed,
        detailedExplanation: _GrassFedKB.explainPartialClaim,
        fsisRequirement: _GrassFedKB.fsisReqPartial,
        percentage: pct,
      ));
      partialMatched = true;
      break;
    }
  }

  // 5. Grain fed, grass finished
  bool mixedMatched = false;
  for (final p in [
    'grain fed grass finished',
    'grain fed, grass finished',
    'grain finished grass fed',
  ]) {
    if (text.contains(p)) {
      claims.add(const _GrassFedClaimMatch(
        claimType: _GrassFedClaimType.grainFedGrassFinished,
        credibility: _GrassFedCredibility.weakerThanExpected,
        confidence: 0.92,
        consumerAlert: _GrassFedKB.alertGrainFedGrassFinished,
        detailedExplanation: _GrassFedKB.explainGrassFinishedFSIS,
        fsisRequirement: _GrassFedKB.fsisReqGrassFinished,
      ));
      mixedMatched = true;
      break;
    }
  }

  // 6. Grass-finished alone (weaker claim) — only if no mixed/AGA/AGW match.
  final hasGrassFinishedMatch = mixedMatched || agaMatched || agwMatched;
  if (!hasGrassFinishedMatch) {
    for (final p in ['grass finished', 'grassfinished']) {
      if (text.contains(p)) {
        final alsoSaysGrassFed =
            text.contains('grass fed') || text.contains('grassfed');
        if (alsoSaysGrassFed) break;
        claims.add(const _GrassFedClaimMatch(
          claimType: _GrassFedClaimType.grassFinished,
          credibility: _GrassFedCredibility.weakerThanExpected,
          confidence: 0.90,
          consumerAlert: _GrassFedKB.alertGrassFinished,
          detailedExplanation: _GrassFedKB.explainGrassFinishedFSIS,
          fsisRequirement: _GrassFedKB.fsisReqGrassFinished,
        ));
        break;
      }
    }
  }

  // 7. Generic grass-fed / 100% grass-fed (no cert) — only if no higher-spec match.
  final hasGrassFedMatch = agaMatched || agwMatched || hasPVP && hasGrassFed || partialMatched;
  if (!hasGrassFedMatch) {
    bool hundredMatched = false;
    for (final p in [
      '100% grass fed',
      '100% grassfed',
      '100 percent grass fed',
      '100 percent grassfed',
    ]) {
      if (text.contains(p)) {
        claims.add(const _GrassFedClaimMatch(
          claimType: _GrassFedClaimType.grassFed100,
          credibility: _GrassFedCredibility.fsisApproved,
          confidence: 0.88,
          consumerAlert: _GrassFedKB.alertGrassFedNoCert,
          detailedExplanation: _GrassFedKB.explainGrassFedFSIS,
          fsisRequirement: _GrassFedKB.fsisReqGrassFed,
        ));
        hundredMatched = true;
        break;
      }
    }
    if (!hundredMatched) {
      for (final p in ['grass fed', 'grassfed']) {
        if (text.contains(p)) {
          claims.add(const _GrassFedClaimMatch(
            claimType: _GrassFedClaimType.grassFedUnspecified,
            credibility: _GrassFedCredibility.fsisApproved,
            confidence: 0.85,
            consumerAlert: _GrassFedKB.alertGrassFedNoCert,
            detailedExplanation: _GrassFedKB.explainGrassFedFSIS,
            fsisRequirement: _GrassFedKB.fsisReqGrassFed,
          ));
          break;
        }
      }
    }
  }

  return claims;
}

class GrassFedResultCard extends StatelessWidget {
  final List<_GrassFedClaimMatch> _claims;
  const GrassFedResultCard._(this._claims);

  /// Returns a card when grass-fed/grass-finished claims are present, else null.
  static GrassFedResultCard? maybeFrom(FATResult result, String scannedText) {
    final claims = _detectGrassFed(_normalize(scannedText));
    if (claims.isEmpty) return null;
    return GrassFedResultCard._(claims);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CertColors.systemGray6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CertColors.systemGray4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const [
                Icon(Icons.eco, size: 18, color: _CertColors.successGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Grass-Fed Claim Assessment',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _CertColors.fatDarkBlue)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _claims.length; i++) ...[
            if (i != 0) const SizedBox(height: 12),
            _GrassFedClaimCard(claim: _claims[i]),
          ],
        ],
      ),
    );
  }
}

Color _grassFedCredibilityColor(_GrassFedCredibility c) {
  switch (c) {
    case _GrassFedCredibility.thirdPartyAudited:
      return _CertColors.successGreen;
    case _GrassFedCredibility.usdaProcessVerified:
      return _CertColors.fatAmber;
    case _GrassFedCredibility.fsisApproved:
      return _CertColors.fatOrange;
    case _GrassFedCredibility.partialClaim:
    case _GrassFedCredibility.weakerThanExpected:
      return _CertColors.danger;
  }
}

Color _grassFedAlertBg(_GrassFedCredibility c) {
  switch (c) {
    case _GrassFedCredibility.thirdPartyAudited:
      return _CertColors.successGreenSoft;
    case _GrassFedCredibility.usdaProcessVerified:
      return _CertColors.fatAmberTint;
    case _GrassFedCredibility.fsisApproved:
      return _CertColors.fatOrangeTint;
    case _GrassFedCredibility.partialClaim:
    case _GrassFedCredibility.weakerThanExpected:
      return _CertColors.fatRedTint;
  }
}

String _grassFedTitle(_GrassFedClaimMatch claim) {
  switch (claim.claimType) {
    case _GrassFedClaimType.grassFed100:
      return '100% Grass-Fed';
    case _GrassFedClaimType.grassFinished:
      return 'Grass-Finished (Weaker Claim)';
    case _GrassFedClaimType.grainFedGrassFinished:
      return 'Grain Fed, Grass Finished';
    case _GrassFedClaimType.partialGrassFed:
      return claim.percentage != null
          ? '${claim.percentage}% Grass-Fed'
          : 'Partial Grass-Fed';
    case _GrassFedClaimType.grassFedAGA:
      return 'AGA Certified Grass-Fed';
    case _GrassFedClaimType.grassFedAGW:
      return 'Certified Grassfed by AGW';
    case _GrassFedClaimType.grassFedPVP:
      return 'USDA Process Verified Grass-Fed';
    case _GrassFedClaimType.grassFedUnspecified:
      return 'Grass-Fed (No Certification)';
  }
}

IconData _grassFedBadgeIcon(_GrassFedCredibility c) {
  switch (c) {
    case _GrassFedCredibility.thirdPartyAudited:
      return Icons.verified_user;
    case _GrassFedCredibility.usdaProcessVerified:
      return Icons.account_balance;
    case _GrassFedCredibility.fsisApproved:
      return Icons.description;
    case _GrassFedCredibility.partialClaim:
      return Icons.pie_chart;
    case _GrassFedCredibility.weakerThanExpected:
      return Icons.warning_amber_rounded;
  }
}

class _GrassFedClaimCard extends StatefulWidget {
  final _GrassFedClaimMatch claim;
  const _GrassFedClaimCard({required this.claim});

  @override
  State<_GrassFedClaimCard> createState() => _GrassFedClaimCardState();
}

class _GrassFedClaimCardState extends State<_GrassFedClaimCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final accent = _grassFedCredibilityColor(claim.credibility);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CertColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title (+ percentage) and credibility badge.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_grassFedTitle(claim),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _CertColors.fatDarkBlue)),
                    if (claim.percentage != null) ...[
                      const SizedBox(height: 4),
                      Text('${claim.percentage}% of diet from grass/forage',
                          style: const TextStyle(
                              fontSize: 12, color: _CertColors.fatGray)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _credibilityBadge(
                _grassFedBadgeIcon(claim.credibility),
                claim.credibility.displayLabel,
                _grassFedCredibilityColor(claim.credibility),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Consumer alert (always visible).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _grassFedAlertBg(claim.credibility),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(claim.consumerAlert,
                style: const TextStyle(
                    fontSize: 12, color: _CertColors.fatBodyText)),
          ),
          const SizedBox(height: 8),
          _moreDetailButton(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            _detailRow(Icons.account_balance, 'FSIS Requirement',
                claim.fsisRequirement),
            const SizedBox(height: 8),
            _detailRow(
                Icons.description, 'What This Means', claim.detailedExplanation),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.show_chart,
                    size: 10, color: _CertColors.fatLightGray),
                const SizedBox(width: 4),
                Text(
                    'Detection confidence: ${(claim.confidence * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 10, color: _CertColors.fatLightGray)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
                'Source: FAT Research Paper No. 6 — Grass-Fed vs. Grass-Finished',
                style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: _CertColors.fatPaleGray)),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. WELFARE CERTIFICATION
//    (port of CertificationResultView.swift + WelfareCertification.swift)
// ═════════════════════════════════════════════════════════════════════════════

enum _WelfareRating {
  highest,
  high,
  meaningful,
  moderate,
  marginal,
  misleading,
}

Color _welfareTierColor(_WelfareRating r) {
  switch (r) {
    case _WelfareRating.highest:
      return _CertColors.tierHighest;
    case _WelfareRating.high:
      return _CertColors.tierHigh;
    case _WelfareRating.meaningful:
      return _CertColors.tierMeaningful;
    case _WelfareRating.moderate:
      return _CertColors.tierModerate;
    case _WelfareRating.marginal:
      return _CertColors.tierMarginal;
    case _WelfareRating.misleading:
      return _CertColors.tierMisleading;
  }
}

class _WelfareTier {
  final String id;
  final String displayName;
  final String certifyingBody;
  final _WelfareRating rating;
  final bool outdoorAccessRequired;
  final bool cagesProhibited;
  final bool feedlotFinishingAllowed;
  final bool routineAntibioticsProhibited;
  final bool slaughterAudited;
  final bool aspcaEndorsed;
  final List<String> keyFacts;
  final String whatConsumersShouldKnow;

  const _WelfareTier({
    required this.id,
    required this.displayName,
    required this.certifyingBody,
    required this.rating,
    required this.outdoorAccessRequired,
    required this.cagesProhibited,
    required this.feedlotFinishingAllowed,
    required this.routineAntibioticsProhibited,
    required this.slaughterAudited,
    required this.aspcaEndorsed,
    required this.keyFacts,
    required this.whatConsumersShouldKnow,
  });
}

class _UnverifiedClaim {
  final String id;
  final String claimText;
  final List<String> alternateTexts;
  final String whatItActuallyMeans;
  const _UnverifiedClaim({
    required this.id,
    required this.claimText,
    required this.alternateTexts,
    required this.whatItActuallyMeans,
  });
}

/// Verbatim port of WelfareCertKnowledgeBase.allTiers.
const List<_WelfareTier> _welfareTiers = [
  _WelfareTier(
    id: 'awa',
    displayName: 'Animal Welfare Approved',
    certifyingBody: 'A Greener World',
    rating: _WelfareRating.highest,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: true,
    aspcaEndorsed: true,
    keyFacts: [
      'Limited exclusively to independent family farms',
      'Continuous outdoor access on pasture or range required for all species',
      'No cages, crates, or tethers permitted',
      'Annual on-farm audits by independent auditors; ISO 17065 accredited',
      'Covers birth through slaughter including transport',
    ],
    whatConsumersShouldKnow:
        'This is the highest welfare certification available. Animals were raised on a family farm with continuous outdoor access. The certifier is fully independent of industry and has the most rigorous auditing regime of any program.',
  ),
  _WelfareTier(
    id: 'ch_base',
    displayName: 'Certified Humane',
    certifyingBody: 'Humane Farm Animal Care',
    rating: _WelfareRating.moderate,
    outdoorAccessRequired: false,
    cagesProhibited: true,
    feedlotFinishingAllowed: true,
    routineAntibioticsProhibited: true,
    slaughterAudited: true,
    aspcaEndorsed: true,
    keyFacts: [
      'No cages, crates, or tie stalls — a real improvement over industry practice',
      'Outdoor access is NOT required at the base level',
      'Poultry can be raised entirely indoors',
      'Slaughter facilities are audited — one of only two certifiers that do this',
      'Look for additional Free Range or Pasture Raised designation for outdoor access',
    ],
    whatConsumersShouldKnow:
        'The base Certified Humane label eliminates cages and crates, which is meaningful. However, it does not require outdoor access. If outdoor access matters to you, look for the additional Free Range or Pasture Raised designation on the package.',
  ),
  _WelfareTier(
    id: 'ch_freerange',
    displayName: 'Certified Humane Free Range',
    certifyingBody: 'Humane Farm Animal Care',
    rating: _WelfareRating.meaningful,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: true,
    aspcaEndorsed: true,
    keyFacts: [
      'At least 6 hours of outdoor access per day required',
      'Minimum 2 sq ft of outdoor space per bird',
      'No cages, crates, or tie stalls',
      'No routine antibiotics or growth hormones',
      'Slaughter facilities audited',
    ],
    whatConsumersShouldKnow:
        'This certification requires meaningful outdoor access — at least 6 hours daily — in addition to the cage-free and enrichment requirements of the base Certified Humane program. A solid choice for consumers who want verified outdoor access.',
  ),
  _WelfareTier(
    id: 'ch_pasture',
    displayName: 'Certified Humane Pasture Raised',
    certifyingBody: 'Humane Farm Animal Care',
    rating: _WelfareRating.high,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: true,
    aspcaEndorsed: true,
    keyFacts: [
      '108 sq ft of outdoor space per bird — substantially more than Free Range',
      'At least 6 hours of outdoor access per day',
      'Pasture must have living vegetation',
      'No cages, crates, or tie stalls',
      'Slaughter facilities audited',
    ],
    whatConsumersShouldKnow:
        'This is Certified Humane\'s highest tier and provides genuinely high welfare conditions comparable to the best certifications available. Animals have extensive pasture access with real vegetation.',
  ),
  _WelfareTier(
    id: 'gap_step1',
    displayName: 'GAP Step 1: No Cages, No Crates, No Crowding',
    certifyingBody: 'Global Animal Partnership',
    rating: _WelfareRating.marginal,
    outdoorAccessRequired: false,
    cagesProhibited: true,
    feedlotFinishingAllowed: true,
    routineAntibioticsProhibited: true,
    slaughterAudited: false,
    aspcaEndorsed: false,
    keyFacts: [
      'Lowest tier — no outdoor access required',
      'Feedlot finishing permitted for beef cattle',
      'Castration without anesthetic allowed',
      'Early weaning permitted',
      'ASPCA does NOT endorse this tier',
    ],
    whatConsumersShouldKnow:
        'This is GAP\'s lowest tier and the most commonly available at retail, including Whole Foods. It prohibits cages and crates but does not require outdoor access, and conditions may be only marginally better than standard industry practice. The ASPCA excludes Step 1 from its endorsement.',
  ),
  _WelfareTier(
    id: 'gap_step2',
    displayName: 'GAP Step 2: Environmental Enrichment',
    certifyingBody: 'Global Animal Partnership',
    rating: _WelfareRating.moderate,
    outdoorAccessRequired: false,
    cagesProhibited: true,
    feedlotFinishingAllowed: true,
    routineAntibioticsProhibited: true,
    slaughterAudited: false,
    aspcaEndorsed: true,
    keyFacts: [
      'Adds environmental enrichment requirements over Step 1',
      'Still no outdoor access required',
      'Feedlot finishing still permitted for beef',
      'Longer minimum weaning age than Step 1',
      'ASPCA endorses Step 2 and above',
    ],
    whatConsumersShouldKnow:
        'Step 2 adds enrichments like pecking objects for poultry and rooting materials for pigs, which is a real improvement. However, outdoor access is still not required and most animals may be raised in confinement.',
  ),
  _WelfareTier(
    id: 'gap_step3',
    displayName: 'GAP Step 3: Outdoor Access',
    certifyingBody: 'Global Animal Partnership',
    rating: _WelfareRating.meaningful,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: false,
    aspcaEndorsed: true,
    keyFacts: [
      'First GAP tier to require outdoor access',
      'Seasonal outdoor access — birds can be confined until 4 weeks of age',
      'Fast-growing meat birds may never actually go outside during their short lives',
      'No Step 3 standard exists for beef cattle',
      'Genuinely better than industry standard but still has limitations',
    ],
    whatConsumersShouldKnow:
        'Step 3 introduces outdoor access, which is a meaningful improvement. However, for fast-growing poultry breeds with short lifespans, the allowance for indoor confinement until 4 weeks means some birds may never reach the outdoors.',
  ),
  _WelfareTier(
    id: 'gap_step4',
    displayName: 'GAP Step 4: Pasture Centered',
    certifyingBody: 'Global Animal Partnership',
    rating: _WelfareRating.high,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: false,
    aspcaEndorsed: true,
    keyFacts: [
      'Pasture-centered production system required',
      'Animals spend majority of time on pasture',
      'Substantially higher welfare than Steps 1-3',
      'Rare at retail — most GAP products are Step 1 or 2',
      'Comparable to high-tier certifications from other programs',
    ],
    whatConsumersShouldKnow:
        'Step 4 represents genuinely high welfare with pasture-centered production. This is a strong certification — but uncommon at retail. If you see it, it\'s a good choice.',
  ),
  _WelfareTier(
    id: 'gap_step5',
    displayName: 'GAP Step 5/5+: Animal Centered, Entire Life on Same Farm',
    certifyingBody: 'Global Animal Partnership',
    rating: _WelfareRating.highest,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: false,
    aspcaEndorsed: true,
    keyFacts: [
      'Animals spend entire life on a single farm',
      'No physical alterations permitted',
      'Step 5+ adds on-farm slaughter requirement',
      'Highest tier of the GAP program',
      'Extremely rare at retail',
    ],
    whatConsumersShouldKnow:
        'The highest GAP tier, comparable to Animal Welfare Approved. Animals live their entire lives on one farm with no physical alterations. Excellent welfare — but extremely difficult to find in stores.',
  ),
  _WelfareTier(
    id: 'usda_organic',
    displayName: 'USDA Organic',
    certifyingBody: 'USDA National Organic Program',
    rating: _WelfareRating.meaningful,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: true,
    aspcaEndorsed: true,
    keyFacts: [
      'Government-regulated with federal enforcement authority',
      '2023 OLPS rule substantially upgraded animal welfare requirements',
      'Outdoor access required; porches no longer count as outdoor space',
      'Gestation and farrowing crates for pigs now prohibited',
      'Full poultry stocking density requirements not in effect until January 2029',
    ],
    whatConsumersShouldKnow:
        'USDA Organic is being significantly upgraded under the 2023 Organic Livestock and Poultry Standards rule. By 2029, it will require meaningful outdoor access for all species. Until then, some poultry provisions are still phasing in — consumers may want to combine with an additional welfare certification for poultry products.',
  ),
  _WelfareTier(
    id: 'ahc',
    displayName: 'American Humane Certified',
    certifyingBody: 'American Humane Association',
    rating: _WelfareRating.marginal,
    outdoorAccessRequired: false,
    cagesProhibited: false,
    feedlotFinishingAllowed: true,
    routineAntibioticsProhibited: false,
    slaughterAudited: true,
    aspcaEndorsed: false,
    keyFacts: [
      'Space requirements only slightly above industry standard — less than 1 sq ft per bird',
      'Outdoor access NOT required for any species',
      'Some types of cages permitted for laying hens',
      'Farrowing crates for pigs are permitted',
      'Farms can pass with only 85% of criteria met',
    ],
    whatConsumersShouldKnow:
        'Despite its name, American Humane Certified has the weakest standards of any major third-party certification. Space allowances barely exceed industry norms, outdoor access is not required, and some cages are permitted. Consumer Reports, the ASPCA, and multiple welfare organizations have rated these standards as inadequate.',
  ),
  _WelfareTier(
    id: 'aga',
    displayName: 'American Grassfed Certified',
    certifyingBody: 'American Grassfed Association',
    rating: _WelfareRating.meaningful,
    outdoorAccessRequired: true,
    cagesProhibited: true,
    feedlotFinishingAllowed: false,
    routineAntibioticsProhibited: true,
    slaughterAudited: false,
    aspcaEndorsed: true,
    keyFacts: [
      '100% grass and forage diet — no grain finishing',
      'Continuous access to pasture; no feedlot confinement',
      'No antibiotics or growth hormones',
      'Limited to ruminants: beef, dairy, sheep, goats, bison',
      'Does not cover transport, slaughter, or physical alterations',
    ],
    whatConsumersShouldKnow:
        'A credible certification for grass-fed claims with continuous pasture access and no feedlots. Its welfare scope is narrower than AWA — it does not cover transport, slaughter, or painful procedures — but for the specific claims it makes, it is reliable.',
  ),
];

/// Verbatim port of WelfareCertKnowledgeBase.unverifiedClaims.
const List<_UnverifiedClaim> _unverifiedClaims = [
  _UnverifiedClaim(
    id: 'natural',
    claimText: 'Natural',
    alternateTexts: ['All Natural', '100% Natural'],
    whatItActuallyMeans:
        'USDA defines this as no artificial ingredients and minimally processed. All fresh meat qualifies. It says nothing about how the animal was raised, what it was fed, or whether it received antibiotics.',
  ),
  _UnverifiedClaim(
    id: 'humanely_raised',
    claimText: 'Humanely Raised',
    alternateTexts: ['Humanely Raised & Handled', 'Raised with Care'],
    whatItActuallyMeans:
        'USDA does not define this term. Without an accompanying third-party certification seal, it is essentially meaningless and self-reported by the producer.',
  ),
  _UnverifiedClaim(
    id: 'cage_free',
    claimText: 'Cage-Free',
    alternateTexts: ['Cage Free'],
    whatItActuallyMeans:
        'Means only that birds were not kept in battery cages. Birds may be crowded indoors in sheds with no outdoor access and minimal space to move. Does not address any other welfare concern.',
  ),
  _UnverifiedClaim(
    id: 'free_range',
    claimText: 'Free-Range',
    alternateTexts: ['Free Range', 'Free Roaming'],
    whatItActuallyMeans:
        'USDA defines this only for poultry: birds must have been allowed access to the outside. No requirement for size, quality, or duration of outdoor access, and no verification that birds actually went outside.',
  ),
  _UnverifiedClaim(
    id: 'no_hormones_poultry',
    claimText: 'No Hormones Added',
    alternateTexts: [
      'Hormone Free',
      'No Added Hormones',
      'Raised Without Hormones'
    ],
    whatItActuallyMeans:
        'Federal regulations already prohibit hormones in all poultry and pork production. This claim is technically true for every chicken and pork product sold in the U.S. — it implies a distinction that does not exist.',
  ),
  _UnverifiedClaim(
    id: 'pasture_raised_unverified',
    claimText: 'Pasture Raised',
    alternateTexts: ['Pasture-Raised', 'Pastured'],
    whatItActuallyMeans:
        'Pasture raised is not regulated by USDA. Without an accompanying third-party certification (like Certified Humane Pasture Raised), this claim is unverified and may mean very little.',
  ),
];

/// A matched welfare tier; partialMatch mirrors the iOS "step number not
/// readable" case (a GAP program detected without a readable step number).
class _CertificationMatch {
  final _WelfareTier tier;
  final bool partialMatch;
  const _CertificationMatch(this.tier, {this.partialMatch = false});
}

/// Derive welfare-tier matches + unverified-claim matches from the OCR text.
/// Detection mirrors LabelInterpreter._detectAnimalWelfare semantics, expanded
/// to map onto the specific tiers/claims the iOS view renders.
({List<_CertificationMatch> certs, List<_UnverifiedClaim> unverified})
    _detectWelfare(String text) {
  final certs = <_CertificationMatch>[];

  _WelfareTier tier(String id) => _welfareTiers.firstWhere((t) => t.id == id);

  // Animal Welfare Approved.
  if (text.contains('animal welfare approved') || text.contains('awa certified')) {
    certs.add(_CertificationMatch(tier('awa')));
  }

  // Certified Humane (+ tier).
  if (text.contains('certified humane')) {
    if (text.contains('pasture raised')) {
      certs.add(_CertificationMatch(tier('ch_pasture')));
    } else if (text.contains('free range')) {
      certs.add(_CertificationMatch(tier('ch_freerange')));
    } else {
      certs.add(_CertificationMatch(tier('ch_base')));
    }
  }

  // Global Animal Partnership (+ step number, with partial-match fallback).
  if (text.contains('global animal partnership') ||
      RegExp(r'\bgap\b').hasMatch(text)) {
    if (text.contains('step 5') || text.contains('step5')) {
      certs.add(_CertificationMatch(tier('gap_step5')));
    } else if (text.contains('step 4') || text.contains('step4')) {
      certs.add(_CertificationMatch(tier('gap_step4')));
    } else if (text.contains('step 3') || text.contains('step3')) {
      certs.add(_CertificationMatch(tier('gap_step3')));
    } else if (text.contains('step 2') || text.contains('step2')) {
      certs.add(_CertificationMatch(tier('gap_step2')));
    } else if (text.contains('step 1') || text.contains('step1')) {
      certs.add(_CertificationMatch(tier('gap_step1')));
    } else if (text.contains('global animal partnership')) {
      // Program detected, step number not readable.
      certs.add(_CertificationMatch(tier('gap_step1'), partialMatch: true));
    }
  }

  // USDA Organic.
  if (text.contains('usda organic') || text.contains('certified organic')) {
    certs.add(_CertificationMatch(tier('usda_organic')));
  }

  // American Humane Certified (distinct from American Grassfed).
  if (text.contains('american humane')) {
    certs.add(_CertificationMatch(tier('ahc')));
  }

  // American Grassfed Association.
  if (text.contains('american grassfed') ||
      text.contains('american grass fed') ||
      text.contains('aga certified')) {
    certs.add(_CertificationMatch(tier('aga')));
  }

  // Unverified marketing claims — only surface when NOT already covered by a
  // certification on the same label (e.g., don't flag bare "pasture raised" /
  // "free range" if Certified Humane / AWA is present).
  final hasWelfareCert = certs.isNotEmpty;
  final unverified = <_UnverifiedClaim>[];
  for (final claim in _unverifiedClaims) {
    final needles = <String>[
      claim.claimText.toLowerCase().replaceAll('-', ' '),
      ...claim.alternateTexts.map((t) => t.toLowerCase().replaceAll('-', ' ')),
    ];
    final present = needles.any(text.contains);
    if (!present) continue;
    // Suppress pasture/free-range/humanely-raised when a real cert is present.
    if (hasWelfareCert &&
        (claim.id == 'pasture_raised_unverified' ||
            claim.id == 'free_range' ||
            claim.id == 'humanely_raised' ||
            claim.id == 'cage_free')) {
      continue;
    }
    unverified.add(claim);
  }

  return (certs: certs, unverified: unverified);
}

class CertificationResultCard extends StatefulWidget {
  final List<_CertificationMatch> _certs;
  final List<_UnverifiedClaim> _unverified;
  const CertificationResultCard._({
    required List<_CertificationMatch> certs,
    required List<_UnverifiedClaim> unverified,
  })  : _certs = certs,
        _unverified = unverified;

  /// Returns a card when welfare certifications or unverified welfare claims are
  /// present, else null.
  static CertificationResultCard? maybeFrom(
      FATResult result, String scannedText) {
    final res = _detectWelfare(_normalize(scannedText));
    if (res.certs.isEmpty && res.unverified.isEmpty) return null;
    return CertificationResultCard._(
        certs: res.certs, unverified: res.unverified);
  }

  @override
  State<CertificationResultCard> createState() =>
      _CertificationResultCardState();
}

class _CertificationResultCardState extends State<CertificationResultCard> {
  String? _expandedCertId;
  String? _expandedClaimId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CertColors.certPaleBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const [
                Icon(Icons.verified_outlined, size: 24, color: _CertColors.certBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Welfare Claims Detected',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _CertColors.certBlue)),
                ),
              ],
            ),
          ),
          for (final m in widget._certs) ...[
            const SizedBox(height: 12),
            _CertificationCard(
              match: m,
              isExpanded: _expandedCertId == m.tier.id,
              onTap: () => setState(() => _expandedCertId =
                  _expandedCertId == m.tier.id ? null : m.tier.id),
            ),
          ],
          for (final c in widget._unverified) ...[
            const SizedBox(height: 12),
            _UnverifiedClaimCard(
              claim: c,
              isExpanded: _expandedClaimId == c.id,
              onTap: () => setState(() =>
                  _expandedClaimId = _expandedClaimId == c.id ? null : c.id),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.menu_book, size: 13, color: _CertColors.certLightBlue),
              SizedBox(width: 6),
              Expanded(
                child: Text('Full analysis at farmanimaltransparency.com',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _CertColors.certLightBlue)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CertRatingBadge extends StatelessWidget {
  final _WelfareRating rating;
  const _CertRatingBadge(this.rating);

  @override
  Widget build(BuildContext context) {
    final color = _welfareTierColor(rating);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _CertFactRow extends StatelessWidget {
  final String label;
  final String value;
  final bool positive;
  const _CertFactRow(
      {required this.label, required this.value, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(positive ? Icons.check_circle : Icons.cancel,
            size: 13, color: positive ? _CertColors.green : _CertColors.danger),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _CertColors.secondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _CertColors.fatDarkBlue)),
        ),
      ],
    );
  }
}

class _CertificationCard extends StatelessWidget {
  final _CertificationMatch match;
  final bool isExpanded;
  final VoidCallback onTap;
  const _CertificationCard(
      {required this.match, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tier = match.tier;
    return Container(
      decoration: BoxDecoration(
        color: _CertColors.systemGray6,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CertRatingBadge(tier.rating),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tier.displayName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _CertColors.fatDarkBlue)),
                        const SizedBox(height: 2),
                        Text(tier.certifyingBody,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _CertColors.secondary)),
                        if (match.partialMatch) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: const [
                              Icon(Icons.visibility,
                                  size: 14, color: Colors.orange),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                    'Step number not readable — verify on package',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: _CertColors.secondary),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(tier.whatConsumersShouldKnow,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _CertColors.fatDarkBlue)),
                  const SizedBox(height: 10),
                  _CertFactRow(
                      label: 'Outdoor access',
                      value: tier.outdoorAccessRequired
                          ? 'Required'
                          : 'Not required',
                      positive: tier.outdoorAccessRequired),
                  const SizedBox(height: 6),
                  _CertFactRow(
                      label: 'Cages/crates',
                      value: tier.cagesProhibited ? 'Prohibited' : 'Permitted',
                      positive: tier.cagesProhibited),
                  const SizedBox(height: 6),
                  _CertFactRow(
                      label: 'Feedlot finishing',
                      value:
                          tier.feedlotFinishingAllowed ? 'Allowed' : 'Prohibited',
                      positive: !tier.feedlotFinishingAllowed),
                  const SizedBox(height: 6),
                  _CertFactRow(
                      label: 'Routine antibiotics',
                      value: tier.routineAntibioticsProhibited
                          ? 'Prohibited'
                          : 'Allowed',
                      positive: tier.routineAntibioticsProhibited),
                  const SizedBox(height: 6),
                  _CertFactRow(
                      label: 'Slaughter audited',
                      value: tier.slaughterAudited ? 'Yes' : 'No',
                      positive: tier.slaughterAudited),
                  const SizedBox(height: 6),
                  _CertFactRow(
                      label: 'ASPCA endorsed',
                      value: tier.aspcaEndorsed ? 'Yes' : 'No',
                      positive: tier.aspcaEndorsed),
                  if (tier.keyFacts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Key Facts',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _CertColors.certBlue)),
                    const SizedBox(height: 4),
                    for (final fact in tier.keyFacts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _CertColors.certLightBlue)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(fact,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _CertColors.fatDarkBlue)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UnverifiedClaimCard extends StatelessWidget {
  final _UnverifiedClaim claim;
  final bool isExpanded;
  final VoidCallback onTap;
  const _UnverifiedClaimCard(
      {required this.claim, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CertColors.systemGray6,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CertColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CertRatingBadge(_WelfareRating.misleading),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"${claim.claimText}"',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _CertColors.fatDarkBlue)),
                        const SizedBox(height: 2),
                        const Text('Unverified marketing claim',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _CertColors.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: _CertColors.secondary),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(claim.whatItActuallyMeans,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _CertColors.fatDarkBlue)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. PASTURE  (port of PastureResultView.swift + PastureCertification.swift)
// ═════════════════════════════════════════════════════════════════════════════

enum _PastureClaimType {
  certifiedHumanePastureRaised,
  awaPastureRaised,
  gapStep5Plus,
  gapStep4,
  agaPastureRuminant,
  usdaOrganicNOPRuminant,
  usdaPVPPasture,
  fsisFreeRange,
  fsisPastureRaisedAffidavit,
  humanelyRaisedUnverified,
  pastureMarketingOnly,
}

enum _PastureCredibility {
  thirdPartyAudited,
  usdaOrganicNOP,
  usdaProcessVerified,
  fsisAffidavitOnly,
  marketingClaimOnly,
}

extension _PastureCredibilityLabel on _PastureCredibility {
  String get displayLabel {
    switch (this) {
      case _PastureCredibility.thirdPartyAudited:
        return 'Third-Party Audited';
      case _PastureCredibility.usdaOrganicNOP:
        return 'USDA Organic (NOP Pasture Rule)';
      case _PastureCredibility.usdaProcessVerified:
        return 'USDA Process Verified';
      case _PastureCredibility.fsisAffidavitOnly:
        return 'FSIS Label Approved (Affidavit Only)';
      case _PastureCredibility.marketingClaimOnly:
        return 'Marketing Claim Only';
    }
  }
}

enum _PastureApplicability {
  ruminantGrazing,
  porkOutdoorRooting,
  poultryRotatedPasture,
  notApplicable,
}

extension _PastureApplicabilityNote on _PastureApplicability {
  String get speciesNote {
    switch (this) {
      case _PastureApplicability.ruminantGrazing:
        return 'For beef, bison, lamb, and goat, FAT looks for lifetime '
            'pasture or rangeland access with managed grazing and '
            'pasture- or range-finishing — not feedlot finishing.';
      case _PastureApplicability.porkOutdoorRooting:
        return 'For pork, pasture-raised should mean outdoor paddock or '
            'pasture access with rooting, wallowing, and shade — and '
            'explicitly excludes "indoor confinement with a small '
            'concrete yard."';
      case _PastureApplicability.poultryRotatedPasture:
        return 'For poultry, pasture-raised should mean year-round outdoor '
            'access on managed vegetated land at densities that maintain '
            'ground cover — and explicitly rejects "a pop-door to a worn '
            'dirt run." "Free range" under FSIS only requires some '
            'outdoor access — a much weaker standard.';
      case _PastureApplicability.notApplicable:
        return '';
    }
  }
}

_PastureApplicability _pastureApplicabilityForSpecies(String? species) {
  switch (species?.toLowerCase()) {
    case 'beef':
    case 'lamb':
    case 'bison':
    case 'goat':
    case 'mutton':
      return _PastureApplicability.ruminantGrazing;
    case 'pork':
      return _PastureApplicability.porkOutdoorRooting;
    case 'chicken':
    case 'turkey':
      return _PastureApplicability.poultryRotatedPasture;
    case null:
      return _PastureApplicability.ruminantGrazing;
    default:
      return _PastureApplicability.ruminantGrazing;
  }
}

class _PastureClaimMatch {
  final _PastureClaimType claimType;
  final _PastureCredibility credibility;
  final String consumerAlert;
  final String detailedExplanation;
  final String verificationRequirement;
  const _PastureClaimMatch({
    required this.claimType,
    required this.credibility,
    required this.consumerAlert,
    required this.detailedExplanation,
    required this.verificationRequirement,
  });
}

/// Verbatim port of PastureKnowledgeBase.
class _PastureKB {
  _PastureKB._();

  static const alertCertifiedHumanePR =
      'Certified Humane "Pasture Raised" requires 108 sq ft per bird (poultry) '
      'and continuous outdoor pasture access during the growing season. Independently audited.';

  static const alertAWA =
      'Animal Welfare Approved by AGW: pasture-based, outdoor production by default. '
      'Independently audited; one of the strictest welfare and outdoor-access standards available.';

  static const alertGAP5 =
      'Global Animal Partnership Step 5 / 5+: animal-centered, pasture-based whole-life '
      'production with third-party audits. Step 5+ requires the animal to spend its entire '
      'life on the same farm. Continuous pasture except in extreme weather.';

  static const alertGAP4 =
      'Global Animal Partnership Step 4: pasture-centered with daily outdoor access. '
      'A meaningful pasture standard but weaker than Step 5 / 5+ (which require continuous '
      'pasture access except in extreme weather).';

  static const alertAGAPasture =
      'American Grassfed Association: cattle, sheep, goats, and bison must have lifetime '
      'pasture access with a 100% forage diet, no confinement, and no antibiotics or '
      'added hormones. Independently audited. (AGA is also a grass-fed certifier — see '
      'the Grass-Fed Assessment for the feed-side detail.)';

  static const alertOrganicNOP =
      'USDA Organic (NOP) ruminant pasture rule: cattle, sheep, and goats must obtain at '
      'least 30% of their dry-matter intake from pasture during a grazing season of at '
      'least 120 days per year. This is a statutory federal floor — meaningful for ruminants, '
      'but for pigs and poultry the NOP only requires general outdoor access, not pasture-'
      'specific access.';

  static const alertPVPPasture =
      'USDA Process Verified: the producer defined their own "pasture" standard and '
      'USDA audits compliance with that self-defined standard. Two PVP operations may '
      'have very different outdoor conditions.';

  static const alertFSISFreeRange =
      'FSIS defines "free range" as having access to the outdoors — but does not '
      'specify pasture, duration, or outdoor conditions. A barn with a small door to '
      'a concrete pad can qualify. Without third-party certification, the claim is unverified.';

  static const alertPastureMarketingOnly =
      'This label uses "pasture raised" without a third-party certification mark. '
      'There is no FSIS regulatory definition of the term, and no audit or monitoring '
      'documentation has been surfaced.';

  static const alertHumanelyRaisedUnverified =
      'There is no FSIS regulatory definition of "humanely raised." Without third-party '
      'certification (e.g., Certified Humane, Animal Welfare Approved, GAP), the claim is unverified.';

  static const explainNoFSISPastureDefinition =
      'FSIS does not define "pasture raised" in regulation. FSIS reviews the claim '
      'as a voluntary marketing claim under FSIS-GD-2024-0006 and strongly encourages '
      'third-party certification. "Free range," by contrast, is loosely defined for '
      'poultry as outdoor access only — with no minimum time, density, or outdoor-condition '
      'requirement.';

  static const explainCertifiedHumanePR =
      'Certified Humane "Pasture Raised" sits at the top of the Humane Farm Animal Care '
      'tier (above "Free Range" and "Certified Humane"). For poultry it requires 108 sq '
      'ft per bird, daily outdoor rotation, and pasture cover. For pigs, ruminants, and '
      'other species there are species-specific outdoor-access and density requirements.';

  static const explainAWA =
      'Animal Welfare Approved by A Greener World certifies independent family farms '
      'raising animals outdoors on pasture or range. AWA does not allow feedlot, cage, '
      'or crate confinement. Required as a prerequisite for AGW "Certified Grassfed" '
      'and "Certified Regenerative."';

  static const explainGAP5 =
      'Global Animal Partnership uses a five-step rating. Step 4 is pasture-centered with '
      'daily outdoor access. Step 5 requires animal-centered, pasture-based production for '
      'the animal\'s entire life on a single farm; Step 5+ additionally requires no transfer '
      'between farms. Independently audited.';

  static const explainAGAPasture =
      'AGA\'s standard requires lifetime pasture access for cattle, sheep, goats, and bison '
      'with a 100% forage diet (no grain, no grain by-products), no confinement, and no '
      'antibiotics or hormones. Independent third-party audit. AGA is the most common '
      'third-party certifier that ties pasture access and grass-fed feeding into a single '
      'standard.';

  static const explainOrganicNOP =
      'Under the USDA National Organic Program, ruminants must obtain ≥30% of their '
      'dry-matter intake from pasture during a grazing season of at least 120 days per '
      'year (7 CFR §205.237, §205.240). This is a statutory federal floor — the only '
      'binding pasture rule in U.S. labeling law. For pigs and poultry, the NOP requires '
      'general outdoor access but does not specify pasture, density, or rotation.';

  static const verifyThirdParty =
      'Third-party certifier audit records (Certified Humane Pasture Raised, Animal Welfare '
      'Approved, GAP Step 5/5+) plus on-farm density, outdoor-time, and pasture-rotation records.';

  static const verifyPVP =
      'USDA Process Verified Program documentation showing the producer\'s self-defined '
      'pasture / outdoor-access standard and the audit scope.';

  static const verifyAffidavit =
      'FSIS label-approval record. No independent on-farm audit required.';

  static const verifyOrganicNOP =
      'USDA Organic certification by an accredited certifying agent, with the producer\'s '
      'Organic System Plan documenting pasture management. Annual on-site inspection. '
      'Note: the NOP pasture rule applies to ruminants only.';
}

/// Port of PastureDetector.detect(in:detectedSpecies:).
({List<_PastureClaimMatch> claims, _PastureApplicability applicability})
    _detectPasture(String text, String? detectedSpecies) {
  final applicability = _pastureApplicabilityForSpecies(detectedSpecies);
  final claims = <_PastureClaimMatch>[];

  // 1. Certified Humane Pasture Raised.
  if (text.contains('certified humane') && text.contains('pasture raised')) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.certifiedHumanePastureRaised,
      credibility: _PastureCredibility.thirdPartyAudited,
      consumerAlert: _PastureKB.alertCertifiedHumanePR,
      detailedExplanation: _PastureKB.explainCertifiedHumanePR,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  }

  // 2. Animal Welfare Approved (AGW).
  if (text.contains('animal welfare approved') ||
      text.contains('awa certified') ||
      (text.contains('a greener world') &&
          !text.contains('regenerative') &&
          !text.contains('grassfed'))) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.awaPastureRaised,
      credibility: _PastureCredibility.thirdPartyAudited,
      consumerAlert: _PastureKB.alertAWA,
      detailedExplanation: _PastureKB.explainAWA,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  }

  // 3. GAP Step 5 / 5+ else Step 4.
  if (text.contains('global animal partnership') &&
      (text.contains('step 5') || text.contains('step5'))) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.gapStep5Plus,
      credibility: _PastureCredibility.thirdPartyAudited,
      consumerAlert: _PastureKB.alertGAP5,
      detailedExplanation: _PastureKB.explainGAP5,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  } else if (text.contains('global animal partnership') &&
      (text.contains('step 4') || text.contains('step4'))) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.gapStep4,
      credibility: _PastureCredibility.thirdPartyAudited,
      consumerAlert: _PastureKB.alertGAP4,
      detailedExplanation: _PastureKB.explainGAP5,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  }

  final isRuminant = applicability == _PastureApplicability.ruminantGrazing;

  // 4. American Grassfed Association — ruminants only.
  if (isRuminant &&
      (text.contains('american grassfed') ||
          text.contains('aga certified') ||
          text.contains('aga grassfed'))) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.agaPastureRuminant,
      credibility: _PastureCredibility.thirdPartyAudited,
      consumerAlert: _PastureKB.alertAGAPasture,
      detailedExplanation: _PastureKB.explainAGAPasture,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  }

  // 5. USDA Organic NOP — ruminants only.
  if (isRuminant && text.contains('usda organic')) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.usdaOrganicNOPRuminant,
      credibility: _PastureCredibility.usdaOrganicNOP,
      consumerAlert: _PastureKB.alertOrganicNOP,
      detailedExplanation: _PastureKB.explainOrganicNOP,
      verificationRequirement: _PastureKB.verifyOrganicNOP,
    ));
  }

  // 6. USDA Process Verified + pasture / free range.
  final mentionsPVP = text.contains('process verified') ||
      text.contains('usda pvp') ||
      text.contains(' pvp ');
  if (mentionsPVP &&
      (text.contains('pasture') || text.contains('free range'))) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.usdaPVPPasture,
      credibility: _PastureCredibility.usdaProcessVerified,
      consumerAlert: _PastureKB.alertPVPPasture,
      detailedExplanation: _PastureKB.explainNoFSISPastureDefinition,
      verificationRequirement: _PastureKB.verifyPVP,
    ));
  }

  bool hasStrongerPastureClaim() => claims.any((c) =>
      c.credibility == _PastureCredibility.thirdPartyAudited ||
      c.credibility == _PastureCredibility.usdaOrganicNOP ||
      c.credibility == _PastureCredibility.usdaProcessVerified);

  // 7. Bare "pasture raised".
  if (!hasStrongerPastureClaim() && text.contains('pasture raised')) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.pastureMarketingOnly,
      credibility: _PastureCredibility.marketingClaimOnly,
      consumerAlert: _PastureKB.alertPastureMarketingOnly,
      detailedExplanation: _PastureKB.explainNoFSISPastureDefinition,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  }

  // 8. Free range.
  if (!hasStrongerPastureClaim() && text.contains('free range')) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.fsisFreeRange,
      credibility: _PastureCredibility.fsisAffidavitOnly,
      consumerAlert: _PastureKB.alertFSISFreeRange,
      detailedExplanation: _PastureKB.explainNoFSISPastureDefinition,
      verificationRequirement: _PastureKB.verifyAffidavit,
    ));
  }

  // 9. Humanely raised (unverified) — only if no third-party / PVP cert.
  final hasAnyCert = claims.any((c) =>
      c.credibility == _PastureCredibility.thirdPartyAudited ||
      c.credibility == _PastureCredibility.usdaProcessVerified);
  if (!hasAnyCert && text.contains('humanely raised')) {
    claims.add(const _PastureClaimMatch(
      claimType: _PastureClaimType.humanelyRaisedUnverified,
      credibility: _PastureCredibility.marketingClaimOnly,
      consumerAlert: _PastureKB.alertHumanelyRaisedUnverified,
      detailedExplanation: _PastureKB.explainNoFSISPastureDefinition,
      verificationRequirement: _PastureKB.verifyThirdParty,
    ));
  }

  return (claims: claims, applicability: applicability);
}

Color _pastureCredibilityColor(_PastureCredibility c) {
  switch (c) {
    case _PastureCredibility.thirdPartyAudited:
    case _PastureCredibility.usdaOrganicNOP:
      return _CertColors.successGreen;
    case _PastureCredibility.usdaProcessVerified:
      return _CertColors.fatAmber;
    case _PastureCredibility.fsisAffidavitOnly:
      return _CertColors.fatOrange;
    case _PastureCredibility.marketingClaimOnly:
      return _CertColors.danger;
  }
}

Color _pastureAlertBg(_PastureCredibility c) {
  switch (c) {
    case _PastureCredibility.thirdPartyAudited:
    case _PastureCredibility.usdaOrganicNOP:
      return _CertColors.successGreenSoft;
    case _PastureCredibility.usdaProcessVerified:
      return _CertColors.fatAmberTint;
    case _PastureCredibility.fsisAffidavitOnly:
      return _CertColors.fatOrangeTint;
    case _PastureCredibility.marketingClaimOnly:
      return _CertColors.fatRedTint;
  }
}

IconData _pastureBadgeIcon(_PastureCredibility c) {
  switch (c) {
    case _PastureCredibility.thirdPartyAudited:
      return Icons.verified_user;
    case _PastureCredibility.usdaOrganicNOP:
      return Icons.eco;
    case _PastureCredibility.usdaProcessVerified:
      return Icons.account_balance;
    case _PastureCredibility.fsisAffidavitOnly:
      return Icons.description;
    case _PastureCredibility.marketingClaimOnly:
      return Icons.warning_amber_rounded;
  }
}

String _pastureTitle(_PastureClaimType t) {
  switch (t) {
    case _PastureClaimType.certifiedHumanePastureRaised:
      return 'Certified Humane — Pasture Raised';
    case _PastureClaimType.awaPastureRaised:
      return 'Animal Welfare Approved (AGW)';
    case _PastureClaimType.gapStep5Plus:
      return 'Global Animal Partnership Step 5 / 5+';
    case _PastureClaimType.gapStep4:
      return 'Global Animal Partnership Step 4';
    case _PastureClaimType.agaPastureRuminant:
      return 'American Grassfed Association';
    case _PastureClaimType.usdaOrganicNOPRuminant:
      return 'USDA Organic — NOP Pasture Rule';
    case _PastureClaimType.usdaPVPPasture:
      return 'USDA Process Verified — Pasture / Outdoor Access';
    case _PastureClaimType.fsisFreeRange:
      return 'Free Range (FSIS Affidavit)';
    case _PastureClaimType.fsisPastureRaisedAffidavit:
      return 'Pasture Raised (FSIS Affidavit)';
    case _PastureClaimType.humanelyRaisedUnverified:
      return 'Humanely Raised (Unverified)';
    case _PastureClaimType.pastureMarketingOnly:
      return 'Pasture Raised (No Certification)';
  }
}

class PastureResultCard extends StatelessWidget {
  final List<_PastureClaimMatch> _claims;
  final _PastureApplicability _applicability;
  const PastureResultCard._(this._claims, this._applicability);

  /// Returns a card when pasture / outdoor-access claims are present, else null.
  static PastureResultCard? maybeFrom(FATResult result, String scannedText) {
    final res = _detectPasture(_normalize(scannedText), _detectedSpecies(result));
    if (res.claims.isEmpty) return null;
    return PastureResultCard._(res.claims, res.applicability);
  }

  @override
  Widget build(BuildContext context) {
    final note = _applicability.speciesNote;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CertColors.systemGray6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CertColors.systemGray4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const [
                Icon(Icons.park, size: 18, color: _CertColors.successGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Pasture / Outdoor-Access Assessment',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _CertColors.fatDarkBlue)),
                ),
              ],
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SpeciesFramingNote(text: note),
          ],
          for (var i = 0; i < _claims.length; i++) ...[
            const SizedBox(height: 12),
            _PastureClaimCard(claim: _claims[i]),
          ],
        ],
      ),
    );
  }
}

class _SpeciesFramingNote extends StatelessWidget {
  final String text;
  const _SpeciesFramingNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _CertColors.systemBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info, size: 14, color: _CertColors.fatBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: _CertColors.fatBodyText)),
          ),
        ],
      ),
    );
  }
}

class _PastureClaimCard extends StatefulWidget {
  final _PastureClaimMatch claim;
  const _PastureClaimCard({required this.claim});

  @override
  State<_PastureClaimCard> createState() => _PastureClaimCardState();
}

class _PastureClaimCardState extends State<_PastureClaimCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final accent = _pastureCredibilityColor(claim.credibility);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CertColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(_pastureTitle(claim.claimType),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _CertColors.fatDarkBlue)),
              ),
              const SizedBox(width: 8),
              _credibilityBadge(
                _pastureBadgeIcon(claim.credibility),
                claim.credibility.displayLabel,
                _pastureCredibilityColor(claim.credibility),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _pastureAlertBg(claim.credibility),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(claim.consumerAlert,
                style: const TextStyle(
                    fontSize: 12, color: _CertColors.fatBodyText)),
          ),
          const SizedBox(height: 8),
          _moreDetailButton(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            _detailRow(Icons.description, 'What This Means',
                claim.detailedExplanation),
            const SizedBox(height: 8),
            _detailRow(Icons.verified, 'Verification Required',
                claim.verificationRequirement),
            const SizedBox(height: 8),
            const Text(
                'Source: FSIS-GD-2024-0006 + FAT animal-welfare research',
                style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: _CertColors.fatPaleGray)),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. REGENERATIVE
//    (port of RegenerativeResultView.swift + RegenerativeCertification.swift)
// ═════════════════════════════════════════════════════════════════════════════

enum _RegenClaimType {
  regenerativeOrganicCertified,
  landToMarketEOV,
  regenified,
  agwCertifiedRegenerative,
  usdaPVPRegenerative,
  fsisRaisedUsingRegen,
  regenerativeUnspecified,
}

enum _RegenCredibility {
  thirdPartyAudited,
  usdaProcessVerified,
  fsisAffidavitOnly,
  marketingClaimOnly,
}

extension _RegenCredibilityLabel on _RegenCredibility {
  String get displayLabel {
    switch (this) {
      case _RegenCredibility.thirdPartyAudited:
        return 'Third-Party Audited';
      case _RegenCredibility.usdaProcessVerified:
        return 'USDA Process Verified';
      case _RegenCredibility.fsisAffidavitOnly:
        return 'FSIS Label Approved (Affidavit Only)';
      case _RegenCredibility.marketingClaimOnly:
        return 'Marketing Claim Only';
    }
  }
}

class _RegenClaimMatch {
  final _RegenClaimType claimType;
  final _RegenCredibility credibility;
  final String consumerAlert;
  final String detailedExplanation;
  final String verificationRequirement;
  const _RegenClaimMatch({
    required this.claimType,
    required this.credibility,
    required this.consumerAlert,
    required this.detailedExplanation,
    required this.verificationRequirement,
  });
}

/// Verbatim port of RegenerativeKnowledgeBase.
class _RegenKB {
  _RegenKB._();

  static const alertROC =
      'Regenerative Organic Certified: USDA Organic is the prerequisite, plus '
      'third-party audited soil-health, animal-welfare, and social-fairness standards.';

  static const alertLandToMarket =
      'Land to Market (Ecological Outcome Verification, Savory Institute): on-farm '
      'monitoring of soil, water, and biodiversity outcomes, audited by an '
      'independent third party.';

  static const alertRegenified =
      'Regenified: tier-rated certification (1- to 5-star) based on field '
      'monitoring of the six soil-health principles and ecological outcomes.';

  static const alertAGWRegen =
      'Certified Regenerative by A Greener World: outcome-based, whole-farm '
      'certification covering soil, water, biodiversity, animal welfare, and social impact.';

  static const alertPVPRegen =
      'USDA Process Verified: the producer defined their own "regenerative" '
      'standard and USDA audits compliance with that self-defined standard. '
      'No uniform baseline — two PVP operations may have very different practices.';

  static const alertFSISAffidavit =
      '"Raised using Regenerative Agriculture Practices" was approved by FSIS '
      'based on a producer affidavit. There is no FSIS regulatory definition of '
      'regenerative and no independent audit is required.';

  static const alertMarketingOnly =
      'This label uses the word "regenerative" without a certification mark. '
      'There is no FSIS, USDA, or scientific standard for the term — and no '
      'audit or monitoring documentation has been surfaced.';

  static const alertGrassFedMisuseOnNonRuminant =
      '"Grass-fed" is not an appropriate frame for pork or poultry. Pigs and '
      'chickens are not 100% forage-fed animals. Look instead for pasture-raised '
      'or outdoor-access claims with documented feed sourcing.';

  static const explainNoFederalDefinition =
      'There is no FSIS regulatory definition of regenerative agriculture. '
      'USDA-NRCS treats it as a conservation management approach centered on '
      'four soil-health principles (maximize living roots, minimize disturbance, '
      'maximize soil cover, maximize biodiversity), but those principles are not '
      'a labeling standard. FSIS reviews "regenerative" claims on meat and '
      'poultry as voluntary marketing claims (FSIS-GD-2024-0006) and strongly '
      'encourages third-party certification.';

  static const explainOutcomeNotPractice =
      'The academic literature treats regenerative agriculture as a system, not '
      'a checklist. A farm is not regenerative because it uses one practice. '
      'The stronger test is whether soil organic matter, water infiltration, '
      'plant diversity, and animal welfare are improving over time, with '
      'documentation to prove it. Outcomes — not the label itself — are the standard.';

  static const verifyThirdParty =
      'Audit records or certification mark from an independent certifier, '
      'covering soil, water, biodiversity, livestock integration, and traceability.';

  static const verifyPVP =
      'USDA Process Verified Program documentation showing the producer\'s '
      'self-defined standard and the audit scope.';

  static const verifyAffidavit =
      'FSIS label-approval record. No independent on-farm audit required.';
}

/// Port of RegenerativeDetector.detect(in:detectedSpecies:).
({List<_RegenClaimMatch> claims, String? speciesMisuseFlag}) _detectRegen(
    String text, String? detectedSpecies) {
  final claims = <_RegenClaimMatch>[];

  // 1. Regenerative Organic Certified.
  if (text.contains('regenerative organic certified') ||
      (text.contains('regenerative organic') && text.contains('certified'))) {
    claims.add(const _RegenClaimMatch(
      claimType: _RegenClaimType.regenerativeOrganicCertified,
      credibility: _RegenCredibility.thirdPartyAudited,
      consumerAlert: _RegenKB.alertROC,
      detailedExplanation: _RegenKB.explainOutcomeNotPractice,
      verificationRequirement: _RegenKB.verifyThirdParty,
    ));
  }

  // 2. Land to Market / EOV.
  if (text.contains('land to market') ||
      text.contains('ecological outcome verification') ||
      text.contains(' eov ')) {
    claims.add(const _RegenClaimMatch(
      claimType: _RegenClaimType.landToMarketEOV,
      credibility: _RegenCredibility.thirdPartyAudited,
      consumerAlert: _RegenKB.alertLandToMarket,
      detailedExplanation: _RegenKB.explainOutcomeNotPractice,
      verificationRequirement: _RegenKB.verifyThirdParty,
    ));
  }

  // 3. Regenified.
  if (text.contains('regenified')) {
    claims.add(const _RegenClaimMatch(
      claimType: _RegenClaimType.regenified,
      credibility: _RegenCredibility.thirdPartyAudited,
      consumerAlert: _RegenKB.alertRegenified,
      detailedExplanation: _RegenKB.explainOutcomeNotPractice,
      verificationRequirement: _RegenKB.verifyThirdParty,
    ));
  }

  // 4. A Greener World — Certified Regenerative.
  if (text.contains('certified regenerative') &&
      (text.contains('a greener world') || text.contains('agw'))) {
    claims.add(const _RegenClaimMatch(
      claimType: _RegenClaimType.agwCertifiedRegenerative,
      credibility: _RegenCredibility.thirdPartyAudited,
      consumerAlert: _RegenKB.alertAGWRegen,
      detailedExplanation: _RegenKB.explainOutcomeNotPractice,
      verificationRequirement: _RegenKB.verifyThirdParty,
    ));
  }

  // 5. USDA Process Verified + regenerative.
  final mentionsPVP = text.contains('process verified') ||
      text.contains('usda pvp') ||
      text.contains(' pvp ');
  if (mentionsPVP && text.contains('regenerative')) {
    claims.add(const _RegenClaimMatch(
      claimType: _RegenClaimType.usdaPVPRegenerative,
      credibility: _RegenCredibility.usdaProcessVerified,
      consumerAlert: _RegenKB.alertPVPRegen,
      detailedExplanation: _RegenKB.explainNoFederalDefinition,
      verificationRequirement: _RegenKB.verifyPVP,
    ));
  }

  // 6. FSIS-style "raised using regenerative agriculture practices".
  if (text.contains('raised using regenerative') ||
      text.contains('regenerative agriculture practices')) {
    final alreadyHasStronger = claims.any((c) =>
        c.credibility == _RegenCredibility.thirdPartyAudited ||
        c.credibility == _RegenCredibility.usdaProcessVerified);
    if (!alreadyHasStronger) {
      claims.add(const _RegenClaimMatch(
        claimType: _RegenClaimType.fsisRaisedUsingRegen,
        credibility: _RegenCredibility.fsisAffidavitOnly,
        consumerAlert: _RegenKB.alertFSISAffidavit,
        detailedExplanation: _RegenKB.explainNoFederalDefinition,
        verificationRequirement: _RegenKB.verifyAffidavit,
      ));
    }
  }

  // 7. Bare "regenerative".
  if (claims.isEmpty && text.contains('regenerative')) {
    claims.add(const _RegenClaimMatch(
      claimType: _RegenClaimType.regenerativeUnspecified,
      credibility: _RegenCredibility.marketingClaimOnly,
      consumerAlert: _RegenKB.alertMarketingOnly,
      detailedExplanation: _RegenKB.explainNoFederalDefinition,
      verificationRequirement: _RegenKB.verifyThirdParty,
    ));
  }

  // Species-misuse flag: "grass-fed" on pork/poultry.
  String? misuseFlag;
  final isNonRuminant =
      ['pork', 'chicken', 'turkey'].contains(detectedSpecies?.toLowerCase());
  final mentionsGrassFed =
      text.contains('grass fed') || text.contains('grassfed');
  if (isNonRuminant && mentionsGrassFed) {
    misuseFlag = _RegenKB.alertGrassFedMisuseOnNonRuminant;
  }

  return (claims: claims, speciesMisuseFlag: misuseFlag);
}

Color _regenCredibilityColor(_RegenCredibility c) {
  switch (c) {
    case _RegenCredibility.thirdPartyAudited:
      return _CertColors.successGreen;
    case _RegenCredibility.usdaProcessVerified:
      return _CertColors.fatAmber;
    case _RegenCredibility.fsisAffidavitOnly:
      return _CertColors.fatOrange;
    case _RegenCredibility.marketingClaimOnly:
      return _CertColors.danger;
  }
}

Color _regenAlertBg(_RegenCredibility c) {
  switch (c) {
    case _RegenCredibility.thirdPartyAudited:
      return _CertColors.successGreenSoft;
    case _RegenCredibility.usdaProcessVerified:
      return _CertColors.fatAmberTint;
    case _RegenCredibility.fsisAffidavitOnly:
      return _CertColors.fatOrangeTint;
    case _RegenCredibility.marketingClaimOnly:
      return _CertColors.fatRedTint;
  }
}

IconData _regenBadgeIcon(_RegenCredibility c) {
  switch (c) {
    case _RegenCredibility.thirdPartyAudited:
      return Icons.verified_user;
    case _RegenCredibility.usdaProcessVerified:
      return Icons.account_balance;
    case _RegenCredibility.fsisAffidavitOnly:
      return Icons.description;
    case _RegenCredibility.marketingClaimOnly:
      return Icons.warning_amber_rounded;
  }
}

String _regenTitle(_RegenClaimType t) {
  switch (t) {
    case _RegenClaimType.regenerativeOrganicCertified:
      return 'Regenerative Organic Certified';
    case _RegenClaimType.landToMarketEOV:
      return 'Land to Market — EOV';
    case _RegenClaimType.regenified:
      return 'Regenified';
    case _RegenClaimType.agwCertifiedRegenerative:
      return 'Certified Regenerative by AGW';
    case _RegenClaimType.usdaPVPRegenerative:
      return 'USDA Process Verified — Regenerative';
    case _RegenClaimType.fsisRaisedUsingRegen:
      return 'Raised Using Regenerative Practices (FSIS)';
    case _RegenClaimType.regenerativeUnspecified:
      return 'Regenerative (No Certification)';
  }
}

class RegenerativeResultCard extends StatelessWidget {
  final List<_RegenClaimMatch> _claims;
  final String? _speciesMisuseFlag;
  const RegenerativeResultCard._(this._claims, this._speciesMisuseFlag);

  /// Returns a card when regen claims are present OR a species-misuse flag
  /// fired ("grass-fed" on pork/poultry), else null.
  static RegenerativeResultCard? maybeFrom(
      FATResult result, String scannedText) {
    final res = _detectRegen(_normalize(scannedText), _detectedSpecies(result));
    if (res.claims.isEmpty && res.speciesMisuseFlag == null) return null;
    return RegenerativeResultCard._(res.claims, res.speciesMisuseFlag);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CertColors.systemGray6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CertColors.systemGray4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const [
                Icon(Icons.autorenew, size: 18, color: _CertColors.successGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Regenerative / Land-Use Assessment',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _CertColors.fatDarkBlue)),
                ),
              ],
            ),
          ),
          if (_speciesMisuseFlag != null) ...[
            const SizedBox(height: 8),
            _SpeciesMisuseInlineBanner(text: _speciesMisuseFlag),
          ],
          for (var i = 0; i < _claims.length; i++) ...[
            const SizedBox(height: 12),
            _RegenClaimCard(claim: _claims[i]),
          ],
        ],
      ),
    );
  }
}

class _SpeciesMisuseInlineBanner extends StatelessWidget {
  final String text;
  const _SpeciesMisuseInlineBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _CertColors.fatOrangeTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.help, size: 14, color: _CertColors.fatOrange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: _CertColors.fatBodyText)),
          ),
        ],
      ),
    );
  }
}

class _RegenClaimCard extends StatefulWidget {
  final _RegenClaimMatch claim;
  const _RegenClaimCard({required this.claim});

  @override
  State<_RegenClaimCard> createState() => _RegenClaimCardState();
}

class _RegenClaimCardState extends State<_RegenClaimCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final accent = _regenCredibilityColor(claim.credibility);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CertColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(_regenTitle(claim.claimType),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _CertColors.fatDarkBlue)),
              ),
              const SizedBox(width: 8),
              _credibilityBadge(
                _regenBadgeIcon(claim.credibility),
                claim.credibility.displayLabel,
                _regenCredibilityColor(claim.credibility),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _regenAlertBg(claim.credibility),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(claim.consumerAlert,
                style: const TextStyle(
                    fontSize: 12, color: _CertColors.fatBodyText)),
          ),
          const SizedBox(height: 8),
          _moreDetailButton(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            _detailRow(Icons.description, 'What This Means',
                claim.detailedExplanation),
            const SizedBox(height: 8),
            _detailRow(Icons.verified, 'Verification Required',
                claim.verificationRequirement),
            const SizedBox(height: 8),
            const Text(
                'Source: FAT Research Brief — What Regenerative Agriculture Means (May 2026)',
                style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: _CertColors.fatPaleGray)),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared small widgets used by GrassFed / Pasture / Regenerative claim cards
// ═════════════════════════════════════════════════════════════════════════════

/// Pill badge: icon + label tinted with [color] at 15% background opacity.
Widget _credibilityBadge(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500, color: color)),
      ],
    ),
  );
}

/// "More detail" / "Less detail" toggle row.
Widget _moreDetailButton({required bool expanded, required VoidCallback onTap}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(expanded ? 'Less detail' : 'More detail',
            style: const TextStyle(fontSize: 12, color: _CertColors.fatBlue)),
        const SizedBox(width: 2),
        Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 14, color: _CertColors.fatBlue),
      ],
    ),
  );
}

/// Labeled detail block (icon + label header, body text) on a gray panel.
Widget _detailRow(IconData icon, String label, String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: _CertColors.systemGray6,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: _CertColors.fatGray),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _CertColors.fatDarkBlue)),
          ],
        ),
        const SizedBox(height: 4),
        Text(text,
            style:
                const TextStyle(fontSize: 12, color: _CertColors.fatBodyText)),
      ],
    ),
  );
}
