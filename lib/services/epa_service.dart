import 'dart:convert';
import 'package:http/http.dart' as http;

/// EPA environmental-enforcement lookup for the Cat 7 (Processor) −3 penalty.
///
/// Fetches the lean "violations" list (est-cores with a high-confidence EPA ECHO
/// match and current noncompliance/penalties) once per session and checks whether
/// a scanned establishment's numeric core is in it. Data is hosted on the
/// fat-android repo and served via jsDelivr; regenerate with fat-epa/match_bulk.py.
class EpaService {
  static Set<String>? _cores;
  static const _url =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/epa/fat_epa_violations.json';
  static final _tok = RegExp(r'\d{1,7}[a-z]?');

  /// True iff the establishment has a high-confidence EPA match with violations.
  /// Fail-open: any network/parse error returns false (no penalty).
  static Future<bool> hasViolation(String? est) async {
    if (est == null || est.trim().isEmpty) return false;
    final cores = await _load();
    if (cores == null || cores.isEmpty) return false;
    for (final m in _tok.allMatches(est.toLowerCase())) {
      final t = m.group(0)!;
      if (cores.contains(t)) return true;
      // also try digits-only (est printed without the trailing grant letter)
      final digits = t.replaceAll(RegExp(r'[a-z]'), '');
      if (digits.isNotEmpty && cores.contains(digits)) return true;
    }
    return false;
  }

  static Future<Set<String>?> _load() async {
    if (_cores != null) return _cores;
    try {
      final r =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body);
      _cores = Set<String>.from((d['cores'] as List).map((e) => e.toString()));
      return _cores;
    } catch (_) {
      return null;
    }
  }
}
