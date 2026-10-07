import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/nc_hog_lagoon_notice.dart';

/// North Carolina hog lagoons — neutral informational card, same look as the
/// Environmental Watch card. Never a score input. Mirrors iOS NCHogLagoonCard.
class NcHogLagoonCard extends StatelessWidget {
  const NcHogLagoonCard({super.key});

  static const _darkBlue = Color(0xFF2C3E50);
  static const _cardBG = Color(0xFFDEE1D7);

  Widget _link(String label, String url) => GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.blue)),
      );

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
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.water_drop_outlined, size: 18, color: _darkBlue),
            SizedBox(width: 6),
            Expanded(
              child: Text(NcHogLagoonNotice.title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue)),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(NcHogLagoonNotice.body,
              style: TextStyle(fontSize: 13.5, color: Colors.black)),
          const SizedBox(height: 8),
          const Text(NcHogLagoonNotice.caveat,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
          const SizedBox(height: 8),
          _link(NcHogLagoonNotice.sourceLabel, NcHogLagoonNotice.sourceUrl),
          const SizedBox(height: 6),
          _link(NcHogLagoonNotice.permitListLabel,
              NcHogLagoonNotice.permitListUrl),
        ],
      ),
    );
  }
}
