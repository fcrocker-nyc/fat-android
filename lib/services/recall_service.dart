// FSIS recall lookup.
//
// Queries FAT's server-side proxy for the FSIS Recall & Public Health Alert API
// (https://www.fsis.usda.gov/fsis/api/recall/v/1). The app does not call FSIS
// directly: the agency's edge returns 403 to non-browser clients, so the FAT
// site fetches, caches and re-serves it — the same pattern the FSIS
// inspection-results and OSHA lookups already use.
//
// Works for a DOMESTIC establishment number and for a FOREIGN establishment
// mark (e.g. "IT 1937 L"), because FSIS quotes the foreign mark verbatim in the
// recall summary — an imported product has no USDA establishment number to
// match on.

import 'dart:convert';
import 'package:http/http.dart' as http;

class RecallRecord {
  final String recallNumber;
  final String title;
  final String url;
  final String date;
  final String classification;
  final String riskLevel;
  final String type;
  final bool active;
  final List<String> reason;
  final List<String> states;
  final List<String> establishment;
  final String summary;

  const RecallRecord({
    required this.recallNumber,
    required this.title,
    required this.url,
    required this.date,
    required this.classification,
    required this.riskLevel,
    required this.type,
    required this.active,
    required this.reason,
    required this.states,
    required this.establishment,
    required this.summary,
  });

  static List<String> _strings(dynamic v) => v is List
      ? v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
      : const [];

  factory RecallRecord.fromJson(Map<String, dynamic> j) => RecallRecord(
        recallNumber: (j['recall_number'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        classification: (j['classification'] ?? '').toString(),
        riskLevel: (j['risk_level'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        active: j['active'] == true,
        reason: _strings(j['reason']),
        states: _strings(j['states']),
        establishment: _strings(j['establishment']),
        summary: (j['summary'] ?? '').toString(),
      );

  /// Class I is FSIS's highest hazard tier.
  bool get isClassI => classification.toUpperCase().contains('CLASS I') &&
      !classification.toUpperCase().contains('CLASS II');
}

class RecallCheck {
  final String est;
  final int matchCount;
  final int activeCount;
  final List<RecallRecord> matches;

  const RecallCheck({
    required this.est,
    required this.matchCount,
    required this.activeCount,
    required this.matches,
  });

  bool get hasActive => activeCount > 0;
  List<RecallRecord> get activeMatches =>
      matches.where((m) => m.active).toList();
}

class RecallService {
  RecallService._();
  static final RecallService instance = RecallService._();

  static const String _base =
      'https://farmanimaltransparency.com/wp-json/fat/v1/recall-check';

  final Map<String, RecallCheck?> _cache = {};

  /// Look up recalls for an establishment identifier — domestic ("199",
  /// "P-7418") or foreign ("IT1937L"). Returns null on any network/parse
  /// failure, so a lookup outage never blocks or alters a scan result.
  Future<RecallCheck?> check(String est) async {
    final key = est.trim().toUpperCase();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final res = await http
          .get(Uri.parse('$_base?est=${Uri.encodeQueryComponent(key)}'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _cache[key] = null;
        return null;
      }
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        _cache[key] = null;
        return null;
      }
      final raw = body['matches'];
      final matches = raw is List
          ? raw
              .whereType<Map>()
              .map((m) => RecallRecord.fromJson(m.cast<String, dynamic>()))
              .toList()
          : <RecallRecord>[];
      final check = RecallCheck(
        est: key,
        matchCount: (body['match_count'] as num?)?.toInt() ?? matches.length,
        activeCount: (body['active_count'] as num?)?.toInt() ??
            matches.where((m) => m.active).length,
        matches: matches,
      );
      _cache[key] = check;
      return check;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }
}
