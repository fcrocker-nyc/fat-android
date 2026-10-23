import 'package:flutter/material.dart';
import '../models/fat_models.dart';
import '../theme/fat_theme.dart';
import '../interpreter/meter_card_text.dart';
import '../interpreter/seafood_detail_lines.dart';

/// Full-color shareable evaluation image — Flutter port of iOS
/// `DisclosureShareCard.swift`: the at-a-glance meter card plus the category
/// summary, in the results-screen colors (green disclosed, amber partial,
/// red not disclosed, blue not applicable). Rendered off-screen to a PNG by
/// `share_card_renderer.dart`.
///
/// Why it used to look black-and-white: every pill was the sage brand tint
/// (#C5C9BF, a near-neutral gray-green) at 100/70/40% opacity with black text
/// and no meter or status dots, so the image was effectively grayscale. The
/// rounded card also left transparent corners in the PNG. It now uses the
/// on-screen status colors on an opaque white canvas.
///
/// Handles both meat and seafood (`result.isSeafood`).
class DisclosureShareCard extends StatelessWidget {
  final FATResult result;
  const DisclosureShareCard({super.key, required this.result});

  static const disclosedGreen = Color(0xFF34A853);
  static const notApplicableBlue = Color(0xFF2563EB);
  static const partialAmber = FATTheme.fatAmber;
  static const missingRed = FATTheme.fatRed;
  static const sage = FATTheme.primaryGreen;
  static const double width = 390;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formattedDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  static Color statusColor(DisclosureStatus s) {
    switch (s) {
      case DisclosureStatus.known:
        return disclosedGreen;
      case DisclosureStatus.partial:
        return partialAmber;
      case DisclosureStatus.missing:
        return missingRed;
      case DisclosureStatus.notRequired:
        return notApplicableBlue;
    }
  }

  static String statusText(DisclosureStatus s) {
    switch (s) {
      case DisclosureStatus.known:
        return 'Disclosed';
      case DisclosureStatus.partial:
        return 'Partial';
      case DisclosureStatus.missing:
        return 'Not disclosed';
      case DisclosureStatus.notRequired:
        return 'Not applicable';
    }
  }

  Widget _dot(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  BoxDecoration _outlined() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sage, width: 1.5),
      );

  @override
  Widget build(BuildContext context) {
    final isSeafood = result.isSeafood;
    final statuses = <({String name, DisclosureStatus status})>[];
    final grownIn = isSeafood
        ? SeafoodDetailLines.forResult(result)[SeafoodCategory.farmVesselFishery]
        : null;
    if (isSeafood) {
      for (final c in SeafoodCategory.values) {
        statuses.add((
          name: c.displayName,
          status: result.seafoodCategories[c]?.status ?? DisclosureStatus.missing
        ));
      }
    } else {
      for (final c in FATCategory.values) {
        statuses.add((
          name: c.displayName,
          status: result.categories[c]?.status ?? DisclosureStatus.missing
        ));
      }
    }
    final total = statuses.length;
    final disclosed =
        statuses.where((e) => e.status == DisclosureStatus.known).length;
    final partial =
        statuses.where((e) => e.status == DisclosureStatus.partial).length;
    final missing =
        statuses.where((e) => e.status == DisclosureStatus.missing).length;
    final notApplicable =
        statuses.where((e) => e.status == DisclosureStatus.notRequired).length;
    final naLine =
        isSeafood ? null : MeterCardText.notApplicableLine(result.categories);
    final pillText =
        isSeafood ? null : MeterCardText.claimPillText(result.categories);
    final tier =
        isSeafood ? null : MeterCardText.strongestClaimTier(result.categories);
    final pillColor = tier == ClaimCredibility.verified
        ? disclosedGreen
        : tier == ClaimCredibility.usdaApproved
            ? partialAmber
            : Colors.black.withValues(alpha: 0.55);
    final est = result.detectedEstablishmentNumber;

    Color meterColor(int i) {
      if (i < disclosed) return disclosedGreen;
      if (i < disclosed + notApplicable) {
        return notApplicableBlue.withValues(alpha: 0.35);
      }
      return Colors.black.withValues(alpha: 0.10);
    }

    Widget summaryRow(String title, int n, Color c) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            _dot(c, 11),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black))),
            Text('$n',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ]),
        );

    final header = Row(children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: FATTheme.scanGreen, borderRadius: BorderRadius.circular(6)),
        child: const Text('FAT',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Farm Animal Transparency',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: FATTheme.scanGreen)),
          Text(_formattedDate(result.scannedAt),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.6))),
        ]),
      ),
      if (est != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
              color: disclosedGreen, borderRadius: BorderRadius.circular(20)),
          child: Text('EST. $est',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
    ]);

    final meterCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _outlined(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isSeafood) ...[
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield, size: 15, color: disclosedGreen),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Meets USDA minimums — as is required of all federally inspected meat and catfish.',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        Row(children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                    color: meterColor(i),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$disclosed',
                style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: disclosedGreen)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  notApplicable > 0
                      ? 'of ${total - notApplicable} applicable categories disclosed'
                      : 'of $total categories disclosed',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ),
          ],
        ),
        if (partial > 0)
          Text('$partial more partially disclosed',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: partialAmber)),
        if (naLine != null) ...[
          const SizedBox(height: 4),
          Text(naLine,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: notApplicableBlue)),
        ],
        if (pillText != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: pillColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20)),
            child: Text(pillText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pillColor)),
          ),
        ],
      ]),
    );

    final summaryCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: sage, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What This Label Discloses',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black)),
        summaryRow('Disclosed', disclosed, disclosedGreen),
        summaryRow('Partially disclosed', partial, partialAmber),
        summaryRow('Not disclosed', missing, missingRed),
        if (notApplicable > 0)
          summaryRow('Not applicable', notApplicable, notApplicableBlue),
      ]),
    );

    final rows = <Widget>[];
    for (final e in statuses) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          _dot(statusColor(e.status), 9),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e.name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ),
          const SizedBox(width: 6),
          Text(statusText(e.status),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor(e.status))),
        ]),
      ));
      if (grownIn != null &&
          e.name == SeafoodCategory.farmVesselFishery.displayName) {
        for (final l in grownIn) {
          rows.add(Padding(
            padding: const EdgeInsets.only(left: 17, bottom: 2),
            child: Text(l.text,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.7))),
          ));
        }
      }
    }
    final categoryList = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _outlined(),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );

    // Opaque white canvas, no transparent corners — light mode by construction.
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: 14),
          meterCard,
          const SizedBox(height: 14),
          summaryCard,
          const SizedBox(height: 14),
          categoryList,
          const SizedBox(height: 14),
          Text(
              'A count of what the label discloses — not a rating, endorsement, or certification of the food.',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
