import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/establishments_service.dart';
import '../services/fsis_plant_names.dart';
import '../theme/fat_theme.dart';

// UI for fat/v1/establishments results. Mirrors the SwiftUI views in
// iOS FATAppMVP2/EstablishmentsService.swift.

const _disclosureGreen = Color(0xFF34A853);
const _darkBlue = Color(0xFF2C3E50);

Future<void> _open(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Counts block for one plant (used when the digits-keyed enforcement detail
/// can't be confirmed for this plant).
class EstablishmentRecordRows extends StatelessWidget {
  final FatEstablishment plant;
  const EstablishmentRecordRows({super.key, required this.plant});

  Widget _row(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = plant;
    const warn = Color(0xFFEA580C);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(Icons.warning_amber_rounded, p.recalls > 0 ? warn : _disclosureGreen,
            'Recalls: ${p.recalls}'),
        _row(Icons.campaign_outlined,
            p.publicHealthAlerts > 0 ? warn : _disclosureGreen,
            'Public health alerts: ${p.publicHealthAlerts}'),
        _row(Icons.checklist, _disclosureGreen,
            'Inspection tasks: ${p.inspectionTasks} (noncompliance records: ${p.noncomplianceRecords}, memoranda of interview: ${p.memorandaOfInterview})'),
        _row(Icons.biotech_outlined,
            p.residueViolations > 0 ? warn : _disclosureGreen,
            'Residue violations: ${p.residueViolations}'),
        if (p.salmonellaLine != null)
          _row(Icons.science_outlined, _disclosureGreen,
              'Salmonella category — ${p.salmonellaLine}'),
        if (p.latestRecallLine != null)
          _row(Icons.history, warn, 'Latest recall: ${p.latestRecallLine}'),
      ],
    );
  }
}

/// One plant card for the Lookup tab.
class EstablishmentPlantCard extends StatelessWidget {
  final FatEstablishment plant;
  const EstablishmentPlantCard({super.key, required this.plant});

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: _disclosureGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = plant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: FATTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name.isEmpty ? FsisPlantNames.notOnFileText : p.name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _disclosureGreen,
                borderRadius: BorderRadius.circular(20)),
            child: Text('USDA EST. ${p.establishmentNumber}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          if (p.fullAddress.isNotEmpty) _line(Icons.location_on, p.fullAddress),
          if (p.size != null) _line(Icons.business, 'HACCP Size: ${p.size}'),
          if (p.activityList.isNotEmpty)
            _line(Icons.settings, p.activityList.join(', ')),
          if (p.dba != null && p.dba != p.name)
            _line(Icons.sell, 'Also known as: ${p.dba}'),
          _line(
              Icons.account_tree_outlined,
              p.parentCompany != null
                  ? 'Parent company: ${p.parentCompany}'
                  : 'No parent mapping on file'),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.black26),
          const SizedBox(height: 4),
          EstablishmentRecordRows(plant: p),
          if (p.recordUrl != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _open(p.recordUrl),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.public, size: 16, color: Colors.blue),
                SizedBox(width: 6),
                Text('Full FSIS record',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Scan results: neutral card when several FSIS plants share the scanned
/// number and the label didn't say which one. No single plant's record shown.
class SharedNumberPlantsCard extends StatelessWidget {
  final List<FatEstablishment> plants;
  const SharedNumberPlantsCard({super.key, required this.plants});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info, size: 18, color: _darkBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(EstablishmentsService.sharedHeadline(plants.length),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        for (final p in plants)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name.isEmpty ? FsisPlantNames.notOnFileText : p.name,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                    '${p.establishmentNumber} · ${p.cityState} · Recalls: ${p.recalls}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
