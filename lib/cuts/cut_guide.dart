import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

// Cut guide data — port of iOS CutGuide.swift. The Lookup tab's "Cut" mode:
// where on the animal a beef, pork or chicken cut comes from, what it goes by,
// and what the name doesn't tell you. Data is assets/data/cuts.json (built by
// FATAppMVP2/Scripts/build_cuts.py, shared byte-for-byte with iOS). Diagrams
// are assets/images/cuts/cut_<species>_<primal>.png.

class CutSpecies {
  final String key, name, image, nameNeverSays;
  const CutSpecies(this.key, this.name, this.image, this.nameNeverSays);
  factory CutSpecies.fromJson(Map<String, dynamic> j) =>
      CutSpecies(j['key'] as String, j['name'] as String, j['image'] as String, j['nameNeverSays'] as String);
  String get asset => 'assets/images/cuts/$image.png';
}

class CutPrimal {
  final String species, key, name, about;
  const CutPrimal(this.species, this.key, this.name, this.about);
  factory CutPrimal.fromJson(Map<String, dynamic> j) =>
      CutPrimal(j['species'] as String, j['key'] as String, j['name'] as String, j['about'] as String);
}

class CutEntry {
  final String species, key, name, primal, about, nameNote, source;
  final List<String> aliases;
  const CutEntry(this.species, this.key, this.name, this.primal, this.aliases, this.about, this.nameNote, this.source);
  factory CutEntry.fromJson(Map<String, dynamic> j) => CutEntry(
        j['species'] as String,
        j['key'] as String,
        j['name'] as String,
        j['primal'] as String,
        List<String>.from(j['aliases'] as List),
        j['about'] as String,
        j['nameNote'] as String? ?? '',
        j['source'] as String,
      );

  String get id => '$species.$key';

  /// The diagram with this cut's primal highlighted.
  String get asset => 'assets/images/cuts/cut_${species}_$primal.png';

  /// Aliases that aren't already in the card's title.
  List<String> get otherNames {
    final title = CutGuide.normalize(name);
    return aliases.where((a) => !title.contains(CutGuide.normalize(a))).toList();
  }
}

class CutGuide {
  final String version;
  final List<CutSpecies> species;
  final List<CutPrimal> primals;
  final List<CutEntry> cuts;
  const CutGuide(this.version, this.species, this.primals, this.cuts);

  factory CutGuide.fromJson(Map<String, dynamic> j) => CutGuide(
        j['version'] as String? ?? '',
        [for (final s in j['species'] as List) CutSpecies.fromJson(s as Map<String, dynamic>)],
        [for (final p in j['primals'] as List) CutPrimal.fromJson(p as Map<String, dynamic>)],
        [for (final c in j['cuts'] as List) CutEntry.fromJson(c as Map<String, dynamic>)],
      );

  static CutGuide? _cached;
  static CutGuide? get cached => _cached;

  static Future<CutGuide> load() async => _cached ??=
      CutGuide.fromJson(jsonDecode(await rootBundle.loadString('assets/data/cuts.json')) as Map<String, dynamic>);

  CutSpecies? speciesFor(String key) {
    for (final s in species) {
      if (s.key == key) return s;
    }
    return null;
  }

  CutPrimal? primalFor(CutEntry c) {
    for (final p in primals) {
      if (p.species == c.species && p.key == c.primal) return p;
    }
    return null;
  }

  List<CutEntry> cutsOf(String species) => cuts.where((c) => c.species == species).toList();

  // ── Search ────────────────────────────────────────────────────────────────

  /// "Rib-Eye", "ribeyes", "N.Y. strip" → "rib eye", "ribeye", "ny strip".
  static String normalize(String s) {
    const fold = {'á': 'a', 'à': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', 'ç': 'c'};
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final c = fold[ch] ?? ch;
      if (RegExp(r'[a-z0-9]').hasMatch(c)) {
        b.write(c);
      } else if (c != "'" && c != '’' && c != '.') {
        b.write(' ');
      }
    }
    return b.toString().split(' ').where((w) => w.isNotEmpty).join(' ');
  }

  static String _singular(String s) => s
      .split(' ')
      .map((w) => w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w)
      .join(' ');

  /// Cuts matching a search, best first: an exact name or alias, then one
  /// that starts with the query, then one that contains it. Words like
  /// "beef", "pork" or "chicken" in the query narrow to that species.
  List<CutEntry> search(String query) {
    var q = _singular(normalize(query));
    if (q.isEmpty) return const [];
    String? only;
    for (final s in species) {
      final words = q.split(' ');
      if (words.contains(s.key)) {
        only = s.key;
        final rest = words.where((w) => w != s.key).join(' ');
        if (rest.isNotEmpty) q = rest;
      }
    }
    final scored = <(CutEntry, int)>[];
    for (final c in cuts) {
      if (only != null && c.species != only) continue;
      var best = 0;
      for (final n in [c.name, ...c.aliases].map((a) => _singular(normalize(a)))) {
        if (n == q) {
          best = best < 3 ? 3 : best;
        } else if (n.startsWith(q) || q.startsWith('$n ')) {
          best = best < 2 ? 2 : best;
        } else if (n.contains(q) || (n.length >= 6 && ' $q '.contains(' $n '))) {
          best = best < 1 ? 1 : best;
        }
      }
      if (only != null && q == only) best = 1; // "beef" alone: list every beef cut
      if (best > 0) scored.add((c, best));
    }
    // Stable sort: equal scores keep data order, as on iOS.
    final indexed = [for (var i = 0; i < scored.length; i++) (scored[i], i)];
    indexed.sort((a, b) => b.$1.$2 != a.$1.$2 ? b.$1.$2.compareTo(a.$1.$2) : a.$2.compareTo(b.$2));
    return [for (final e in indexed) e.$1.$1];
  }

  // ── Menu dishes ───────────────────────────────────────────────────────────

  /// The cut a menu dish names, if any — longest whole-word match among the
  /// species the dish contains ("Dry Aged Ribeye" → Ribeye).
  CutEntry? cutInDish(String text, Set<String> allowed) {
    final t = ' ${_singular(normalize(text))} ';
    CutEntry? best;
    var bestLen = 0;
    for (final c in cuts) {
      if (!allowed.contains(c.species)) continue;
      for (final n in [c.name, ...c.aliases].map((a) => _singular(normalize(a)))) {
        if (n.length >= 4 && t.contains(' $n ') && n.length > bestLen) {
          best = c;
          bestLen = n.length;
        }
      }
    }
    return best;
  }
}
