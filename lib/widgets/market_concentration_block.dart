import 'package:flutter/material.dart';
import '../data/market_concentration.dart';

/// Compact "Market concentration" block near the top of a meat result
/// (mirrors iOS MarketConcentrationBlock). Informational only.
class MarketConcentrationBlock extends StatelessWidget {
  final MarketConcentrationSummary summary;
  final VoidCallback? onSeeDetails;
  const MarketConcentrationBlock(
      {super.key, required this.summary, this.onSeeDetails});

  static const _ink = Color(0xFF1B2938);
  static const _alertInk = Color(0xFFB45309);

  Color get _classColor {
    final hhi = MarketHHI.estimatedFull(summary.species);
    if (hhi < 1500) return const Color(0xFF27AE60);
    if (hhi < 2500) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ink.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bar_chart, size: 16, color: _classColor),
            const SizedBox(width: 6),
            Text(MarketConcentrationSummary.title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: Colors.black.withValues(alpha: 0.55))),
          ]),
          const SizedBox(height: 8),
          Text(summary.marketLine,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
          const SizedBox(height: 8),
          Text(summary.companyLine,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.bold, color: _ink)),
          if (summary.foreignLine != null) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.public, size: 16, color: _alertInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(summary.foreignLine!,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _alertInk)),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          Text('${summary.basisLine} ${MarketConcentrationSummary.sourceLine}',
              style: TextStyle(
                  fontSize: 11, color: Colors.black.withValues(alpha: 0.55))),
          if (onSeeDetails != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSeeDetails,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('See ownership details',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                SizedBox(width: 4),
                Icon(Icons.arrow_downward, size: 14, color: Colors.blue),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
