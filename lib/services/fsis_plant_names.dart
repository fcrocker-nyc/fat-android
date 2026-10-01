import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One plant from the bundled USDA FSIS MPI Directory snapshot.
class FsisPlantInfo {
  final String name;
  final String? dba;
  final String city;
  final String state;
  const FsisPlantInfo(
      {required this.name, this.dba, required this.city, required this.state});
}

/// FSIS plant-name fallback.
///
/// The FAT website's per-establishment JSON (fsis/inspection-results/{n}.json)
/// sometimes carries a blank establishment name / city / state (a bug in the
/// monthly FSIS update — e.g. EST 80, EST 1, P-1250). The processor card must
/// still lead with the plant's NAME, so a compact snapshot of the FSIS MPI
/// Directory is bundled (assets/data/fsis_establishment_names.json) and blanks
/// are filled from it. Never overrides a non-empty website value.
///
/// Format: {"source","source_date","plants":[{"n","d","c","s"}],
///          "keys":{"I80":idx,"80":idx,"P4033":idx,...}} — keys are FSIS
/// prefix+number for each part of combined numbers, plus bare digits (bare
/// prefers M, then P, G, V, I). Mirrors iOS FSISPlantNames.swift.
class FsisPlantNames {
  FsisPlantNames._();

  static const assetPath = 'assets/data/fsis_establishment_names.json';

  /// Neutral placeholder shown when no name is known from any source.
  static const notOnFileText = 'Plant name not on file';

  static List<FsisPlantInfo>? _plants;
  static Map<String, int>? _keys;
  static Future<void>? _loading;

  static bool get isLoaded => _plants != null;

  /// Loads the bundled table once. Safe to call repeatedly; never throws.
  static Future<void> ensureLoaded() {
    if (_plants != null) return Future.value();
    return _loading ??= () async {
      try {
        loadFromJsonString(await rootBundle.loadString(assetPath));
      } catch (_) {
        _loading = null; // allow a retry later
      }
    }();
  }

  /// Parses a table from its JSON text (used by [ensureLoaded] and tests).
  static void loadFromJsonString(String text) {
    final obj = jsonDecode(text) as Map<String, dynamic>;
    String clean(dynamic v) => (v ?? '').toString().trim();
    final plants = ((obj['plants'] as List?) ?? const []).map((e) {
      final p = Map<String, dynamic>.from(e as Map);
      final d = clean(p['d']);
      return FsisPlantInfo(
        name: clean(p['n']),
        dba: d.isEmpty ? null : d,
        city: clean(p['c']),
        state: clean(p['s']),
      );
    }).toList();
    final keys = <String, int>{};
    (Map<String, dynamic>.from(obj['keys'] as Map? ?? const {}))
        .forEach((k, v) {
      if (v is num && v >= 0 && v < plants.length) {
        keys[k.toUpperCase()] = v.toInt();
      }
    });
    _plants = plants;
    _keys = keys;
  }

  /// Look up a plant by FSIS prefix (M/P/V/G/I, may be null) + number. Tries
  /// prefix+digits (full prefix, then its first letter) before bare digits.
  /// Returns null when the table isn't loaded or the number is unknown.
  static FsisPlantInfo? lookup({String? prefix, required String digits}) {
    final plants = _plants, keys = _keys;
    if (plants == null || keys == null) return null;
    var number = digits
        .toUpperCase()
        .replaceAll('EST.', '')
        .replaceAll('EST', '')
        .replaceAll(RegExp(r'[\s.\-]'), '');
    var pfx = (prefix ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    // A number passed with its letter prefix attached (e.g. "P4033").
    final lead = RegExp(r'^[A-Z]+').firstMatch(number)?.group(0) ?? '';
    if (lead.isNotEmpty) {
      if (pfx.isEmpty) pfx = lead;
      number = number.substring(lead.length);
    }
    if (number.isEmpty) return null;
    // FAT records fold suffix letters into est_prefix (M20AE -> "MAE"), so
    // also try first-letter + number + remaining letters. The bare number is
    // tried only when no prefix is known — "20" alone is I20, a different plant.
    final candidates = <String>[
      if (pfx.isNotEmpty) '$pfx$number',
      if (pfx.length > 1) '${pfx[0]}$number${pfx.substring(1)}',
      if (pfx.length > 1) '${pfx[0]}$number',
      if (pfx.isEmpty) number,
    ];
    for (final c in candidates) {
      final i = keys[c];
      if (i != null) return plants[i];
    }
    return null;
  }

  /// True when a website-supplied name is missing / placeholder.
  static bool isBlankName(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty || t.toLowerCase() == 'unknown establishment';
  }
}
