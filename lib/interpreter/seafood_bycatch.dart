// Seafood catch method + bycatch context (Cat. 10 detail lines).
//
// 1. Gear detection: what catch method a wild-seafood label states. Feeds the
//    Cat. 10 value ("Wild-Caught (gillnet)") and the "Catch method" line. It
//    never changes a category status, the disclosure count, or the index.
// 2. Bycatch context: when a wild (or unstated-method) product's species group
//    and stated country match one of the 10 "Strong" country × species pairs in
//    FAT Seafood Paper No. 5 (FDA × NOAA bycatch crosswalk), a public-record
//    line says NOAA has denied U.S. market access to some of that country's
//    fisheries for that species group, and with which gear. Pairs are bundled
//    in assets/data/mmpa_bycatch_pairs.json (built from the workbook's
//    Overlap_Pairs sheet).
//
// Strings and rules are kept identical to iOS (SeafoodBycatch.swift) for
// parity.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/fat_models.dart';

class SeafoodGear {
  /// Stable id, matched against `deniedGears` in mmpa_bycatch_pairs.json.
  final String id;

  /// Text inside "Wild-Caught (…)".
  final String label;

  /// Plain lowercase name used in "Catch method: … (stated on label)".
  final String phrase;

  const SeafoodGear(this.id, this.label, this.phrase);

  /// Cat. 10 value text, e.g. "Wild-Caught (gillnet)".
  String get cat10Value => 'Wild-Caught ($label)';
}

class _GearEntry {
  final RegExp regex;
  final SeafoodGear gear;
  _GearEntry(String pattern, String id, String label, String phrase)
      : regex = RegExp(pattern),
        gear = SeafoodGear(id, label, phrase);
}

class SeafoodGearDetector {
  SeafoodGearDetector._();

  // Order matters only for ties (equal match length → earlier entry wins).
  // The first nine are the pre-existing Cat. 10 gears (labels unchanged).
  static final List<_GearEntry> _entries = [
    _GearEntry(r'\bline caught', 'hookAndLine', 'line caught', 'hook and line'),
    _GearEntry(r'\bline-caught', 'hookAndLine', 'line-caught', 'hook and line'),
    _GearEntry(r'\bpole caught', 'poleAndLine', 'pole caught', 'pole and line'),
    _GearEntry(r'\bpole-caught', 'poleAndLine', 'pole-caught', 'pole and line'),
    _GearEntry(r'\btrawl', 'trawl', 'trawl', 'trawl'),
    _GearEntry(r'\blong-?line', 'longline', 'longline', 'longline'),
    _GearEntry(r'\bgill[- ]?net', 'gillnet', 'gillnet', 'gillnet'),
    _GearEntry(r'\bpurse[- ]?seine', 'purseSeine', 'purse seine', 'purse seine'),
    _GearEntry(r'\bhook[- ](?:and|&)[- ]line(?:[- ]caught)?', 'hookAndLine',
        'hook and line', 'hook and line'),
    // Added gears.
    _GearEntry(r'\bpole[- ]?(?:and|&)[- ]?line(?:[- ]caught)?', 'poleAndLine',
        'pole and line', 'pole and line'),
    _GearEntry(r'\btroll(?:ed|ing|s)?\b(?:[- ]caught)?', 'troll', 'troll', 'troll'),
    _GearEntry(r'\btraps?\b(?:[- ]caught)?', 'trapPot', 'trap/pot', 'trap or pot'),
    _GearEntry(
        r'(?<!hot )(?<!crock )(?<!instant )\bpots?\b(?![- ]?(?:pies?|stickers?|roast)\b)(?:[- ]caught)?',
        'trapPot',
        'trap/pot',
        'trap or pot'),
    _GearEntry(r'\bharpoon(?:ed|s)?\b(?:[- ]caught)?', 'harpoon', 'harpoon', 'harpoon'),
    _GearEntry(r'\bhand[- ]?line[sd]?\b(?:[- ]caught)?', 'handline', 'handline', 'handline'),
    _GearEntry(r'\bdredge[sd]?\b', 'dredge', 'dredge', 'dredge'),
    _GearEntry(r'\btrammel[- ]?nets?\b', 'trammelNet', 'trammel net', 'trammel net'),
    _GearEntry(r'\bdrift[- ]?(?:gill[- ]?)?nets?\b', 'driftGillnet', 'drift gillnet',
        'drift gillnet'),
    _GearEntry(r'\bset[- ]?(?:gill[- ]?)?nets?\b(?![ .]*(?:wt|weight)\b)', 'setNet',
        'set net', 'set net'),
  ];

  static final RegExp _fadFree = RegExp(r'\bfad[- ]?free\b');
  static final RegExp _freeSchool = RegExp(r'\bfree[- ]school\b');
  static const fadFreePurseSeine =
      SeafoodGear('purseSeine', 'FAD-free purse seine', 'FAD-free purse seine');
  static const freeSchoolPurseSeine =
      SeafoodGear('purseSeine', 'free school purse seine', 'free school purse seine');

  /// Catch method stated on the label (lowercased, whitespace-collapsed text),
  /// or null. Longest match wins. "FAD-free" / "free school" qualify a purse
  /// seine (or stand for one when no other gear is named).
  static SeafoodGear? detect(String t) {
    SeafoodGear? best;
    var bestLen = 0;
    for (final e in _entries) {
      final m = e.regex.firstMatch(t);
      if (m == null) continue;
      final len = m.end - m.start;
      if (len > bestLen) {
        best = e.gear;
        bestLen = len;
      }
    }
    if (best == null || best.id == 'purseSeine') {
      if (_fadFree.hasMatch(t)) return fadFreePurseSeine;
      if (_freeSchool.hasMatch(t)) return freeSchoolPurseSeine;
    }
    return best;
  }
}

// ── Bycatch pairs (bundled data) ──

class MmpaBycatchPair {
  final String country;
  final String speciesGroup;
  final String gearPhrase;
  final List<String> deniedGears;
  const MmpaBycatchPair(
      this.country, this.speciesGroup, this.gearPhrase, this.deniedGears);
}

class MmpaBycatchData {
  final String asOf;
  final List<MmpaBycatchPair> pairs;
  const MmpaBycatchData(this.asOf, this.pairs);

  static const assetPath = 'assets/data/mmpa_bycatch_pairs.json';

  /// Loaded once at startup (main.dart). Null → no bycatch lines.
  static MmpaBycatchData? bundled;
  static Future<void>? _loading;

  /// Loads the bundled pairs once. Safe to call repeatedly; never throws.
  static Future<void> ensureLoaded() {
    if (bundled != null) return Future.value();
    return _loading ??= () async {
      try {
        bundled = fromJsonString(await rootBundle.loadString(assetPath));
      } catch (_) {
        _loading = null; // allow a retry later
      }
    }();
  }

  static MmpaBycatchData fromJsonString(String text) {
    final obj = jsonDecode(text) as Map<String, dynamic>;
    final pairs = ((obj['pairs'] as List?) ?? const []).map((e) {
      final p = Map<String, dynamic>.from(e as Map);
      return MmpaBycatchPair(
        p['country'] as String,
        p['speciesGroup'] as String,
        p['gearPhrase'] as String,
        ((p['deniedGears'] as List?) ?? const []).cast<String>(),
      );
    }).toList();
    return MmpaBycatchData(obj['asOf'] as String, pairs);
  }
}

// ── Lines ──

class SeafoodBycatch {
  SeafoodBycatch._();

  // ── User-facing strings (kept verbatim for iOS parity) ──
  static const String catchMethodNotStated = 'Catch method not stated on label';
  static String catchMethodStated(String phrase) =>
      'Catch method: $phrase (stated on label)';
  static String contextLead(
          String country, String group, String gearPhrase, String asOf) =>
      'NOAA has denied U.S. market access to some $group fisheries in $country using $gearPhrase, because of marine-mammal bycatch (as of $asOf).';
  static String contextUnknownGear(String country, String group,
          String gearPhrase, String asOf, String species) =>
      "${contextLead(country, group, gearPhrase, asOf)} This label doesn't say how this $species was caught.";
  static String contextDeniedGear(
          String country, String group, String gearPhrase, String asOf) =>
      "${contextLead(country, group, gearPhrase, asOf)} Products sold in the U.S. must come from fisheries that were not denied; this label doesn't name the fishery.";

  /// Cat. 10 catch-method line — wild-caught seafood only.
  static String? catchMethodLine(SeafoodProductionMethod? method, String t) {
    if (method != SeafoodProductionMethod.wildCaught) return null;
    final g = SeafoodGearDetector.detect(t);
    return g != null ? catchMethodStated(g.phrase) : catchMethodNotStated;
  }

  // Species groups used in Paper No. 5's Strong pairs.
  static final List<MapEntry<String, RegExp>> _groupPatterns = [
    MapEntry('tuna',
        RegExp(r'\b(tunas?|albacore|skipjack|yellowfin|bigeye|ahi|bluefin)\b')),
    MapEntry('shrimp', RegExp(r'\b(shrimps?|prawns?)\b')),
    MapEntry('mahi mahi', RegExp(r'\b(mahi[- ]mahi|mahi|dolphinfish(es)?)\b')),
    MapEntry('grouper', RegExp(r'\bgroupers?\b')),
    MapEntry('snapper', RegExp(r'\bsnappers?\b')),
  ];

  static String? _group(String s) {
    for (final e in _groupPatterns) {
      if (e.value.hasMatch(s)) return e.key;
    }
    return null;
  }

  /// Countries in the bundled pairs, with the spellings that count as each.
  static List<String> _countryKeys(String country) {
    final c = country.toLowerCase();
    return c == 'vietnam' ? const ['vietnam', 'viet nam'] : [c];
  }

  /// True when the label states the country: the Cat. 4 value (when Known)
  /// names it, or the text says "Product of [the] {country}".
  static bool _statesCountry(
      String country, FATCategoryResult? origin, String t) {
    final keys = _countryKeys(country);
    if (origin != null &&
        origin.status == DisclosureStatus.known &&
        origin.value != null) {
      final v = origin.value!.toLowerCase();
      if (keys.any(v.contains)) return true;
    }
    return keys.any((k) =>
        RegExp(r'\bproduct of (the )?' + RegExp.escape(k) + r'\b').hasMatch(t));
  }

  /// Bycatch context lines for Cat. 10 (usually zero or one).
  static List<String> contextLines({
    required String? species,
    required SeafoodProductionMethod? method,
    required FATCategoryResult? origin,
    required String text,
    MmpaBycatchData? data,
  }) {
    final d = data ?? MmpaBycatchData.bundled;
    if (d == null || method == SeafoodProductionMethod.farmRaised) return const [];
    // Species group: from the Cat. 2 species when Known, else the text.
    final String? speciesGroup;
    final String speciesName;
    if (species != null) {
      final s = species.toLowerCase();
      speciesGroup = _group(s);
      speciesName = s.endsWith('prawns') ? s.substring(0, s.length - 1) : s;
    } else {
      speciesGroup = _group(text);
      speciesName = speciesGroup ?? '';
    }
    if (speciesGroup == null) return const [];
    final stated = SeafoodGearDetector.detect(text);
    final out = <String>[];
    for (final p in d.pairs) {
      if (p.speciesGroup != speciesGroup) continue;
      if (!_statesCountry(p.country, origin, text)) continue;
      if (stated != null) {
        if (!p.deniedGears.contains(stated.id)) continue; // other gear stated → no line
        out.add(contextDeniedGear(p.country, p.speciesGroup, p.gearPhrase, d.asOf));
      } else {
        out.add(contextUnknownGear(
            p.country, p.speciesGroup, p.gearPhrase, d.asOf, speciesName));
      }
    }
    return out;
  }
}
