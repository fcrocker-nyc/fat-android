import 'dart:convert';
import '../widgets/label_image_viewer.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/fat_models.dart';
import '../theme/fat_theme.dart';
import '../services/scan_store.dart';
import '../services/epa_service.dart';
import '../services/processor_service.dart';
import '../widgets/share_card_renderer.dart';

/// Seafood scan result screen — Flutter port of iOS SeafoodResultsView.
///
/// NOTE ON MODEL LIMITS: the shared FATResult model in this app exposes only
/// the meat surface (`categories: Map<FATCategory, FATCategoryResult>`). It has
/// NO seafoodCategories, productType, productionMethod, or isSiluriformes
/// fields. This screen therefore renders the seafood layout (header, blue
/// product-type banner, 3-tier disclosure summary, category section, actions)
/// using result.categories, and surfaces a note in the banner that production
/// method / siluriformes data is unavailable from the current model.
class SeafoodResultsScreen extends StatefulWidget {
  final FATResult result;
  /// Photographed label panels for this session (shown as a top carousel).
  final List<String> imagePaths;
  const SeafoodResultsScreen(
      {super.key, required this.result, this.imagePaths = const []});

  @override
  State<SeafoodResultsScreen> createState() => _SeafoodResultsScreenState();
}

class _SeafoodResultsScreenState extends State<SeafoodResultsScreen> {
  bool _didSave = false;
  // OSHA worker-safety penalty against the Processor (Cat 7) disclosure score —
  // relevant to catfish/Siluriformes, the only seafood with an OSHA-linkable
  // FSIS establishment. Set true after a high-confidence match with violations.
  bool _oshaViolation = false;
  bool _epaViolation = false; // EPA environmental-enforcement penalty (Cat 7)
  // FSIS record — only catfish / Siluriformes seafood has an FSIS establishment;
  // for FDA-regulated seafood the fetch simply 404s and nothing renders.
  ProcessorRecord? _processor;

  FATResult get result => widget.result;

  List<String> get _panelPaths =>
      widget.imagePaths.isNotEmpty ? widget.imagePaths : widget.result.imagePaths;

  @override
  void initState() {
    super.initState();
    _loadOshaPenalty();
    _loadEpaPenalty();
    _loadProcessorRecord();
  }

  Future<void> _loadProcessorRecord() async {
    final rec =
        await ProcessorService.fetch(result.detectedEstablishmentNumber);
    if (rec != null && mounted) setState(() => _processor = rec);
  }

  Future<void> _loadEpaPenalty() async {
    final v = await EpaService.hasViolation(result.detectedEstablishmentNumber);
    if (v && mounted) setState(() => _epaViolation = true);
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
      final hasViolations = d['found'] == true &&
          d['match_confidence'] == 'high' &&
          s is Map &&
          (((s['total_violations'] ?? 0) as num).toInt() > 0);
      if (hasViolations && mounted) {
        setState(() => _oshaViolation = true);
      }
    } catch (_) {
      // Fail-open: no penalty on network/parse error.
    }
  }

  // ── Palette ────────────────────────────────────────────────────────────
  static const _disclosureGreen = Color(0xFF34A853);
  static const _fatAmber = FATTheme.fatAmber;
  static const _fatRed = FATTheme.fatRed;
  static const _fatGreen = FATTheme.primaryGreen;
  static const _orange = FATTheme.fatOrange;
  static const _seafoodUsdaBlue = Color(0xFF3380CC); // usdaApproved (seafood)

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formattedDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  // Seafood uses only 3 credibility tiers (verified, usdaApproved,
  // labelClaimOnly). producerAffidavit maps to orange if it ever appears.
  Color _credColor(ClaimCredibility c) {
    switch (c) {
      case ClaimCredibility.verified:
        return _disclosureGreen;
      case ClaimCredibility.usdaApproved:
        return _seafoodUsdaBlue;
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
              if (_panelPaths.isNotEmpty) _imageCarousel(),
              _productTypeBanner(),
              _atAGlanceCard(),
              _disclosureSummary(),
              if (_processor != null) _fsisRecordSection(),
              _categorySection(),
              _actions(context),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _withSpacing(double gap, List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(SizedBox(height: gap));
    }
    return out;
  }

  // ── B1. Header ─────────────────────────────────────────────────────────
  /// FSIS public record for catfish/Siluriformes plants (USDA-inspected seafood).
  /// Mirrors the meat Results enforcement block.
  Widget _fsisRecordSection() {
    final p = _processor!;
    final asOf = p.generatedDate != null ? ' (as of ${p.generatedDate})' : '';
    final rows = <Widget>[];
    Widget line(IconData ic, Color c, String label, String detail) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(ic, size: 16, color: c)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: Colors.black),
                  children: [
                    TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: detail),
                  ],
                ),
              ),
            ),
          ]),
        );
    if (p.hasRecalls) {
      rows.add(line(Icons.warning_amber_rounded, const Color(0xFFC0392B), 'Recalls', '${p.recallCount} on record'));
    }
    final hh = p.humaneHandling;
    if (hh.isNotEmpty) {
      rows.add(line(Icons.pets, const Color(0xFFEF8A2B), 'Humane handling', '${hh.length} noncompliance record(s)'));
    }
    if (p.hasResidues) {
      rows.add(line(Icons.biotech_outlined, const Color(0xFFC0392B), 'Chemical residue', '${p.residueCount} violation(s) on record'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FSIS Public Record',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: FATTheme.primaryGreen, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('USDA-inspected (catfish / Siluriformes) — EST. ${p.estNumber}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Clean record — no recalls, humane-handling actions, or residue violations on file$asOf.',
                      style: const TextStyle(fontSize: 13.5)),
                )
              else
                ...rows,
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageCarousel() {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _panelPaths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () =>
              LabelImageViewer.open(context, _panelPaths, initialIndex: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_panelPaths[i]),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Evaluation Results',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_formattedDate(result.scannedAt),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
      ],
    );
  }

  // ── B3. Product Type Banner ────────────────────────────────────────────
  Widget _productTypeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.set_meal, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seafood Product',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                    result.isSiluriformes
                        ? 'Catfish / Siluriformes — USDA/FSIS regulated'
                        : 'FDA regulated',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (result.productionMethod != null) ...[
                  const SizedBox(height: 2),
                  Text(result.productionMethod!.displayName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _disclosureGreen)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── At-a-glance card ──────────────────────────────────────────────────
  // Mirrors the meat results screen: FSIS/FDA baseline, a single-color
  // 16-segment disclosure meter, the disclosed count, what the label is silent
  // on, and how claims are backed. Reports counts, not a grade.

  int get _seafoodTotal =>
      SeafoodCategory.values.where((c) => c.isAppSupported).length;

  List<SeafoodCategory> get _silentSeafood => SeafoodCategory.values
      .where((c) =>
          c.isAppSupported &&
          (result.seafoodCategories[c]?.status ?? DisclosureStatus.missing) ==
              DisclosureStatus.missing)
      .toList();

  int _credCount(ClaimCredibility tier) =>
      result.seafoodCategories.values.where((r) => r.credibility == tier).length;

  bool get _hasEnforcement => _oshaViolation || _epaViolation;

  String _seafoodGlanceLabel(SeafoodCategory c) {
    switch (c) {
      case SeafoodCategory.regulatoryRequiredLanguage:    return 'required basics';
      case SeafoodCategory.speciesIdentity:               return 'species';
      case SeafoodCategory.strainVariety:                 return 'strain';
      case SeafoodCategory.countryOrigin:                 return 'origin';
      case SeafoodCategory.farmVesselFishery:             return 'vessel / farm';
      case SeafoodCategory.ageAtHarvest:                  return 'harvest age';
      case SeafoodCategory.processor:                     return 'processor';
      case SeafoodCategory.who:                           return 'owner';
      case SeafoodCategory.brand:                         return 'brand';
      case SeafoodCategory.productionMethodFeed:          return 'wild vs farmed';
      case SeafoodCategory.animalWelfare:                 return 'welfare';
      case SeafoodCategory.medicineAntibioticsChemicals:  return 'antibiotics';
      case SeafoodCategory.hormones:                      return 'hormones';
      case SeafoodCategory.qualityHandling:               return 'quality';
      case SeafoodCategory.organic:                       return 'organic';
      case SeafoodCategory.supplyChainIntermediary:       return 'supply chain';
    }
  }

  String _seafoodSilentSummary(List<SeafoodCategory> cats) {
    final labels = cats.map(_seafoodGlanceLabel).toList();
    final head = labels.take(4).toList();
    var s = head.join(', ');
    final rest = labels.length - head.length;
    if (rest > 0) s += ' — and $rest more';
    return s;
  }

  ({String line, IconData icon, Color color}) get _seafoodVerification {
    if (_credCount(ClaimCredibility.verified) > 0) {
      return (line: 'Independently verified claims present', icon: Icons.verified, color: _disclosureGreen);
    }
    if (_credCount(ClaimCredibility.usdaApproved) > 0) {
      return (line: 'USDA-reviewed claims present', icon: Icons.verified_user, color: _fatAmber);
    }
    if (_credCount(ClaimCredibility.producerAffidavit) > 0) {
      return (line: 'Producer-affidavit claims only', icon: Icons.info_outline, color: Colors.black54);
    }
    if (_credCount(ClaimCredibility.labelClaimOnly) > 0) {
      return (line: 'Unverified marketing claims only', icon: Icons.info_outline, color: Colors.black54);
    }
    return (line: 'No backed claims disclosed', icon: Icons.info_outline, color: Colors.black54);
  }

  Widget _atAGlanceCard() {
    final total = _seafoodTotal;
    final disclosed = result.knownCount;
    final partial = result.partialCount;
    final silent = _silentSeafood;
    final v = _seafoodVerification;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _fatGreen, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.shield_outlined, size: 16, color: _disclosureGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meets USDA FSIS minimums — as is required of all federally inspected meat and catfish.',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(total, (i) {
              return Expanded(
                child: Container(
                  height: 12,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: i < disclosed
                        ? _disclosureGreen
                        : Colors.black.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$disclosed',
                  style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: _disclosureGreen,
                      height: 1.0)),
              const SizedBox(width: 8),
              Text('of $total categories disclosed',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (partial > 0) ...[
            const SizedBox(height: 4),
            Text('$partial more partially disclosed',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _fatAmber)),
          ],
          if (silent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Silent on: ${_seafoodSilentSummary(silent)}',
                style: TextStyle(
                    fontSize: 13.5, color: Colors.black.withValues(alpha: 0.7))),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(v.icon, size: 13, color: v.color),
                const SizedBox(width: 6),
                Text(v.line,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: v.color)),
              ],
            ),
          ),
          if (_hasEnforcement) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel, size: 14, color: Color(0xFFB45309)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Processor has federal enforcement violations on record — see the processor section below.',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text('A count of what the label discloses — not a rating of the food.',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.55))),
        ],
      ),
    );
  }

  // ── B4. Disclosure Summary (3 credibility tiers) ───────────────────────
  Widget _disclosureSummary() {
    final tierCounts = <ClaimCredibility, int>{};
    for (final r in result.seafoodCategories.values) {
      final c = r.credibility;
      if (c == null) continue;
      tierCounts[c] = (tierCounts[c] ?? 0) + 1;
    }
    final hasDisclosed = result.knownCount + result.partialCount > 0;
    final notRequiredCount = result.seafoodCategories.values
        .where((r) => r.status == DisclosureStatus.notRequired)
        .length;

    // Seafood surfaces only 3 tiers.
    const seafoodTiers = [
      ClaimCredibility.verified,
      ClaimCredibility.usdaApproved,
      ClaimCredibility.labelClaimOnly,
    ];

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
          if (notRequiredCount > 0) ...[
            const SizedBox(height: 10),
            _dotRow(Colors.blue, 'Not required', notRequiredCount),
          ],
          if (hasDisclosed) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.black.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            const Text('Claim Credibility',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final tier in seafoodTiers)
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

  // ── B6. Category Section ───────────────────────────────────────────────
  Widget _categorySection() {
    final appCats =
        SeafoodCategory.values.where((c) => c.isAppSupported).toList();
    final websiteCats =
        SeafoodCategory.values.where((c) => !c.isAppSupported).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transparency Categories',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        ..._withSpacing(14, appCats.map(_categoryCard).toList()),
        if (websiteCats.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Website Only',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ..._withSpacing(14, websiteCats.map(_websiteOnlyCard).toList()),
        ],
      ],
    );
  }

  Widget _websiteOnlyCard(SeafoodCategory category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fatGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(category.displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Website',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Visit farmanimaltransparency.com for this category.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _categoryCard(SeafoodCategory category) {
    final value = result.seafoodCategories[category];
    final status = value?.status ?? DisclosureStatus.missing;

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
        statusText = value?.value ?? 'Not required by federal law.';
        break;
    }

    final isRegulatory = category == SeafoodCategory.regulatoryRequiredLanguage;
    Color subtitleColor;
    if (status == DisclosureStatus.notRequired) {
      subtitleColor = Colors.blue;
    } else if (isRegulatory && status == DisclosureStatus.known) {
      subtitleColor = _disclosureGreen;
    } else {
      subtitleColor = Colors.black;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fatGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.displayName,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(statusText,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor)),
          if (value?.credibility != null) ...[
            const SizedBox(height: 6),
            _credibilityBadge(value!.credibility!, value.credibilityNote),
          ],
        ],
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

  // ── B7. Actions ────────────────────────────────────────────────────────
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
      'Farm Animal Transparency (FAT) — Seafood Evaluation',
      'Date: ${_formattedDate(result.scannedAt)}',
      '',
    ];
    for (final cat in SeafoodCategory.values) {
      final r = result.seafoodCategories[cat] ?? FATCategoryResult.missing;
      var line = '${cat.displayName}: ${r.status.name.toUpperCase()}';
      if (r.credibility != null) line += ' [${r.credibility!.displayName}]';
      if (!cat.isAppSupported) line += ' (website only)';
      lines.add(line);
    }
    lines.add('');
    lines.add('Generated by the FAT App — farmanimaltransparency.com');
    return lines.join('\n');
  }

  Future<void> _share() async {
    // Primary path: render the disclosure card to a PNG and share the image.
    final shared = await shareDisclosureCard(
      context,
      result,
      shareText:
          'FAT Seafood Evaluation — discloses ${result.knownCount} of $_seafoodTotal transparency categories. farmanimaltransparency.com',
    );
    if (shared) return;

    // Fallback: the original text / mailto share when image rendering fails.
    final subject =
        Uri.encodeComponent('FAT Seafood Evaluation');
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
    final subject =
        Uri.encodeComponent('FAT App — Question about a seafood label');
    final body = Uri.encodeComponent('\n\n---\n${_summaryText()}');
    final uri = Uri.parse(
        'mailto:dirkadams@farmanimaltransparency.com?subject=$subject&body=$body');
    final launched = await _launch(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Email: dirkadams@farmanimaltransparency.com')),
      );
    }
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
