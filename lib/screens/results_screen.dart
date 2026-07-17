import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/fat_models.dart';
import '../theme/fat_theme.dart';
import '../data/pork_owner_database.dart';
import '../services/scan_store.dart';
import '../services/epa_service.dart';
import '../services/processor_service.dart';
import '../services/feedlot_proximity_service.dart';
import '../widgets/share_card_renderer.dart';
import 'certification_result_cards.dart';
import '../widgets/label_image_viewer.dart';

/// Meat / poultry scan result screen — Flutter port of iOS ResultsView.
/// Mirrors the spec section-by-section (A1–A11), constrained to the fields
/// that actually exist on FATResult / FATCategoryResult.
class ResultsScreen extends StatefulWidget {
  final FATResult result;
  /// File paths of the label panels the user photographed this session. Shown
  /// as a carousel at the top, matching iOS. Empty when opened from History
  /// (images are not persisted across sessions).
  final List<String> imagePaths;
  const ResultsScreen(
      {super.key, required this.result, this.imagePaths = const []});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _didSave = false;
  // OSHA worker-safety penalty against the Processor (Cat 7) disclosure score.
  // Set true after the live OSHA fetch confirms a high-confidence match with
  // violations on record; the score/grade then recompute with −2 applied.
  bool _oshaViolation = false;
  // EPA environmental-enforcement penalty (Cat 7), set after the jsDelivr fetch.
  bool _epaViolation = false;
  // FSIS public enforcement record fetched from the FAT backend (recalls,
  // humane-handling, Salmonella category, residues). Null until it loads.
  ProcessorRecord? _processor;
  bool _processorLoading = true;
  // Nearby EPA-ECHO CAFO/feedlot violators (beef → feedlots 50mi; pork → hog
  // CAFOs 75mi). Fetched once the processor record supplies coordinates.
  ProximityResult? _proximity;
  String _proximityKind = ''; // 'feedlot' | 'hog CAFO'

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
    if (mounted) {
      setState(() {
        _processor = rec;
        _processorLoading = false;
      });
    }
    // Chain the environmental-proximity lookup off the processor's coordinates.
    if (rec?.lat != null && rec?.lon != null) {
      final sp = rec!.primarySpecies.toLowerCase();
      ProximityResult? prox;
      String kind = '';
      if (sp.contains('beef') || sp.contains('cattle')) {
        prox = await FeedlotProximityService.feedlot(rec.lat!, rec.lon!);
        kind = 'feedlot';
      } else if (sp.contains('pork') || sp.contains('hog') || sp.contains('swine')) {
        prox = await FeedlotProximityService.hog(rec.lat!, rec.lon!);
        kind = 'hog CAFO';
      }
      if (prox != null && mounted) {
        setState(() {
          _proximity = prox;
          _proximityKind = kind;
        });
      }
    }
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

  FATResult get result => widget.result;

  /// Panel image paths to show: the ones passed in this session if present,
  /// else the paths persisted on the result (History re-open).
  List<String> get _panelPaths =>
      widget.imagePaths.isNotEmpty ? widget.imagePaths : widget.result.imagePaths;

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
              if (_panelPaths.isNotEmpty) _imageCarousel(),
              _atAGlanceCard(),
              ..._estWarnings(),
              _disclosureSummary(),
              if (result.detectedEstablishmentNumber != null) _processorSection(),
              if (_proximity != null) _proximitySection(),
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

  /// Scanned label panels, horizontally scrollable (mirrors iOS imageSection).
  Widget _imageCarousel() {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _panelPaths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => LabelImageViewer.open(context, _panelPaths,
              initialIndex: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_panelPaths[i]),
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
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

  // ── At-a-glance card ───────────────────────────────────────────────────
  // The fast, glanceable read leading the results screen: the FSIS baseline
  // that applies to all federally inspected product, a single-color 16-segment
  // disclosure meter, the disclosed count, what the label is silent on, and how
  // the disclosed claims are backed. Reports counts, not a verdict — no letter
  // grade is shown. The weighted 0–100 index remains behind the scenes only.

  static const int _totalCategories = 16;

  int _credCount(ClaimCredibility tier) =>
      result.categories.values.where((r) => r.credibility == tier).length;

  List<FATCategory> get _silentCategories => FATCategory.values
      .where((c) =>
          (result.categories[c]?.status ?? DisclosureStatus.missing) ==
          DisclosureStatus.missing)
      .toList();

  String _glanceLabel(FATCategory c) {
    switch (c) {
      case FATCategory.usdaFsisRequiredLanguage: return 'required basics';
      case FATCategory.species:                  return 'species';
      case FATCategory.breed:                    return 'breed';
      case FATCategory.countryOrigin:            return 'origin';
      case FATCategory.farmRanch:                return 'farm';
      case FATCategory.ageAtSlaughter:           return 'age at slaughter';
      case FATCategory.processor:                return 'processor';
      case FATCategory.who:                      return 'owner';
      case FATCategory.brand:                    return 'brand';
      case FATCategory.feed:                     return 'feed';
      case FATCategory.animalWelfare:            return 'animal welfare';
      case FATCategory.medicine:                 return 'antibiotics';
      case FATCategory.hormones:                 return 'hormones';
      case FATCategory.qualityPalatability:      return 'quality';
      case FATCategory.organic:                  return 'organic';
      case FATCategory.supplyChainIntermediary:  return 'supply chain';
    }
  }

  String _silentSummary(List<FATCategory> cats) {
    final labels = cats.map(_glanceLabel).toList();
    final head = labels.take(4).toList();
    var s = head.join(', ');
    final rest = labels.length - head.length;
    if (rest > 0) s += ' — and $rest more';
    return s;
  }

  ({String line, IconData icon, Color color}) get _verification {
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
    final disclosed = result.knownCount;
    final partial = result.partialCount;
    final silent = _silentCategories;
    final v = _verification;

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
          // FSIS baseline — the neutrality anchor, stated for every product.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.shield_outlined, size: 16, color: _disclosureGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meets USDA FSIS minimums — as is required of all federally inspected meat and catfish.',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 16-segment single-color disclosure meter (fuller = more disclosed).
          Row(
            children: List.generate(_totalCategories, (i) {
              return Expanded(
                child: Container(
                  height: 12,
                  margin: EdgeInsets.only(
                      right: i == _totalCategories - 1 ? 0 : 3),
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
              Text('of $_totalCategories categories disclosed',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (partial > 0) ...[
            const SizedBox(height: 4),
            Text('$partial more partially disclosed',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _fatAmber)),
          ],
          if (silent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Silent on: ${_silentSummary(silent)}',
                style: TextStyle(
                    fontSize: 13.5, color: Colors.black.withValues(alpha: 0.7))),
          ],
          const SizedBox(height: 12),
          // How the disclosed claims are backed — factual, strongest tier shown.
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

  bool get _hasEnforcement => _oshaViolation || _epaViolation;

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
              _enforcementBlock(),
              _regulatorStatusRows(),
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

  /// Nearby feedlot / hog-CAFO environmental compliance (EPA ECHO). Mirrors iOS
  /// feedlotProximitySection / hogProximitySection.
  Widget _proximitySection() {
    final p = _proximity!;
    final title = _proximityKind == 'hog CAFO'
        ? 'Nearby Hog Farm Compliance'
        : 'Nearby Feedlot Compliance';
    final mapUrl = _proximityKind == 'hog CAFO'
        ? 'https://farmanimaltransparency.com/pork-supply-chain/pork-enforcement-map/'
        : 'https://farmanimaltransparency.com/beef-supply-chain/feedlot-enforcement-map/';
    Color tierColor(String t) => switch (t) {
          'red' => const Color(0xFFDC2626),
          'orange' => const Color(0xFFEA580C),
          _ => const Color(0xFFCA8A04),
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _fatGreen, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!p.hasNearby)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.verified_outlined,
                          size: 16, color: FATTheme.scanGreen)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'No EPA-flagged $_proximityKind operations with environmental violations within ${p.radiusMiles} miles of this plant.',
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                ])
              else ...[
                Text(
                    '${p.total} $_proximityKind operation${p.total > 1 ? 's' : ''} with environmental violations within ${p.radiusMiles} miles:',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  _tierPill('${p.red} formal', tierColor('red')),
                  const SizedBox(width: 6),
                  _tierPill('${p.orange} significant', tierColor('orange')),
                  const SizedBox(width: 6),
                  _tierPill('${p.yellow} other', tierColor('yellow')),
                ]),
                for (final v in p.violators.take(5)) ...[
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: tierColor(v.tier),
                                shape: BoxShape.circle))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${v.name.isEmpty ? v.permitId : v.name} · ${v.distanceMiles.toStringAsFixed(1)} mi',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800)),
                            Text('${v.tierLabel} — ${v.violationSummary}',
                                style: const TextStyle(fontSize: 12.5)),
                          ]),
                    ),
                  ]),
                ],
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openUrl(mapUrl),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.map_outlined, size: 16, color: Colors.blue),
                  SizedBox(width: 6),
                  Text('View the enforcement map on FAT website',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                ]),
              ),
              if (p.dataDate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${p.dataSource} · ${p.dataDate}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.black.withValues(alpha: 0.55))),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tierPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  /// FSIS public enforcement record (recalls, humane-handling, Salmonella
  /// category, residues) fetched from the FAT backend. Food-safety public
  /// record — kept distinct from the OSHA worker-safety axis.
  Widget _enforcementBlock() {
    if (_processorLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: FATTheme.scanGreen)),
          SizedBox(width: 8),
          Text('Checking FSIS public record…',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    final p = _processor;
    if (p == null) return const SizedBox.shrink();

    final asOf = p.generatedDate != null ? ' (as of ${p.generatedDate})' : '';
    final rows = <Widget>[];

    Widget line(IconData icon, Color color, String label, String detail) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: Colors.black),
                  children: [
                    TextSpan(
                        text: '$label  ',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: detail),
                  ],
                ),
              ),
            ),
          ]),
        );

    if (p.hasRecalls) {
      rows.add(line(Icons.warning_amber_rounded, const Color(0xFFC0392B),
          'Recalls', '${p.recallCount} on record'));
    }
    final hh = p.humaneHandling;
    if (hh.isNotEmpty) {
      final top = hh.first;
      final detail = top.taskName.isNotEmpty
          ? '${hh.length} noncompliance record(s) — e.g. ${top.taskName}${top.regs.isNotEmpty ? ' (9 CFR ${top.regs})' : ''}'
          : '${hh.length} noncompliance record(s)';
      rows.add(line(Icons.pets, const Color(0xFFEF8A2B), 'Humane handling',
          detail));
    }
    if (p.salmonellaCategory != null) {
      rows.add(line(Icons.science_outlined, const Color(0xFFEF8A2B),
          'Salmonella category', p.salmonellaCategory!));
    }
    if (p.hasResidues) {
      rows.add(line(Icons.biotech_outlined, const Color(0xFFC0392B),
          'Chemical residue', '${p.residueCount} violation(s) on record'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1, color: Colors.black26),
        const SizedBox(height: 10),
        const Text('FSIS Public Record',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.verified_outlined,
                      size: 16, color: FATTheme.scanGreen)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clean record — no recalls, humane-handling actions, or residue violations on file$asOf.',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ]),
          )
        else ...[
          ...rows,
          if (asOf.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('FSIS data$asOf.',
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.black.withValues(alpha: 0.55))),
            ),
        ],
      ],
    );
  }

  /// Always-visible EPA (ECHO) + OSHA status for the plant. Separate regulatory
  /// axes from FSIS food-safety enforcement — each is stated explicitly so a
  /// clean plant reads "no violations on file" rather than an ambiguous blank
  /// (mirrors iOS ResultsView.regulatorStatusRows).
  Widget _regulatorStatusRows() {
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _epaViolation
            ? row(Icons.warning_amber_rounded, const Color(0xFFEA580C),
                'EPA (ECHO) environmental violations in the last 3 years (12 quarters)')
            : row(Icons.verified_user_outlined, FATTheme.scanGreen,
                'No EPA (ECHO) environmental violations in the last 3 years (12 quarters)'),
        // OSHA data is the plant's full matched DOL enforcement history (not a
        // fixed rolling window) — say "full record on file," not "last N years."
        _oshaViolation
            ? row(Icons.warning_amber_rounded, const Color(0xFFEA580C),
                'OSHA worker-safety violations on record')
            : row(Icons.verified_user_outlined, FATTheme.scanGreen,
                'No OSHA worker-safety violations in the full record on file'),
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
      'Discloses ${result.knownCount} of 16 transparency categories (${result.partialCount} partial). A count of what the label discloses — not a rating of the food.',
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
    // Primary path: render the disclosure card to a PNG and share the image.
    final shared = await shareDisclosureCard(
      context,
      result,
      shareText:
          'FAT Label Analysis — discloses ${result.knownCount} of 16 transparency categories. farmanimaltransparency.com',
    );
    if (shared) return;

    // Fallback: the original text / mailto share when image rendering fails.
    final subject = Uri.encodeComponent(
        'FAT Label Analysis — discloses ${result.knownCount} of 16 categories');
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
