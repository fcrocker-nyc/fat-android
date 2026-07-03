import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fat_models.dart';

/// Lightweight persistence for scan history — mirrors iOS ScanStore.
/// Stores results as JSON in SharedPreferences.
class ScanStore {
  ScanStore._();
  static final ScanStore instance = ScanStore._();

  static const _key = 'fat_scan_history';

  Future<void> saveResult(FATResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final encoded = jsonEncode(_resultToMap(result));
    existing.insert(0, encoded);
    // Keep last 200
    if (existing.length > 200) existing.removeRange(200, existing.length);
    await prefs.setStringList(_key, existing);
  }

  Future<List<FATResult>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try { return _resultFromMap(jsonDecode(s) as Map<String, dynamic>); }
          catch (_) { return null; }
        })
        .whereType<FATResult>()
        .toList();
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> _resultToMap(FATResult r) => {
    'id':           r.id,
    'scannedText':  r.scannedText,
    'scannedAt':    r.scannedAt.toIso8601String(),
    'estNumber':    r.detectedEstablishmentNumber,
    'estMissing':   r.estMissing,
    'categories':   r.categories.map((k, v) => MapEntry(k.name, _catResultToMap(v))),
  };

  Map<String, dynamic> _catResultToMap(FATCategoryResult r) => {
    'status':          r.status.name,
    'value':           r.value,
    'credibility':     r.credibility?.name,
    'credibilityNote': r.credibilityNote,
    'captivity':       r.captivityStatus?.name,
  };

  FATResult _resultFromMap(Map<String, dynamic> m) {
    final catRaw = m['categories'] as Map<String, dynamic>? ?? {};
    final categories = <FATCategory, FATCategoryResult>{};
    for (final entry in catRaw.entries) {
      final cat = FATCategory.values.firstWhere((c) => c.name == entry.key,
          orElse: () => FATCategory.species);
      categories[cat] = _catResultFromMap(entry.value as Map<String, dynamic>);
    }
    return FATResult(
      id:                         m['id'] as String?,
      scannedText:                m['scannedText'] as String? ?? '',
      scannedAt:                  DateTime.tryParse(m['scannedAt'] as String? ?? ''),
      categories:                 categories,
      detectedEstablishmentNumber: m['estNumber'] as String?,
      estMissing:                 m['estMissing'] as bool? ?? false,
    );
  }

  FATCategoryResult _catResultFromMap(Map<String, dynamic> m) {
    final statusStr = m['status'] as String? ?? 'missing';
    final status = DisclosureStatus.values.firstWhere((s) => s.name == statusStr,
        orElse: () => DisclosureStatus.missing);
    final credStr = m['credibility'] as String?;
    final cred = credStr == null ? null
        : ClaimCredibility.values.firstWhere((c) => c.name == credStr,
            orElse: () => ClaimCredibility.labelClaimOnly);
    final capStr = m['captivity'] as String?;
    final cap = capStr == null ? null
        : CaptivityStatus.values.firstWhere((c) => c.name == capStr,
            orElse: () => CaptivityStatus.undisclosed);
    return FATCategoryResult(
      status:          status,
      value:           m['value'] as String?,
      credibility:     cred,
      credibilityNote: m['credibilityNote'] as String?,
      captivityStatus: cap,
    );
  }
}
