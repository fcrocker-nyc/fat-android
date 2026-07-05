import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/fat_models.dart';
import '../theme/fat_theme.dart';
import '../data/pork_owner_database.dart';
import '../services/scan_store.dart';
import 'certification_result_cards.dart';

/// Meat / poultry scan result screen — Flutter port of iOS ResultsView.
/// Mirrors the spec section-by-section (A1–A11), constrained to the fields
/// that actually exist on FATResult / FATCategoryResult.
class ResultsScreen extends StatefulWidget {
  final FATResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _didSave = false;
  // OSHA worker-safety penalty against the Processor (Cat 7) disclosure score.
  // Set true after the live OSHA fetch confirms a high-confidence match with
  // violations on record; the score/grade then recompute with −2 applied.
  bool _oshaViolation = false;

  @override
  void initState() {
    super.initState();
    _loadOshaPenalty();
  }

  Future<void> _loadOshaPenalty() async {
    final est = result.detectedEstablishmentNumber;
    if (est == null) return;
    try {
      final resp = await http
          .get(Uri.parse(
              'https://farmanimaltransparency.com/wp-json/fat/v1/osha/$est'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final d = jsonDecode(resp.body);
      if (d is! Map) return;
      final s = d['summary'];
      // Penalty fires only on a high-confidence match with actual violations.
      final hasViolations = d['found'] == true &&
          d['match_confidence'] == 'high' &&
          s is Map &&
          (((s['total_violations'] ?? 0) as num).toInt() > 0);
      if (hasViolations && mounted) {
        setState(() => _oshaViolation = true);
      }
    } catch (_) {
      // Network/parse failure → no penalty applied (fail-open).
    }
  }

  double get _penalizedScore =>
      result.fatScoreWith(oshaViolation: _oshaViolation);

  FATResult get result => widget.result;

  // ── Palette (spec section D) ───────────────────────────────────────────
  static const _disclosureGreen = Color(0xFF34A853); // ✓ disclosed
  static const _fatAmber = FATTheme.fatAmber; //         ⚠ partial / USDA-reviewed
  static const _fatRed = FATTheme.fatRed; //             ✗ missing
  static const _fatGreen = FATTheme.primaryGreen; //     sage card BG
  static const _fatGreenLight = Color(0xFFDEE1D7); //    nested card BG
  static const _orange = FATTheme.fatOrange;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formattedDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  Color _statusColor(DisclosureStatus s) {
    switch (s) {
      case DisclosureStatus.known:
        return _disclosureGreen;
      case DisclosureStatus.partial:
        return _fatAmber;
      case DisclosureStatus.missing:
        return _fatRed;
      case DisclosureStatus.notRequired:
        return _disclosureGreen;
    }
  }

  Color _credColor(ClaimCredibility c) {
    switch (c) {
      case ClaimCredibility.verified:
        return _disclosureGreen;
      case ClaimCredibility.usdaApproved:
        return _fatAmber;
      case ClaimCredibility.producerAffidavit:
        return _orange;
      case ClaimCredibility.labelClaimOnly:
        return _fatRed;
    }
  }

  IconData _credIcon(ClaimCredibility c) {
    switch (c) {
      case ClaimCredibility.verified:
        return Icons.verified_user;
      case ClaimCredibility.usdaApproved:
        return Icons.verified;
      case ClaimCredibility.producerAffidavit:
        return Icons.description_outlined;
      case ClaimCredibility.labelClaimOnly:
        return Icons.info_outline;
    }
  }

  Color _captivityColor(CaptivityStatus c) {
    switch (c) {
      case CaptivityStatus.packerOwned:
        return _fatRed;
      case CaptivityStatus.packerContracted:
        return _orange;
      case CaptivityStatus.independent:
        return _disclosureGreen;
      case CaptivityStatus.undisclosed:
        return Colors.grey;
    }
  }

  IconData _captivityIcon(CaptivityStatus c) {
    switch (c) {
      case CaptivityStatus.packerOwned:
        return Icons.lock;
      case CaptivityStatus.packerContracted:
        return Icons.link;
      case CaptivityStatus.independent:
        return Icons.handshake_outlined;
      case CaptivityStatus.undisclosed:
        return Icons.help_outline;
    }
  }

  // ── Score pillars ──────────────────────────────────────────────────────
  // The model only exposes the combined fatScore. Recompute the two pillars
  // here using the identical formula from FATResult.fatScore so we can render
  // the Disclosure (/70) and Credibility (/30) progress bars per spec A4.

  double get _disclosurePillar {
    final allCats = FATCategory.values;
    double points = 0;
    for (final cat in allCats) {
      final r = result.categories[cat];
      if (r == null) continue;
      if (r.status == DisclosureStatus.known) points += 5;
      if (r.status == DisclosureStatus.partial) points += 2;
    }
    final maxDisclosure = allCats.length * 5.0;
    return (points / maxDisclosure) * 70;
  }

  double get _credibilityPillar {
    final weights = result.categories.values
        .where((r) => r.credibility != null)
        .map((r) => r.credibility!.scoreWeight)
        .toList();
    if (weights.isEmpty) return 0;
    final avg = weights.reduce((a, b) => a + b) / weights.length;
    return avg * 30;
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _withSpacing(18, [
              _header(),
              _scoreCard(),
              ..._estWarnings(),
              _disclosureSummary(),
              if (result.detectedEstablishmentNumber != null) _processorSection(),
              _categorySection(),
              // Certification result cards (grass-fed / welfare cert / pasture /
              // regenerative) — each renders only when detected on the label.
              ...[
                CertificationResultCard.maybeFrom(result, result.scannedText),
                GrassFedResultCard.maybeFrom(result, result.scannedText),
                PastureResultCard.maybeFrom(result, result.scannedText),
                RegenerativeResultCard.maybeFrom(result, result.scannedText),
              ].whereType<Widget>(),
              _actions(context),
            ]),
          ),
        ),
      ),
    );
  }

  /// Insert [gap] between non-null children (mirrors VStack spacing).
  List<Widget> _withSpacing(double gap, List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(SizedBox(height: gap));
    }
    return out;
  }

  // ── A1. Header ─────────────────────────────────────────────────────────
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Label Analysis',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_formattedDate(result.scannedAt),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
      ],
    );
  }

  // ── A4. FAT Score Card ─────────────────────────────────────────────────
  Widget _scoreCard() {
    final score = result.fatScoreWith(oshaViolation: _oshaViolation);
    final grade = FATResult.gradeFor(score);
    final gradeColor = FATResult.gradeColorFor(score);
    final disclosurePct = (_disclosurePillar / 70).clamp(0.0, 1.0);
    final credPct = (_credibilityPillar / 30).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fatGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FAT Score',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          // Score number + grade badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(score.toStringAsFixed(0),
                      style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: gradeColor,
                          height: 1.0)),
                  const SizedBox(height: 2),
                  const Text('out of 100',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 20),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(grade,
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: gradeColor)),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          _pillarBar('Disclosure', disclosurePct, gradeColor),
          const SizedBox(height: 14),
          _pillarBar('Credibility', credPct, gradeColor),
          const SizedBox(height: 14),
          const Text(
            'Score reflects label disclosure completeness and data credibility — not product quality or nutrition.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _pillarBar(String label, double fraction, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${(fraction * 100).round()}%',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Container(
                  height: 12,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── A5. EST Warnings ───────────────────────────────────────────────────
  List<Widget> _estWarnings() {
    final widgets = <Widget>[];
    if (result.estMissing) {
      widgets.add(_warningBanner(
        icon: Icons.dangerous,
        iconColor: _fatRed,
        bgColor: _fatRed.withValues(alpha: 0.08),
        borderColor: _fatRed.withValues(alpha: 0.5),
        title: 'No Establishment Number Found',
        titleColor: _fatRed,
        body:
            'This label does not show a USDA establishment (EST.) number. FSIS requires one on all federally inspected meat and poultry products, so its absence may indicate an incomplete label, an exempt product, or imported product handled differently.',
      ));
    }
    if (result.estSpeciesMismatch && result.estSpeciesMismatchNote != null) {
      widgets.add(_warningBanner(
        icon: Icons.warning_amber_rounded,
        iconColor: _orange,
        bgColor: _orange.withValues(alpha: 0.10),
        borderColor: _orange.withValues(alpha: 0.4),
        title: 'Establishment Number May Be Incorrect',
        titleColor: Colors.black,
        body: result.estSpeciesMismatchNote!,
      ));
    }
    if (result.speciesClaimMisuseNote != null) {
      widgets.add(_warningBanner(
        icon: Icons.help_outline,
        iconColor: _orange,
        bgColor: _orange.withValues(alpha: 0.10),
        borderColor: _orange.withValues(alpha: 0.4),
        title: "Claim Doesn't Match the Species",
        titleColor: Colors.black,
        body: result.speciesClaimMisuseNote!,
      ));
    }
    return widgets;
  }

  Widget _warningBanner({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required Color titleColor,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── A6. Disclosure Summary ─────────────────────────────────────────────
  Widget _disclosureSummary() {
    // Credibility tier counts across all disclosed categories.
    final tierCounts = <ClaimCredibility, int>{};
    for (final r in result.categories.values) {
      final c = r.credibility;
      if (c == null) continue;
      tierCounts[c] = (tierCounts[c] ?? 0) + 1;
    }
    final hasDisclosed = result.knownCount + result.partialCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fatGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _fatGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What This Label Discloses',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _dotRow(_disclosureGreen, 'Disclosed', result.knownCount),
          const SizedBox(height: 10),
          _dotRow(_fatAmber, 'Partially disclosed', result.partialCount),
          const SizedBox(height: 10),
          _dotRow(_fatRed, 'Not disclosed', result.missingCount),
          if (hasDisclosed) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.black.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            const Text('Claim Credibility',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final tier in ClaimCredibility.values)
              if ((tierCounts[tier] ?? 0) > 0) ...[
                _credRow(tier, tierCounts[tier]!),
                const SizedBox(height: 8),
              ],
          ],
          const SizedBox(height: 4),
          const Text(
            'This summary reflects what the label discloses and how claims are backed. It is not a rating, endorsement, or certification.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _dotRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('$count',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _credRow(ClaimCredibility tier, int count) {
    final color = _credColor(tier);
    return Row(
      children: [
        Icon(_credIcon(tier), size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(tier.displayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Text('$count',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── A7. Processor / "Who Stands Behind the Label" ──────────────────────
  Widget _processorSection() {
    final est = result.detectedEstablishmentNumber!;
    final owner = PorkOwnerDatabase.detectOwnerAnySpeciesForEstablishment(est);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who Stands Behind the Label',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _fatGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EST pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _disclosureGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('USDA EST. $est',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              if (owner != null) ...[
                const SizedBox(height: 12),
                _ownerBlock(owner),
              ] else ...[
                const SizedBox(height: 12),
                const Text(
                  'No corporate-owner record matched this establishment number. The processing facility is federally inspected under this EST number.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openUrl(
                    'https://farmanimaltransparency.com/processor/est-$est'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Text('View full profile on FAT website',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ownerBlock(PorkOwnerResult r) {
    final o = r.owner;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fatGreenLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Corporate Owner',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text('${o.flag} ${o.name}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
              '${o.country} · ${o.marketSharePct.toStringAsFixed(0)}% market share'
              '${o.isTop3 ? ' · Top 3' : ''}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(o.note, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // ── A10. "What We Checked" categories ──────────────────────────────────
  Widget _categorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What We Checked',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        ..._withSpacing(14, FATCategory.values.map(_categoryCard).toList()),
      ],
    );
  }

  Widget _categoryCard(FATCategory category) {
    final value = result.categories[category];
    final status = value?.status ?? DisclosureStatus.missing;
    final accentColor = _statusColor(status);

    String statusText;
    switch (status) {
      case DisclosureStatus.known:
        statusText = value?.value ?? 'Disclosed.';
        break;
      case DisclosureStatus.partial:
        statusText = value?.value ?? 'Partially disclosed.';
        break;
      case DisclosureStatus.missing:
        statusText = '${category.displayName} not disclosed.';
        break;
      case DisclosureStatus.notRequired:
        statusText = 'Not required by federal law.';
        break;
    }

    final isFsisDisclosed =
        category == FATCategory.usdaFsisRequiredLanguage &&
            status == DisclosureStatus.known;
    final subtitleColor = isFsisDisclosed ? _disclosureGreen : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: _fatGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(statusText,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor)),
                    if (value?.credibility != null) ...[
                      const SizedBox(height: 6),
                      _credibilityBadge(
                          value!.credibility!, value.credibilityNote),
                    ],
                    if (category == FATCategory.supplyChainIntermediary &&
                        value?.captivityStatus != null) ...[
                      const SizedBox(height: 2),
                      _captivityBadge(value!.captivityStatus!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credibilityBadge(ClaimCredibility cred, String? note) {
    final color = _credColor(cred);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_credIcon(cred), size: 13, color: color),
              const SizedBox(width: 6),
              Text(cred.displayName,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _captivityBadge(CaptivityStatus captivity) {
    final color = _captivityColor(captivity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_captivityIcon(captivity), size: 13, color: color),
          const SizedBox(width: 6),
          Text(captivity.displayName,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ── A11. Actions ───────────────────────────────────────────────────────
  Widget _actions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _primaryButton(
                _didSave ? 'Saved' : 'Save',
                _didSave ? null : _save,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _primaryButton('Share', _share)),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _questions,
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Questions?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FATTheme.scanGreen)),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _fatGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
        ),
      ),
    );
  }

  // ── Actions logic ──────────────────────────────────────────────────────
  Future<void> _save() async {
    await ScanStore.instance.saveResult(result);
    if (!mounted) return;
    setState(() => _didSave = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to scan history.')),
    );
  }

  String _summaryText() {
    final lines = <String>[
      'Farm Animal Transparency (FAT) — Label Analysis',
      'Date: ${_formattedDate(result.scannedAt)}',
      'FAT Score: ${_penalizedScore.toStringAsFixed(0)}/100  Grade: ${FATResult.gradeFor(_penalizedScore)}',
      '',
    ];
    for (final cat in FATCategory.values) {
      final r = result.categories[cat] ?? FATCategoryResult.missing;
      var line = '${cat.displayName}: ${r.status.name.toUpperCase()}';
      if (r.credibility != null) line += ' [${r.credibility!.displayName}]';
      lines.add(line);
    }
    if (result.detectedEstablishmentNumber != null) {
      lines.add('');
      lines.add('USDA EST. ${result.detectedEstablishmentNumber}');
    }
    lines.add('');
    lines.add('Generated by the FAT App — farmanimaltransparency.com');
    return lines.join('\n');
  }

  Future<void> _share() async {
    final subject = Uri.encodeComponent(
        'FAT Label Analysis — Score ${_penalizedScore.toStringAsFixed(0)}/100');
    final body = Uri.encodeComponent(_summaryText());
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    final launched = await _launch(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summary ready (${_summaryText().length} chars).')),
      );
    }
  }

  Future<void> _questions() async {
    final subject = Uri.encodeComponent('FAT App — Question about a label');
    final body = Uri.encodeComponent('\n\n---\n${_summaryText()}');
    final uri = Uri.parse(
        'mailto:dirkadams@farmanimaltransparency.com?subject=$subject&body=$body');
    final launched = await _launch(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Email: dirkadams@farmanimaltransparency.com')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await _launch(uri);
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
