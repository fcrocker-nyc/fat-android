import 'dart:convert';
import 'package:http/http.dart' as http;

/// Environmental-proximity lookup: EPA-ECHO CAFO/feedlot violators near a
/// processor. Hits the SAME FAT backend endpoints the iOS app uses:
///   feedlot-proximity.php?lat&lon&miles=50   (beef processors)
///   hog-proximity.php?lat&lon&miles=75       (pork processors)
/// We pass lat/lon straight from the establishment record (ProcessorService),
/// which is the reliable path. Fail-open: any error returns null.
class FeedlotProximityService {
  static const _base =
      'https://farmanimaltransparency.com/wp-content/plugins/fat-fsis-data-manager';

  static Future<ProximityResult?> feedlot(double lat, double lon) =>
      _fetch('feedlot-proximity.php', lat, lon, 50);

  static Future<ProximityResult?> hog(double lat, double lon) =>
      _fetch('hog-proximity.php', lat, lon, 75);

  static Future<ProximityResult?> _fetch(
      String path, double lat, double lon, int miles) async {
    try {
      final uri = Uri.parse('$_base/$path?lat=$lat&lon=$lon&miles=$miles');
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body);
      if (d is! Map) return null;
      return ProximityResult.fromJson(Map<String, dynamic>.from(d));
    } catch (_) {
      return null;
    }
  }
}

class ProximityResult {
  final bool hasNearby;
  final int total;
  final int radiusMiles;
  final int red, orange, yellow;
  final String dataSource;
  final String dataDate;
  final List<Violator> violators;

  ProximityResult({
    required this.hasNearby,
    required this.total,
    required this.radiusMiles,
    required this.red,
    required this.orange,
    required this.yellow,
    required this.dataSource,
    required this.dataDate,
    required this.violators,
  });

  factory ProximityResult.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['summary'] ?? {});
    int i(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return ProximityResult(
      hasNearby: j['has_nearby_violators'] == true,
      total: i(j['total_violators']),
      radiusMiles: i(j['radius_miles']),
      red: i(s['red']),
      orange: i(s['orange']),
      yellow: i(s['yellow']),
      dataSource: (j['data_source'] ?? '').toString(),
      dataDate: (j['data_date'] ?? '').toString(),
      violators: ((j['violators'] as List?) ?? const [])
          .map((e) => Violator.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class Violator {
  final String name;
  final String permitId;
  final String city;
  final String county;
  final String state;
  final double distanceMiles;
  final String tier; // red / orange / yellow
  final int formalActions;
  final int significantNc;
  final int quarterlyNc;
  final int dmrViolations;
  final int violations90d;
  final int informalActions;

  Violator({
    required this.name,
    required this.permitId,
    required this.city,
    required this.county,
    required this.state,
    required this.distanceMiles,
    required this.tier,
    required this.formalActions,
    required this.significantNc,
    required this.quarterlyNc,
    required this.dmrViolations,
    required this.violations90d,
    required this.informalActions,
  });

  factory Violator.fromJson(Map<String, dynamic> j) {
    int i(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    double d(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return Violator(
      name: (j['name'] ?? '').toString(),
      permitId: (j['permit_id'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      county: (j['county'] ?? '').toString(),
      state: (j['state'] ?? '').toString(),
      distanceMiles: d(j['distance_miles']),
      tier: (j['violation_tier'] ?? 'yellow').toString(),
      formalActions: i(j['formal_actions']),
      significantNc: i(j['significant_nc']),
      quarterlyNc: i(j['quarterly_nc']),
      dmrViolations: i(j['dmr_violations']),
      violations90d: i(j['violations_90d']),
      informalActions: i(j['informal_actions']),
    );
  }

  String get tierLabel => switch (tier) {
        'red' => 'Formal Enforcement',
        'orange' => 'Significant Non-Compliance',
        _ => 'Non-Compliance',
      };

  String get violationSummary {
    final parts = <String>[];
    if (formalActions > 0) {
      parts.add('$formalActions formal enforcement action${formalActions > 1 ? 's' : ''}');
    }
    if (significantNc > 0) parts.add('$significantNc significant non-compliance');
    if (quarterlyNc > 0) parts.add('$quarterlyNc quarterly non-compliance');
    if (dmrViolations > 0) {
      parts.add('$dmrViolations DMR violation${dmrViolations > 1 ? 's' : ''}');
    }
    if (violations90d > 0) {
      parts.add('$violations90d violation${violations90d > 1 ? 's' : ''} in last 90 days');
    }
    if (informalActions > 0) {
      parts.add('$informalActions informal action${informalActions > 1 ? 's' : ''}');
    }
    return parts.isEmpty ? 'Environmental violation on record' : parts.join(' • ');
  }
}
