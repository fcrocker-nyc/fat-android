import 'package:flutter/material.dart';
import '../models/fat_models.dart';
import '../theme/fat_theme.dart';

class ResultsScreen extends StatelessWidget {
  final FATResult result;
  const ResultsScreen({super.key, required this.result});

  // ── Colors ──────────────────────────────────────────────────────────────
  static const _disclosureGreen = Color(0xFF34A853);
  static const _fatAmber        = FATTheme.fatAmber;
  static const _fatRed          = FATTheme.fatRed;

  Color _statusColor(DisclosureStatus s) {
    switch (s) {
      case DisclosureStatus.known:    return _disclosureGreen;
      case DisclosureStatus.partial:  return _fatAmber;
      default:                        return _fatRed;
    }
  }

  Color _credColor(ClaimCredibility c) {
    switch (c) {
      case ClaimCredibility.verified:           return _disclosureGreen;
      case ClaimCredibility.usdaApproved:       return _fatAmber;
      case ClaimCredibility.producerAffidavit:  return Colors.orange;
      case ClaimCredibility.labelClaimOnly:     return _fatRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Label Results'),
        backgroundColor: FATTheme.primaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scoreBanner(),
            const SizedBox(height: 12),
            if (!result.regulatoryPassed) _fsisMissingBanner(),
            if (result.estMissing) _estMissingBanner(),
            const SizedBox(height: 4),
            _disclosureSummary(),
            const SizedBox(height: 16),
            const Text('Transparency Categories',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...FATCategory.values.map(_categoryCard),
          ],
        ),
      ),
    );
  }

  // ── Score Banner ─────────────────────────────────────────────────────────

  Widget _scoreBanner() {
    final score = result.fatScore;
    final grade = result.grade;
    final gradeColor = result.gradeColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // Grade circle
          CircleAvatar(
            radius: 36,
            backgroundColor: gradeColor,
            child: Text(grade,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FAT Score: ${score.toStringAsFixed(0)} / 100',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 10,
                    backgroundColor: Colors.white.withAlpha(180),
                    color: gradeColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(result.regulatoryPassed
                    ? '✓ USDA/FSIS required language present'
                    : '⚠ USDA/FSIS required language not detected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: result.regulatoryPassed ? _disclosureGreen : _fatRed,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Warnings ─────────────────────────────────────────────────────────────

  Widget _fsisMissingBanner() => _warningBanner(
    Icons.warning_amber_rounded,
    'FSIS required language not detected on this label.',
  );

  Widget _estMissingBanner() => _warningBanner(
    Icons.error_outline,
    'No USDA establishment number detected. FSIS requires one on all federally-inspected meat products (9 CFR 317.2).',
  );

  Widget _warningBanner(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: _fatRed),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14))),
        ],
      ),
    );
  }

  // ── Disclosure Summary ───────────────────────────────────────────────────

  Widget _disclosureSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryDot(_disclosureGreen, 'Disclosed', result.knownCount),
          _summaryDot(_fatAmber, 'Partial', result.partialCount),
          _summaryDot(_fatRed, 'Not Disclosed', result.missingCount),
        ],
      ),
    );
  }

  Widget _summaryDot(Color color, String label, int count) {
    return Row(
      children: [
        CircleAvatar(radius: 7, backgroundColor: color),
        const SizedBox(width: 6),
        Text('$label: $count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Category Card ────────────────────────────────────────────────────────

  Widget _categoryCard(FATCategory category) {
    final value = result.categories[category];
    final status = value?.status ?? DisclosureStatus.missing;
    final accentColor = _statusColor(status);

    String statusText;
    switch (status) {
      case DisclosureStatus.known:       statusText = value?.value ?? 'Disclosed'; break;
      case DisclosureStatus.partial:     statusText = value?.value ?? 'Partially disclosed'; break;
      case DisclosureStatus.missing:     statusText = '${category.displayName} not disclosed.'; break;
      case DisclosureStatus.notRequired: statusText = 'Not required by federal law.'; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(statusText,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (value?.credibility != null) ...[
                      const SizedBox(height: 6),
                      _credibilityBadge(value!.credibility!, value.credibilityNote),
                    ],
                    if (category == FATCategory.supplyChainIntermediary &&
                        value?.captivityStatus != null)
                      _captivityBadge(value!.captivityStatus!),
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
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_credIcon(cred), size: 14, color: color),
              const SizedBox(width: 5),
              Text(cred.displayName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _captivityBadge(CaptivityStatus captivity) {
    Color color;
    switch (captivity) {
      case CaptivityStatus.packerOwned:       color = _fatRed; break;
      case CaptivityStatus.packerContracted:  color = Colors.orange; break;
      case CaptivityStatus.independent:       color = _disclosureGreen; break;
      case CaptivityStatus.undisclosed:       color = Colors.grey; break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(captivity.displayName,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  IconData _credIcon(ClaimCredibility cred) {
    switch (cred) {
      case ClaimCredibility.verified:           return Icons.verified;
      case ClaimCredibility.usdaApproved:       return Icons.approval;
      case ClaimCredibility.producerAffidavit:  return Icons.description;
      case ClaimCredibility.labelClaimOnly:     return Icons.info_outline;
    }
  }

  // ── Share ────────────────────────────────────────────────────────────────

  void _share(BuildContext context) {
    final lines = <String>['Farm Animal Transparency (FAT)', 'FAT Score: ${result.fatScore.toStringAsFixed(0)}/100  Grade: ${result.grade}', ''];
    for (final cat in FATCategory.values) {
      final r = result.categories[cat] ?? FATCategoryResult.missing;
      var line = '${cat.displayName}: ${r.status.name.toUpperCase()}';
      if (r.credibility != null) line += ' [${r.credibility!.displayName}]';
      lines.add(line);
    }
    lines.add('');
    lines.add('Generated by the FAT App — farmanimaltransparency.com');

    final text = lines.join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share text ready (${text.length} chars) — integrate share_plus for full share sheet.')),
    );
  }
}
