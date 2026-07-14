import 'package:flutter/material.dart';
import '../models/fat_models.dart';
import '../theme/fat_theme.dart';

/// Shareable results card — Flutter port of iOS `DisclosureShareCard.swift`.
///
/// A fixed-width (340) white card with a 4px sage-green border that summarizes
/// what a label discloses, one row per transparency category, plus an optional
/// processor (USDA EST.) row and the standard "not a rating" disclaimer. It is
/// rendered off-screen to a PNG and shared as an image (see
/// `share_card_renderer.dart`).
///
/// Handles both meat and seafood results: it reads `result.isSeafood` and
/// iterates the matching category set (`FATCategory` / `SeafoodCategory`),
/// using only fields that exist on `FATResult`.
class DisclosureShareCard extends StatelessWidget {
  final FATResult result;
  const DisclosureShareCard({super.key, required this.result});

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formattedDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  // ── Pill styling — mirrors iOS shareRow (primaryGreen opacity ramp). ──
  Color _pillColor(DisclosureStatus status) {
    switch (status) {
      case DisclosureStatus.known:
        return FATTheme.primaryGreen;
      case DisclosureStatus.partial:
        return FATTheme.primaryGreen.withValues(alpha: 0.7);
      case DisclosureStatus.missing:
        return FATTheme.primaryGreen.withValues(alpha: 0.4);
      case DisclosureStatus.notRequired:
        return Colors.grey.withValues(alpha: 0.4);
    }
  }

  String _detailText(String displayName, DisclosureStatus status) {
    switch (status) {
      case DisclosureStatus.known:
        return 'Disclosed';
      case DisclosureStatus.partial:
        return 'Partially disclosed';
      case DisclosureStatus.missing:
        return '$displayName not disclosed';
      case DisclosureStatus.notRequired:
        return 'Not required by law';
    }
  }

  Widget _shareRow(String displayName, DisclosureStatus status) {
    return Row(
      children: [
        Expanded(
          child: Text(
            displayName,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _pillColor(status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _detailText(displayName, status),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(height: 1, color: Colors.black.withValues(alpha: 0.15));

  @override
  Widget build(BuildContext context) {
    final isSeafood = result.isSeafood;

    // One row per category, mirroring iOS ForEach(FATCategory.allCases).
    final rows = <Widget>[];
    if (isSeafood) {
      for (final c in SeafoodCategory.values) {
        final status =
            result.seafoodCategories[c]?.status ?? DisclosureStatus.missing;
        rows.add(_shareRow(c.displayName, status));
      }
    } else {
      for (final c in FATCategory.values) {
        final status =
            result.categories[c]?.status ?? DisclosureStatus.missing;
        rows.add(_shareRow(c.displayName, status));
      }
    }

    final est = result.detectedEstablishmentNumber;

    // Interleave 14px gaps between the header block, rows, and footer, matching
    // the iOS VStack(spacing: 14).
    final children = <Widget>[
      const Text(
        'Farm Animal Transparency',
        style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
      ),
      Text(
        _formattedDate(result.scannedAt),
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.55)),
      ),
      _divider(),
      ...rows,
      if (est != null) ...[
        _divider(),
        Row(
          children: [
            const Text(
              'Processor',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FATTheme.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'USDA EST. $est',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
          ],
        ),
      ],
      _divider(),
      Text(
        'This summary reflects what the label discloses. It is not a rating, endorsement, or certification.',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.55)),
      ),
    ];

    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(const SizedBox(height: 14));
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FATTheme.primaryGreen, width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: spaced,
      ),
    );
  }
}
