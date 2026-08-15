import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fat_models.dart';
import '../models/lookup_record.dart';

/// Lightweight persistence for scan history — mirrors iOS ScanStore.
/// Stores results as JSON in SharedPreferences.
///
/// A [ChangeNotifier] so live screens can react to writes: the tab bar keeps
/// every screen alive in an IndexedStack, and History only loaded in
/// initState — a scan saved mid-session never appeared until app restart.
class ScanStore extends ChangeNotifier {
  ScanStore._();
  static final ScanStore instance = ScanStore._();

  static const _key = 'fat_scan_history';
  static const _lookupKey = 'fat_lookup_history';

  Future<void> saveResult(FATResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    // Upsert by id: scans are auto-saved at evaluate time, so the results
    // screen's Save button re-saving the same result must not duplicate it.
    existing.removeWhere((s) {
      try { return (jsonDecode(s) as Map<String, dynamic>)['id'] == result.id; }
      catch (_) { return false; }
    });
    final encoded = jsonEncode(_resultToMap(result));
    existing.insert(0, encoded);
    // Keep last 200
    if (existing.length > 200) existing.removeRange(200, existing.length);
    await prefs.setStringList(_key, existing);
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> deleteAllLookups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lookupKey);
    notifyListeners();
  }

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> _resultToMap(FATResult r) => {
    'id':           r.id,
    'scannedText':  r.scannedText,
    'scannedAt':    r.scannedAt.toIso8601String(),
    'estNumber':    r.detectedEstablishmentNumber,
    'estMissing':   r.estMissing,
    'retailExempt': r.retailExempt,
    'retailExemptStoreName': r.retailExemptStoreName,
    'imagePaths':   r.imagePaths,
    'categories':   r.categories.map((k, v) => MapEntry(k.name, _catResultToMap(v))),
    // Seafood identity — without these a saved seafood scan silently
    // round-tripped as a meat record with zero categories in History.
    'productType':      r.productType.name,
    'seafoodCategories': r.seafoodCategories.map((k, v) => MapEntry(k.name, _catResultToMap(v))),
    'isSiluriformes':   r.isSiluriformes,
    'productionMethod': r.productionMethod?.name,
    'estSpeciesMismatch':     r.estSpeciesMismatch,
    'estSpeciesMismatchNote': r.estSpeciesMismatchNote,
    'speciesClaimMisuseNote': r.speciesClaimMisuseNote,
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
    final seaRaw = m['seafoodCategories'] as Map<String, dynamic>? ?? {};
    final seafoodCategories = <SeafoodCategory, FATCategoryResult>{};
    for (final entry in seaRaw.entries) {
      final cat = SeafoodCategory.values.firstWhere((c) => c.name == entry.key,
          orElse: () => SeafoodCategory.speciesIdentity);
      seafoodCategories[cat] = _catResultFromMap(entry.value as Map<String, dynamic>);
    }
    final typeStr = m['productType'] as String?;
    final methodStr = m['productionMethod'] as String?;
    return FATResult(
      id:                         m['id'] as String?,
      scannedText:                m['scannedText'] as String? ?? '',
      scannedAt:                  DateTime.tryParse(m['scannedAt'] as String? ?? ''),
      categories:                 categories,
      detectedEstablishmentNumber: m['estNumber'] as String?,
      estMissing:                 m['estMissing'] as bool? ?? false,
      retailExempt:               m['retailExempt'] as bool? ?? false,
      retailExemptStoreName:      m['retailExemptStoreName'] as String?,
      estSpeciesMismatch:         m['estSpeciesMismatch'] as bool? ?? false,
      estSpeciesMismatchNote:     m['estSpeciesMismatchNote'] as String?,
      speciesClaimMisuseNote:     m['speciesClaimMisuseNote'] as String?,
      productType: ProductType.values.firstWhere((t) => t.name == typeStr,
          orElse: () => ProductType.meat),
      seafoodCategories:          seafoodCategories,
      isSiluriformes:             m['isSiluriformes'] as bool? ?? false,
      productionMethod: methodStr == null
          ? null
          : SeafoodProductionMethod.values.firstWhere((p) => p.name == methodStr,
              orElse: () => SeafoodProductionMethod.wildCaught),
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
