import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fat_models.dart';
import '../models/lookup_record.dart';

/// Lightweight persistence for scan history — mirrors iOS ScanStore.
/// Stores results as JSON in SharedPreferences.
class ScanStore {
  ScanStore._();
  static final ScanStore instance = ScanStore._();

  static const _key = 'fat_scan_history';
  static const _lookupKey = 'fat_lookup_history';

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

  // ── Lookup history ─────────────────────────────────────────────────────────

  /// Records a lookup event to History. Newest first. Deduplicates against an
  /// identical back-to-back search (same category + query + result) so
  /// re-tapping Search without changing anything doesn't stack duplicates.
  Future<void> saveLookup(LookupRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_lookupKey) ?? [];
    if (existing.isNotEmpty) {
      try {
        final last = LookupRecord.fromMap(
            jsonDecode(existing.first) as Map<String, dynamic>);
        if (last.category == record.category &&
            last.query.toLowerCase() == record.query.toLowerCase() &&
            last.resultTitle == record.resultTitle) {
          return;
        }
      } catch (_) {}
    }
    existing.insert(0, jsonEncode(record.toMap()));
    if (existing.length > 200) existing.removeRange(200, existing.length);
    await prefs.setStringList(_lookupKey, existing);
  }

  Future<List<LookupRecord>> loadLookups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_lookupKey) ?? [];
    return raw
        .map((s) {
          try { return LookupRecord.fromMap(jsonDecode(s) as Map<String, dynamic>); }
          catch (_) { return null; }
        })
        .whereType<LookupRecord>()
        .toList();
  }

  Future<void> deleteLookup(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_lookupKey) ?? [];
    raw.removeWhere((s) {
      try { return (jsonDecode(s) as Map<String, dynamic>)['id'] == id; }
      catch (_) { return false; }
    });
    await prefs.setStringList(_lookupKey, raw);
  }

  Future<void> deleteAllLookups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lookupKey);
  }

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> _resultToMap(FATResult r) => {
    'id':           r.id,
    'scannedText':  r.scannedText,
    'scannedAt':    r.scannedAt.toIso8601String(),
    'estNumber':    r.detectedEstablishmentNumber,
    'estMissing':   r.estMissing,
    'imagePaths':   r.imagePaths,
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
      imagePaths:                 (m['imagePaths'] as List?)?.cast<String>() ?? const [],
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
