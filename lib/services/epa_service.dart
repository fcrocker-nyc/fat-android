import 'dart:convert';
import 'package:http/http.dart' as http;

import 'establishments_service.dart';
import 'processor_service.dart';

/// EPA environmental-enforcement lookup (ECHO). Mirrors iOS EpaService in
/// FATAppMVP2/ProcessorService.swift.
///
/// Data: fat_epa_index.json (EPA ECHO_EXPORTER bulk matched to FSIS est-cores
/// by fat-epa/match_bulk.py), served from this repo via jsDelivr. Each
/// establishment entry carries registry_id, fac_name, fac_city, fac_state,
/// naics, match_confidence (high/medium), a CWA/CAA/RCRA summary and
/// has_violations; "index" maps every number token ("244i", "199gp6620",
/// "6620") to its entry. An entry is a violation iff has_violations &&
/// match_confidence == "high" — exactly the lean fat_epa_violations.json
/// "cores" list, which is the fallback (it carries no location).
///
/// FSIS reuses numbers across plants (244 = Storm Lake IA, Logansport IN, …),
/// so an entry applies only to the RESOLVED plant: same number core AND same
/// city + state. An entry without a location (fallback list) applies only when
/// the number isn't shared, or when it names the plant's own letter-suffixed
/// core ("244i"). For a shared number the label didn't resolve: a neutral line
/// when one of the candidates matches.
enum EpaOutcome {
  /// No EPA violations matched (or no data) — the normal clean line.
  clean,

  /// The resolved plant matched — violation line.
  violation,

  /// Shared number, at least one candidate matched — neutral line.
  sharedOnFile,
}

class EpaEntry {
  final String key;
  final String? city;
  final String? state;
  final bool violating;
  const EpaEntry(this.key, this.city, this.state, this.violating);
}

/// The plant an EPA entry must match: number cores (type letters stripped,
/// lowercase — "M245C+V245C" → ["245c"]) plus city and state.
class EpaPlant {
  final List<String> cores;
  final String? city;
  final String? state;
  const EpaPlant(this.cores, this.city, this.state);

  factory EpaPlant.fromEstablishment(FatEstablishment p) {
    final cores = <String>[];
    for (final t in p.numberTokens) {
      final c = EstablishmentsService.core(t).toLowerCase();
      if (c.isNotEmpty && !cores.contains(c)) cores.add(c);
    }
    return EpaPlant(cores, p.city, p.state);
  }

  factory EpaPlant.fromRecord(ProcessorRecord r) {
    final plant = r.endpointPlant;
    if (plant != null) return EpaPlant.fromEstablishment(plant);
    var cores = <String>[];
    final full = r.fullEstNumber;
    if (full != null) {
      cores = full
          .toUpperCase()
          .split(RegExp(r'[+,/ ]'))
          .map((t) => EstablishmentsService.core(t.replaceAll('-', ''))
              .toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    if (cores.isEmpty) {
      final c = EstablishmentsService.core(
              r.estNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''))
          .toLowerCase();
      if (c.isNotEmpty) cores = [c];
    }
    return EpaPlant(cores, r.city.isEmpty ? null : r.city,
        r.state.isEmpty ? null : r.state);
  }
}

class EpaService {
  static const sharedOnFileText =
      'EPA (ECHO) violations are on file for one of the plants that share this number — match the city on the package to know which';

  static Map<String, EpaEntry>? _entries;
  static const _indexUrl =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/epa/fat_epa_index.json';
  static const _listUrl =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/epa/fat_epa_violations.json';
  static final _tok = RegExp(r'\d{1,7}[a-z]?');

  /// EPA outcome for a scan. [plant] = the resolved plant (null when unknown);
  /// [numberShared] = several FSIS plants carry the number's digits;
  /// [sharedPlants] = candidates when the label didn't say which plant.
  /// Fail-open: any network/parse error → clean.
  static Future<EpaOutcome> outcome(String? est,
      {EpaPlant? plant,
      bool numberShared = false,
      List<EpaPlant> sharedPlants = const []}) async {
    final m = await _load();
    if (m == null || m.isEmpty) return EpaOutcome.clean;
    return evaluate(m, est,
        plant: plant, numberShared: numberShared, sharedPlants: sharedPlants);
  }

  // ── Pure helpers (unit-tested) ─────────────────────────────────────────

  static EpaOutcome evaluate(Map<String, EpaEntry> entries, String? est,
      {EpaPlant? plant,
      bool numberShared = false,
      List<EpaPlant> sharedPlants = const []}) {
    if (sharedPlants.isNotEmpty) {
      return sharedPlants.any((p) => matches(entries, p, numberShared: true))
          ? EpaOutcome.sharedOnFile
          : EpaOutcome.clean;
    }
    if (plant != null) {
      return matches(entries, plant, numberShared: numberShared)
          ? EpaOutcome.violation
          : EpaOutcome.clean;
    }
    // No plant identity at all (offline, no website record): the number alone.
    if (est == null || est.trim().isEmpty) return EpaOutcome.clean;
    for (final m in _tok.allMatches(est.toLowerCase())) {
      final t = m.group(0)!;
      if (entries[t]?.violating == true) return EpaOutcome.violation;
      final digits = t.replaceAll(RegExp(r'[a-z]'), '');
      if (digits.isNotEmpty && entries[digits]?.violating == true) {
        return EpaOutcome.violation;
      }
    }
    return EpaOutcome.clean;
  }

  /// Does any violating EPA entry belong to this plant?
  static bool matches(Map<String, EpaEntry> entries, EpaPlant plant,
      {required bool numberShared}) {
    for (final core in plant.cores) {
      final digits = core.replaceAll(RegExp(r'[^0-9]'), '');
      final keys = [
        (core, RegExp(r'[a-z]').hasMatch(core)),
        (digits, false),
      ];
      for (final (key, letterExact) in keys) {
        if (key.isEmpty) continue;
        final e = entries[key];
        if (e == null || !e.violating) continue;
        final ec = e.city, es = e.state, pc = plant.city, ps = plant.state;
        if (ec != null && es != null && pc != null && ps != null) {
          if (sameLocation(ec, es, pc, ps)) return true;
          continue;
        }
        // One side carries no location: only a plant-specific key counts.
        if (!numberShared || letterExact) return true;
      }
    }
    return false;
  }

  /// "SAINT JOSEPH" ≈ "St Joseph"; "CITY OF SIOUX CITY" ≈ "Sioux City";
  /// "VINELAND CITY" ≈ "Vineland". State must be equal.
  static bool sameLocation(
      String city1, String state1, String city2, String state2) {
    final s1 = state1.trim().toUpperCase(), s2 = state2.trim().toUpperCase();
    if (s1.isEmpty || s1 != s2) return false;
    final a = normCity(city1), b = normCity(city2);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || ' $a '.contains(' $b ') || ' $b '.contains(' $a ');
  }

  static String normCity(String s) {
    var t = s
        .toLowerCase()
        .replaceAll('saint ', 'st ')
        .replaceAll('st. ', 'st ')
        .replaceAll(RegExp(r'[^a-z]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .join(' ');
    if (t.startsWith('city of ')) t = t.substring('city of '.length);
    if (t.endsWith(' city')) t = t.substring(0, t.length - ' city'.length);
    return t;
  }

  /// fat_epa_index.json → token → entry.
  static Map<String, EpaEntry>? parseIndex(String body) {
    try {
      final obj = jsonDecode(body);
      if (obj is! Map || obj['establishments'] is! Map) return null;
      final byKey = <String, EpaEntry>{};
      (obj['establishments'] as Map).forEach((k, v) {
        if (v is! Map) return;
        String? s(String f) {
          final t = (v[f] ?? '').toString().trim();
          return t.isEmpty ? null : t;
        }

        final key = '$k'.toLowerCase();
        byKey[key] = EpaEntry(
            key,
            s('fac_city'),
            s('fac_state'),
            v['has_violations'] == true &&
                s('match_confidence')?.toLowerCase() == 'high');
      });
      final out = Map<String, EpaEntry>.from(byKey);
      final idx = obj['index'];
      if (idx is Map) {
        idx.forEach((tok, key) {
          final e = byKey['$key'.toLowerCase()];
          if (e != null) out['$tok'.toLowerCase()] = e;
        });
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  /// fat_epa_violations.json (fallback, no location) → token → entry.
  static Map<String, EpaEntry>? parseViolationsList(String body) {
    try {
      final obj = jsonDecode(body);
      if (obj is! Map || obj['cores'] is! List) return null;
      return {
        for (final c in obj['cores'] as List)
          '$c'.toLowerCase(): EpaEntry('$c'.toLowerCase(), null, null, true),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetch(String url) async {
    try {
      final r =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return r.statusCode == 200 ? r.body : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, EpaEntry>?> _load() async {
    if (_entries != null) return _entries;
    final idx = await _fetch(_indexUrl);
    _entries = idx == null ? null : parseIndex(idx);
    if (_entries == null) {
      final list = await _fetch(_listUrl);
      _entries = list == null ? null : parseViolationsList(list);
    }
    return _entries;
  }
}
