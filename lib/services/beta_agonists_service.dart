import 'dart:convert';
import 'package:http/http.dart' as http;

/// A verified AMS "Never Fed Beta Agonists" record for an establishment.
class BetaAgonistsInfo {
  final String entity;
  final String species;
  final List<String> markets; // verified export markets, e.g. ['China', 'Russian Federation']
  final String copackerOf; // sponsoring brand if a co-packer facility ('' otherwise)
  const BetaAgonistsInfo(this.entity, this.species, this.markets, this.copackerOf);
}

/// Never Fed Beta Agonists (ractopamine/zilpaterol) verification lookup.
///
/// POSITIVE, plant-level disclosure — NOT a score input (adds/removes no points).
/// Fetches the AMS listing (est-core keyed) once per session and returns the
/// verified record for a scanned establishment. Absence means UNVERIFIED /
/// undisclosed — the UI must NEVER render it as "uses ractopamine": no federal
/// registry of users exists and FSIS requires no beta-agonist label disclosure.
/// Product-line scope, not a company-wide claim. Data hosted on the fat-android
/// repo, served via jsDelivr; regenerate with fat-supplier-registry/
/// extract_beta_agonists.py + build_beta_agonists_lookup.py.
class BetaAgonistsService {
  static Map<String, BetaAgonistsInfo>? _byCore;
  static const _url =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/beta-agonists/fat_beta_agonists.json';
  static final _tok = RegExp(r'\d{1,7}[a-z]?');

  /// Verified record for the establishment, or null if not on the AMS listing.
  /// Fail-open: any network/parse error returns null (no flag shown).
  static Future<BetaAgonistsInfo?> lookup(String? est) async {
    if (est == null || est.trim().isEmpty) return null;
    final map = await _load();
    if (map == null || map.isEmpty) return null;
    for (final m in _tok.allMatches(est.toLowerCase())) {
      final t = m.group(0)!;
      if (map.containsKey(t)) return map[t];
      final digits = t.replaceAll(RegExp(r'[a-z]'), '');
      if (digits.isNotEmpty && map.containsKey(digits)) return map[digits];
    }
    return null;
  }

  static Future<Map<String, BetaAgonistsInfo>?> _load() async {
    if (_byCore != null) return _byCore;
    try {
      final r =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final cores = d['cores'] as Map<String, dynamic>;
      _byCore = cores.map((core, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(
          core,
          BetaAgonistsInfo(
            (m['entity'] ?? '').toString(),
            (m['species'] ?? '').toString(),
            List<String>.from((m['markets'] as List?) ?? const []),
            (m['copacker_of'] ?? '').toString(),
          ),
        );
      });
      return _byCore;
    } catch (_) {
      return null;
    }
  }
}
