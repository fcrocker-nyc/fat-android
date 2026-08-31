import 'dart:convert';
import 'package:http/http.dart' as http;

/// One tracked Environmental Watch matter (litigation/settlement).
class EnvWatchMatter {
  final String id;
  final String title;
  final String classification;
  final String status;
  final String summary;
  final List<String> companies; // lowercase substrings to match label text
  final List<String> estCores; // est-cores for plant-specific matters
  final String url;

  const EnvWatchMatter({
    required this.id,
    required this.title,
    required this.classification,
    required this.status,
    required this.summary,
    required this.companies,
    required this.estCores,
    required this.url,
  });
}

/// FAT Environmental Watch — active environmental litigation/settlement
/// matters keyed to companies and est-cores. INFORMATIONAL ONLY, never a
/// score input: "litigation pending" matters are allegations, not
/// adjudicated findings, and the card copy must keep that distinction.
/// Feed maintained by the weekly Environmental Watch scan; hosted on the
/// fat-android repo, served via jsDelivr. Mirrors iOS EnvironmentalWatchService.
class EnvironmentalWatchService {
  static List<EnvWatchMatter>? _matters;
  static const _url =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/environmental/fat_environmental_litigation.json';
  static final _tok = RegExp(r'\d{1,7}[a-z]?');

  /// Matters matching the scanned product, by est-core or company-name
  /// substring across the supplied texts (OCR text, owner, brand, processor).
  /// Fail-open: any network/parse error returns [] (no card shown).
  static Future<List<EnvWatchMatter>> matches(
      String? est, List<String?> texts) async {
    final all = await _load();
    if (all == null || all.isEmpty) return [];
    final haystack =
        texts.where((t) => t != null).map((t) => t!.toLowerCase()).join('\n');
    final estTokens = <String>{};
    if (est != null && est.trim().isNotEmpty) {
      for (final m in _tok.allMatches(est.toLowerCase())) {
        final t = m.group(0)!;
        estTokens.add(t);
        final digits = t.replaceAll(RegExp(r'[a-z]'), '');
        if (digits.isNotEmpty) estTokens.add(digits);
      }
    }
    return all.where((matter) {
      if (matter.estCores.any(estTokens.contains)) return true;
      return matter.companies
          .any((c) => c.isNotEmpty && haystack.contains(c));
    }).toList();
  }

  static Future<List<EnvWatchMatter>?> _load() async {
    if (_matters != null) return _matters;
    try {
      final r =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body);
      _matters = (d['matters'] as List)
          .map((m) => EnvWatchMatter(
                id: m['id'] as String,
                title: m['title'] as String,
                classification: m['classification'] as String,
                status: m['status'] as String,
                summary: m['summary'] as String,
                companies: List<String>.from(m['companies'] ?? [])
                    .map((c) => c.toLowerCase())
                    .toList(),
                estCores: List<String>.from(m['est_cores'] ?? [])
                    .map((c) => c.toLowerCase())
                    .toList(),
                url: m['url'] as String,
              ))
          .toList();
      return _matters;
    } catch (_) {
      return null;
    }
  }
}
