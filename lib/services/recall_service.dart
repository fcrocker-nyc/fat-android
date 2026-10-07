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

import 'establishments_service.dart';

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

// ── Plant-specific recall display ────────────────────────────────────────
//
// The recall-check proxy matches on the number as printed, and FSIS reuses
// digits across plants (244 = Storm Lake IA pork, New Oxford PA turkey, …), so
// a bare-digits check can return another plant's recall. For a domestic EST:
// - resolved plant → only records that belong to it (its own latest recall
//   number, or a notice naming its city), else the endpoint's own
//   latest_recall for that plant;
// - shared number the label didn't resolve → no single recall; a neutral line
//   when any candidate plant has recalls or public health alerts on file;
// - no resolution (offline) → the proxy result as before.
// Foreign establishment marks are unchanged. Mirrors iOS RecallResolver.

enum RecallDisplayKind { hidden, records, sharedOnFile }

class RecallDisplay {
  final RecallDisplayKind kind;
  final RecallCheck? check;
  const RecallDisplay(this.kind, [this.check]);
}

class RecallResolver {
  static const sharedOnFileText =
      'Recalls or public health alerts are on file for one of the plants that share this number — match the city on the package to know which';

  /// Proxy lookup key: the resolved plant's own number core ("245C"), else
  /// the token on the label.
  static String lookupKey(String token, FatEstablishment? plant) {
    final toks = plant?.numberTokens ?? const <String>[];
    if (toks.isEmpty) return token;
    final c = EstablishmentsService.core(toks.first);
    return c.isEmpty ? token : c;
  }

  static RecallDisplay display(RecallCheck? check,
      {required bool domestic,
      FatEstablishment? plant,
      List<FatEstablishment> shared = const []}) {
    RecallDisplay asIs() => (check != null && check.matchCount > 0)
        ? RecallDisplay(RecallDisplayKind.records, check)
        : const RecallDisplay(RecallDisplayKind.hidden);
    if (!domestic) return asIs();
    if (shared.isNotEmpty) {
      return shared.any((p) => p.recalls > 0 || p.publicHealthAlerts > 0)
          ? const RecallDisplay(RecallDisplayKind.sharedOnFile)
          : const RecallDisplay(RecallDisplayKind.hidden);
    }
    if (plant == null) return asIs();
    final kept = <RecallRecord>[];
    final seen = <String>{};
    for (final r in check?.matches ?? const <RecallRecord>[]) {
      if (!belongs(r, plant)) continue;
      if (seen.add(r.recallNumber.isEmpty ? r.title : r.recallNumber)) {
        kept.add(r);
      }
    }
    if (kept.isEmpty && plant.latestRecall != null) {
      final rec = recordFrom(plant.latestRecall!, plant);
      if (rec != null) kept.add(rec);
    }
    if (kept.isEmpty) return const RecallDisplay(RecallDisplayKind.hidden);
    return RecallDisplay(
        RecallDisplayKind.records,
        RecallCheck(
            est: plant.establishmentNumber,
            matchCount: kept.length,
            activeCount: kept.where((r) => r.active).length,
            matches: kept));
  }

  static String _words(String s) =>
      ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ' ').split(' ').where((w) => w.isNotEmpty).join(' ')} ';

  /// A proxy record belongs to the plant when it is the plant's own latest
  /// recall number, or its notice names the plant's city.
  static bool belongs(RecallRecord r, FatEstablishment plant) {
    final n = plant.latestRecall?.recallNumber;
    if (n != null && n.isNotEmpty && n.toUpperCase() == r.recallNumber.toUpperCase()) {
      return true;
    }
    final city = plant.city;
    if (city == null || city.trim().isEmpty) return false;
    return _words('${r.title} ${r.summary}').contains(_words(city));
  }

  static RecallRecord? recordFrom(
      FatEstablishmentRecall lr, FatEstablishment plant) {
    final title = lr.title ?? lr.reason ?? '';
    if ((lr.recallNumber ?? '').isEmpty && title.isEmpty) return null;
    final type = lr.type ?? '';
    final t = type.toLowerCase();
    return RecallRecord(
      recallNumber: lr.recallNumber ?? '',
      title: title,
      url: lr.url ?? '',
      date: lr.date ?? '',
      classification: lr.recallClass ?? '',
      riskLevel: '',
      type: type,
      active: t.contains('active') && !t.contains('closed'),
      reason: [if (lr.reason != null) lr.reason!],
      states: const [],
      establishment: [plant.name],
      summary: '',
    );
  }
}
