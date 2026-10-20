import 'package:flutter/material.dart';
import '../services/feedlot_proximity_service.dart';
import '../theme/fat_theme.dart';

/// Copy for the Results screen's "Hog Farms Near This Plant" / "Cattle
/// Feedlots Near This Plant" section. Informational only: never a score
/// input. Mirrors iOS NearbyFarmsSection.swift.
class NearbyFarmsCopy {
  static const hogTitle = 'Hog Farms Near This Plant';
  static const feedlotTitle = 'Cattle Feedlots Near This Plant';

  static const hogExplainer =
      'Large hog farms (CAFOs) within 50 miles of the plant that processed this pork, and whether EPA or the state has cited them for environmental violations. This describes the area around the plant. It does not mean this product’s hogs came from these farms, and it does not change the label’s disclosure count.';
  static const feedlotExplainer =
      'Large cattle feedlots within 50 miles of the plant that processed this beef, and whether EPA or the state has cited them for environmental violations. This describes the area around the plant. It does not mean this product’s cattle came from these feedlots, and it does not change the label’s disclosure count.';

  /// Lookup finished without a usable response (network/HTTP/decode error)
  /// and there are no state permit lines.
  static const unavailable =
      'Nearby farm records couldn’t be loaded for this plant right now.';
}

/// What renders under the section heading. Every case draws something, so
/// the heading never stands alone.
enum NearbyFarmsBody {
  /// Lookup not yet started or still in flight.
  loading,

  /// EPA/state response decoded, including a zero-violator response.
  results,

  /// No EPA response, but state permit lines to show.
  permitsOnly,

  /// Lookup finished with no response and there are no permit lines.
  unavailable;

  static NearbyFarmsBody resolve({
    required bool isLoading,
    required bool lookupFinished,
    required bool hasData,
    required bool hasPermitLines,
  }) {
    if (hasData) return NearbyFarmsBody.results;
    if (isLoading || !lookupFinished) return NearbyFarmsBody.loading;
    if (hasPermitLines) return NearbyFarmsBody.permitsOnly;
    return NearbyFarmsBody.unavailable;
  }
}

/// Nearby feedlot / hog-CAFO environmental compliance (EPA ECHO + state
/// permit records). Mirrors iOS feedlotProximitySection / hogProximitySection.
class NearbyFarmsSection extends StatelessWidget {
  final bool isHog;
  final bool isLoading;
  final bool lookupFinished;
  final ProximityResult? result;
  final List<String> permitLines;
  final void Function(String url) onOpenUrl;

  const NearbyFarmsSection({
    super.key,
    required this.isHog,
    required this.isLoading,
    required this.lookupFinished,
    required this.result,
    required this.permitLines,
    required this.onOpenUrl,
  });

  static const _fatGreen = FATTheme.primaryGreen;

  NearbyFarmsBody get body => NearbyFarmsBody.resolve(
        isLoading: isLoading,
        lookupFinished: lookupFinished,
        hasData: result != null,
        hasPermitLines: permitLines.isNotEmpty,
      );

  static Color _tierColor(String t) => switch (t) {
        'red' => const Color(0xFFDC2626),
        'orange' => const Color(0xFFEA580C),
        _ => const Color(0xFFCA8A04),
      };

  Widget _tierPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _fatGreen, borderRadius: BorderRadius.circular(16)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  List<Widget> _resultLines(ProximityResult p, String kind) => [
        if (!p.hasNearby)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.verified_outlined,
                    size: 16, color: FATTheme.scanGreen)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'No EPA-flagged $kind operations with environmental violations within ${p.radiusMiles} miles of this plant.',
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ])
        else ...[
          Text(
              '${p.total} $kind operation${p.total > 1 ? 's' : ''} with environmental violations within ${p.radiusMiles} miles:',
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            _tierPill('${p.red} formal', _tierColor('red')),
            const SizedBox(width: 6),
            _tierPill('${p.orange} significant', _tierColor('orange')),
            const SizedBox(width: 6),
            _tierPill('${p.yellow} other', _tierColor('yellow')),
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
                          color: _tierColor(v.tier), shape: BoxShape.circle))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${v.name.isEmpty ? v.permitId : v.name} · ${v.distanceMiles.toStringAsFixed(1)} mi',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                      Text('${v.tierLabel} — ${v.violationSummary}',
                          style: const TextStyle(fontSize: 12.5)),
                    ]),
              ),
            ]),
          ],
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final kind = isHog ? 'hog CAFO' : 'feedlot';
    final title = isHog ? NearbyFarmsCopy.hogTitle : NearbyFarmsCopy.feedlotTitle;
    final explainer =
        isHog ? NearbyFarmsCopy.hogExplainer : NearbyFarmsCopy.feedlotExplainer;
    final mapUrl = isHog
        ? 'https://farmanimaltransparency.com/pork-supply-chain/pork-enforcement-map/'
        : 'https://farmanimaltransparency.com/beef-supply-chain/feedlot-enforcement-map/';
    final p = result;
    final state = body;

    final Widget content = switch (state) {
      NearbyFarmsBody.loading => _card([
          Row(children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  isHog
                      ? 'Checking nearby hog farm compliance…'
                      : 'Checking nearby feedlot compliance…',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      NearbyFarmsBody.unavailable => _card([
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.error_outline,
                    size: 16, color: Colors.black54)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(NearbyFarmsCopy.unavailable,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      NearbyFarmsBody.results || NearbyFarmsBody.permitsOnly => _card([
          if (p != null) ..._resultLines(p, kind),
          for (final line in permitLines)
            Padding(
              padding: EdgeInsets.only(top: p == null ? 0 : 10),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.description_outlined,
                            size: 16, color: Colors.black54)),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(line, style: const TextStyle(fontSize: 13.5))),
                  ]),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => onOpenUrl(mapUrl),
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
          if (p != null && p.dataDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${p.dataSource} · ${p.dataDate}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.55))),
            ),
        ]),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(explainer,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withValues(alpha: 0.7))),
        const SizedBox(height: 10),
        content,
      ],
    );
  }
}
