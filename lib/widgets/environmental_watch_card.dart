import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/environmental_watch_service.dart';

/// Environmental Watch card — active environmental litigation/settlement
/// matters involving the product's owner or processor. INFORMATIONAL ONLY:
/// never a score input, and the copy must keep allegations distinct from
/// adjudicated findings. Shared by meat and seafood results screens.
/// Mirrors iOS EnvironmentalWatchCard.
class EnvironmentalWatchCard extends StatelessWidget {
  final List<EnvWatchMatter> matters;
  const EnvironmentalWatchCard({super.key, required this.matters});

  static const _darkBlue = Color(0xFF2C3E50);
  static const _cardBG = Color(0xFFDEE1D7);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBG,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.balance, size: 18, color: _darkBlue),
            SizedBox(width: 6),
            Text('Environmental Watch',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _darkBlue)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'A company connected to this product is a party or subject in an '
            'environmental matter FAT tracks:',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.black),
          ),
          for (final m in matters) ...[
            const SizedBox(height: 10),
            Text(m.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _darkBlue, borderRadius: BorderRadius.circular(999)),
              child: Text(m.classification,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(height: 4),
            Text(m.status,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
            const SizedBox(height: 4),
            Text(m.summary,
                style: const TextStyle(fontSize: 13, color: Colors.black)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(m.url),
                  mode: LaunchMode.externalApplication),
              child: const Text('Follow this matter on the FAT website',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Informational only — this never changes the product\'s FAT score. '
            'Matters classified as litigation pending are allegations; no court '
            'has adjudicated them. Only finalized enforcement records (EPA, '
            'OSHA) carry scoring penalties.',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}
