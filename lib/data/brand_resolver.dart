// BrandResolver — Flutter port of iOS BrandResolver.swift.
//
// Loads the FAT brand-data feed (crosswalk + aliases + enforcement layer),
// bundled at assets/data/brand_data.json as the floor and refreshed from
// https://farmanimaltransparency.com/wp-json/fat/v1/brand-data (roll-forward
// by `version`). Resolves OCR text → responsible company and grades public FDA
// enforcement (Category 13) by event type + recency. Shares the exact same feed
// as the iOS app and the website tools.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Resolution + enforcement value types
// ─────────────────────────────────────────────

class BrandResolution {
  final String matchedBrand;
  final String matchedAlias;
  final String primaryResponsibleCompany;
  final String normalizedEntity;
  final String priorityBand; // P1 | P2 | P3 | (unknown)
  final bool existingFdaBridge;
  final List<String> fdaBridgeEntities;
  final String? appDisplayCaveat;
  final String confidenceLabel;
  final String? brandOwnerSourceURL;

  const BrandResolution({
    required this.matchedBrand,
    required this.matchedAlias,
    required this.primaryResponsibleCompany,
    required this.normalizedEntity,
    required this.priorityBand,
    required this.existingFdaBridge,
    required this.fdaBridgeEntities,
    required this.appDisplayCaveat,
    required this.confidenceLabel,
    required this.brandOwnerSourceURL,
  });

  /// True for P2/P3 brands without a public FDA bridge — the UI must NOT surface
  /// FDA history for these, because the result would be misleading.
  bool get shouldSuppressFdaLookup =>
      priorityBand != 'P1' && !existingFdaBridge;
}

class BrandEnforcementSummary {
  final int eventCount;
  final int recallCount;
  final int importAlertCount;
  final int warningCount;
  final int otherCount;
  final String? mostRecentDate; // YYYY-MM-DD
  final List<String> matchedEntities;
  final String? primarySourceURL;

  const BrandEnforcementSummary({
    required this.eventCount,
    required this.recallCount,
    required this.importAlertCount,
    required this.warningCount,
    required this.otherCount,
    required this.mostRecentDate,
    required this.matchedEntities,
    required this.primarySourceURL,
  });

  bool get hasHighSeverity => recallCount > 0 || importAlertCount > 0;

  int? get _monthsSinceMostRecent {
    final d = mostRecentDate;
    if (d == null) return null;
    final parsed = DateTime.tryParse(d);
    if (parsed == null) return null;
    final now = DateTime.now();
    return (now.year - parsed.year) * 12 + (now.month - parsed.month);
  }

  bool get isRecent => (_monthsSinceMostRecent ?? 1 << 30) <= 24;

  String get displayText {
    final parts = <String>[];
    if (recallCount > 0) {
      parts.add('$recallCount recall${recallCount == 1 ? '' : 's'}');
    }
    if (importAlertCount > 0) {
      parts.add(
          '$importAlertCount import alert/advisor${importAlertCount == 1 ? 'y' : 'ies'}');
    }
    if (warningCount > 0) {
      parts.add('$warningCount warning letter${warningCount == 1 ? '' : 's'}');
    }
    if (otherCount > 0) {
      parts.add('$otherCount other action${otherCount == 1 ? '' : 's'}');
    }
    final typeLine =
        parts.isEmpty ? '$eventCount public action(s)' : parts.join(', ');
    var s = 'Public FDA enforcement: $typeLine.';
    if (mostRecentDate != null) s += ' Most recent $mostRecentDate.';
    if (matchedEntities.isNotEmpty) {
      final firm = matchedEntities.first;
      s += matchedEntities.length > 1
          ? ' Tied to $firm and ${matchedEntities.length - 1} other firm(s).'
          : ' Tied to $firm.';
    }
    return s;
  }

  String get recencyNote {
    if (mostRecentDate == null) {
      return 'Official FDA/DOJ public records (FAT brand→FDA bridge).';
    }
    return isRecent
        ? 'Recent — most recent public action $mostRecentDate (within ~2 years). Official FDA/DOJ records.'
        : 'Most recent public action $mostRecentDate. Official FDA/DOJ records.';
  }
}

// ─────────────────────────────────────────────
// Resolver
// ─────────────────────────────────────────────

class BrandResolver {
  BrandResolver._();
  static final BrandResolver instance = BrandResolver._();

  static const _remoteUrl =
      'https://farmanimaltransparency.com/wp-json/fat/v1/brand-data';
  static const _assetPath = 'assets/data/brand_data.json';
  static const _prefsKey = 'fat_brand_data_json';

  String _version = '';
  // crosswalk indexed by brand
  final Map<String, Map<String, dynamic>> _crosswalkByBrand = {};
  // aliases sorted longest-first: (normalizedAlias, brand)
  final List<MapEntry<String, String>> _sortedAliases = [];
  // enforcement events keyed by normalized entity
  final Map<String, List<Map<String, dynamic>>> _enforcementByEntity = {};

  String get loadedVersion => _version;

  /// Load the bundled snapshot synchronously-ish at startup, then refresh from
  /// remote in the background (roll-forward only).
  Future<void> init() async {
    // 1) Prefer a cached remote copy if newer than the bundled asset.
    String? best;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      final asset = await rootBundle.loadString(_assetPath);
      best = asset;
      if (cached != null) {
        final cv = _versionOf(cached);
        final av = _versionOf(asset);
        if (cv.compareTo(av) > 0) best = cached;
      }
    } catch (_) {
      // asset load failed — leave best null, refresh may still populate
    }
    if (best != null) _ingest(best);

    // 2) Background refresh (don't block the UI).
    unawaited(_refreshFromRemote());
  }

  Future<void> _refreshFromRemote() async {
    try {
      final resp =
          await http.get(Uri.parse(_remoteUrl)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final remoteVersion = _versionOf(resp.body);
      if (remoteVersion.isEmpty) return;
      if (remoteVersion.compareTo(_version) > 0) {
        _ingest(resp.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, resp.body);
      }
    } catch (_) {
      // offline / transient — keep current snapshot
    }
  }

  String _versionOf(String jsonStr) {
    try {
      final m = json.decode(jsonStr);
      return (m is Map && m['version'] is String) ? m['version'] as String : '';
    } catch (_) {
      return '';
    }
  }

  void _ingest(String jsonStr) {
    final dynamic root = json.decode(jsonStr);
    if (root is! Map) return;
    _version = (root['version'] as String?) ?? _version;

    _crosswalkByBrand.clear();
    for (final c in (root['crosswalk'] as List? ?? const [])) {
      if (c is Map<String, dynamic> && c['brand'] is String) {
        _crosswalkByBrand[c['brand'] as String] = c;
      }
    }

    _sortedAliases.clear();
    for (final a in (root['aliases'] as List? ?? const [])) {
      if (a is Map && a['alias'] is String && a['brand'] is String) {
        _sortedAliases
            .add(MapEntry(normalize(a['alias'] as String), a['brand'] as String));
      }
    }
    _sortedAliases.sort((x, y) => y.key.length.compareTo(x.key.length));

    _enforcementByEntity.clear();
    for (final e in (root['enforcement_events'] as List? ?? const [])) {
      if (e is Map<String, dynamic> && e['normalized_entity'] is String) {
        final k = normalize(e['normalized_entity'] as String);
        (_enforcementByEntity[k] ??= []).add(e);
      }
    }
  }

  /// Resolve OCR text to a crosswalk row, or null if no alias appears.
  BrandResolution? resolve(String ocrText) {
    final t = normalize(ocrText);
    if (t.isEmpty) return null;
    for (final entry in _sortedAliases) {
      final key = entry.key;
      if (key.isEmpty) continue;
      if (t.contains(key)) {
        final cw = _crosswalkByBrand[entry.value];
        if (cw == null) continue;
        return BrandResolution(
          matchedBrand: entry.value,
          matchedAlias: key,
          primaryResponsibleCompany:
              (cw['primary_responsible_company'] as String?) ?? entry.value,
          normalizedEntity: (cw['normalized_entity'] as String?) ?? '',
          priorityBand: (cw['priority_band'] as String?) ?? 'unknown',
          existingFdaBridge: (cw['existing_fda_bridge'] as bool?) ?? false,
          fdaBridgeEntities:
              ((cw['fda_bridge_entities'] as List?) ?? const [])
                  .map((e) => e.toString())
                  .toList(),
          appDisplayCaveat: cw['app_display_caveat'] as String?,
          confidenceLabel: (cw['confidence_label'] as String?) ?? '',
          brandOwnerSourceURL: cw['brand_owner_source_url'] as String?,
        );
      }
    }
    return null;
  }

  /// Public enforcement matched to a resolved brand, graded by type + recency.
  /// Joins on fda_bridge_entities + normalized entity + responsible company.
  BrandEnforcementSummary? enforcementSummary(BrandResolution r) {
    final keys = <String>{
      normalize(r.normalizedEntity),
      normalize(r.primaryResponsibleCompany),
      for (final b in r.fdaBridgeEntities) normalize(b),
    }..remove('');

    final events = <Map<String, dynamic>>[];
    final seen = <String>{};
    final matched = <String>{};
    for (final k in keys) {
      final list = _enforcementByEntity[k];
      if (list == null) continue;
      for (final e in list) {
        final id =
            '${e['event_id'] ?? ''}|${e['action_date'] ?? ''}|${e['note'] ?? ''}';
        if (seen.add(id)) {
          events.add(e);
          if (e['entity'] is String) matched.add(e['entity'] as String);
        }
      }
    }
    if (events.isEmpty) return null;

    int countBucket(bool Function(String) test) => events
        .where((e) => e['action_bucket'] is String && test(e['action_bucket'] as String))
        .length;
    final recalls = countBucket((b) => b == 'Recall');
    final alerts =
        countBucket((b) => b == 'Import alert' || b == 'Advisory / import action');
    final warnings = countBucket((b) => b == 'Warning letter');
    final other = events.length - recalls - alerts - warnings;

    events.sort((a, b) =>
        ((b['action_date'] as String?) ?? '').compareTo((a['action_date'] as String?) ?? ''));
    final mostRecent = events.first['action_date'] as String?;
    final src = events.first['source_url'] as String?;

    return BrandEnforcementSummary(
      eventCount: events.length,
      recallCount: recalls,
      importAlertCount: alerts,
      warningCount: warnings,
      otherCount: other < 0 ? 0 : other,
      mostRecentDate: mostRecent,
      matchedEntities: matched.toList()..sort(),
      primarySourceURL: src,
    );
  }

  /// Normalize for matching: lowercase, collapse whitespace, strip everything
  /// that isn't alphanumeric or a space. Mirrors iOS BrandResolver.normalize so
  /// crosswalk fda_bridge_entities join to the dataset's normalized_entity.
  static String normalize(String s) {
    final lower = s.toLowerCase();
    final stripped = lower.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
