import 'dart:ui' show Rect;

// Menu Claim Audit — data model. Dart port of the iOS Menu/ module.
// Separate track from label scanning and loose-fish (service case) scanning:
// nothing here references FATResult, Status, or any establishment lookup.
// The menu component explains claims and suggests questions; it never
// verifies, scores or grades.

enum ProteinFamily {
  beef('Beef', 'beef'),
  pork('Pork', 'pork'),
  lamb('Lamb', 'lamb'),
  poultry('Poultry', 'chicken or duck'),
  finfish('Fish', 'fish'),
  shellfish('Shellfish', 'shellfish'),
  other('Other meat', 'meat');

  const ProteinFamily(this.displayName, this.questionNoun);
  final String displayName;
  final String questionNoun;

  static ProteinFamily? parse(String s) {
    for (final f in values) {
      if (f.name == s) return f;
    }
    return null;
  }
}

enum ClaimFamily {
  speciesOrForm('Species & form', 0),
  originRegion('Origin — region', 1),
  originFarm('Origin — named source', 2),
  productionMethod('How it was raised or caught', 3),
  certification('Certification', 4),
  gradeOrBreed('Grade & breed', 5);

  const ClaimFamily(this.displayName, this.priority);
  final String displayName;
  final int priority;

  static ClaimFamily parse(String s) =>
      values.firstWhere((f) => f.name == s, orElse: () => productionMethod);
}

/// One row of the bundled glossary JSON.
class ClaimEntry {
  final String key;
  final ClaimFamily family;
  final List<String> phrases;
  final List<String> patterns;
  final List<ProteinFamily>? proteins;
  final bool adjacentProtein;
  final String meaning;
  final String? authority;
  final String gap;
  final List<String> questions;
  final Map<String, String>? stateNote;

  /// Protein-specific wording, e.g. "organic" on fish (no USDA standard).
  final List<ClaimVariant> variants;

  const ClaimEntry({
    required this.key,
    required this.family,
    required this.phrases,
    required this.patterns,
    required this.proteins,
    required this.adjacentProtein,
    required this.meaning,
    required this.authority,
    required this.gap,
    required this.questions,
    required this.stateNote,
    this.variants = const [],
  });

  /// The wording for the protein the claim sits next to.
  ClaimText textFor(ProteinFamily? protein) {
    if (protein != null) {
      for (final v in variants) {
        if (v.proteins.contains(protein)) {
          return ClaimText(v.meaning, v.authority, v.gap, v.questions);
        }
      }
    }
    return ClaimText(meaning, authority, gap, questions);
  }

  factory ClaimEntry.fromJson(Map<String, dynamic> j) => ClaimEntry(
        key: j['key'] as String,
        family: ClaimFamily.parse(j['family'] as String),
        phrases: List<String>.from(j['phrases'] as List),
        patterns: List<String>.from((j['patterns'] as List?) ?? const []),
        proteins: (j['proteins'] as List?)
            ?.map((e) => ProteinFamily.parse(e as String))
            .whereType<ProteinFamily>()
            .toList(),
        adjacentProtein: (j['adjacentProtein'] as bool?) ?? false,
        meaning: j['meaning'] as String,
        authority: j['authority'] as String?,
        gap: j['gap'] as String,
        questions: List<String>.from(j['questions'] as List),
        stateNote: (j['stateNote'] as Map?)?.map(
          (k, v) => MapEntry(k as String, v as String),
        ),
        variants: ((j['variants'] as List?) ?? const [])
            .map((v) => ClaimVariant.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class ClaimVariant {
  final List<ProteinFamily> proteins;
  final String meaning;
  final String? authority;
  final String gap;
  final List<String> questions;
  const ClaimVariant(this.proteins, this.meaning, this.authority, this.gap, this.questions);

  factory ClaimVariant.fromJson(Map<String, dynamic> j) => ClaimVariant(
        (j['proteins'] as List).map((e) => ProteinFamily.parse(e as String)).whereType<ProteinFamily>().toList(),
        j['meaning'] as String,
        j['authority'] as String?,
        j['gap'] as String,
        List<String>.from(j['questions'] as List),
      );
}

class ClaimText {
  final String meaning;
  final String? authority;
  final String gap;
  final List<String> questions;
  const ClaimText(this.meaning, this.authority, this.gap, this.questions);
}

class MenuGlossary {
  final String version;
  final String status;

  /// Asked about every dish, claim or not. "{protein}" is replaced per dish.
  final List<String> generalQuestions;
  final List<ClaimEntry> entries;

  /// Curated named sources ("Glen Cairn" salmon) with a sourced note.
  final List<KnownSource> knownSources;

  const MenuGlossary({
    required this.version,
    required this.status,
    required this.generalQuestions,
    required this.entries,
    this.knownSources = const [],
  });

  factory MenuGlossary.fromJson(Map<String, dynamic> j) => MenuGlossary(
    version: j['version'] as String,
    status: (j['status'] as String?) ?? '',
    generalQuestions: List<String>.from(j['generalQuestions'] as List),
    entries: (j['entries'] as List).map((e) => ClaimEntry.fromJson(e as Map<String, dynamic>)).toList(),
    knownSources: ((j['knownSources'] as List?) ?? const [])
        .map((e) => KnownSource.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  ClaimEntry? entry(String key) {
    for (final e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  /// The curated note for a named source on the menu, if FAT has one.
  KnownSource? knownSource(String name, String? subject) {
    final n = KnownSource.normalize(name);
    final subj = (subject ?? '').toLowerCase();
    for (final ks in knownSources) {
      if (ks.names.any((x) => KnownSource.normalize(x) == n) &&
          (ks.species.isEmpty || ks.species.any((s) => subj.contains(s.toLowerCase())))) {
        return ks;
      }
    }
    return null;
  }
}

/// One row of the curated "known named sources" table. The note carries its
/// own attribution; FAT does not verify it.
class KnownSource {
  final List<String> names; // "Glen Cairn", "Glencairn"
  final List<String> species; // species words it applies to ("salmon")
  final String note;
  const KnownSource(this.names, this.species, this.note);

  factory KnownSource.fromJson(Map<String, dynamic> j) => KnownSource(
    List<String>.from(j['names'] as List),
    List<String>.from((j['species'] as List?) ?? const []),
    j['note'] as String,
  );

  /// "GLEN CAIRN" / "Glencairn" → "glencairn".
  static String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
}

/// One recognized line with a normalized box (0…1, origin bottom-left, to
/// match iOS Vision). Plain-text input uses synthetic boxes.
class MenuOCRLine {
  final String text;
  final Rect box; // left=x, top=minY, right=x+w, bottom=maxY in bottom-left space
  const MenuOCRLine(this.text, this.box);

  double get minX => box.left;
  double get maxX => box.right;
  double get minY => box.top;
  double get maxY => box.bottom;
  double get midY => (box.top + box.bottom) / 2;
  double get height => box.bottom - box.top;
  double get width => box.right - box.left;
  double get midX => (box.left + box.right) / 2;
}

class MenuPage {
  final int index;
  final List<MenuOCRLine> lines;
  const MenuPage(this.index, this.lines);

  /// Plain text → page, one OCR line per text line (used in tests).
  factory MenuPage.fromPlainText(String text, {int index = 0}) {
    final raw = text.split(RegExp(r'\r?\n'));
    final step = 1.0 / (raw.isEmpty ? 2 : raw.length + 1);
    final lines = <MenuOCRLine>[];
    for (var i = 0; i < raw.length; i++) {
      final t = raw[i].trim();
      if (t.isEmpty) continue;
      final top = 1.0 - (i + 1) * step;
      // Line height 0.8 step: consecutive lines sit close like real print; a
      // blank line in the text becomes a gap the segmenter reads as a break.
      lines.add(MenuOCRLine(t, Rect.fromLTRB(0.05, top, 0.95, top + step * 0.8)));
    }
    return MenuPage(index, lines);
  }
}

class MenuClaim {
  final String entryKey;
  final String matchedText;
  final bool inheritedFromHeader;
  final ProteinFamily? appliesTo;

  /// The item the claim modifies, as printed and lower-cased: "tiger shrimp"
  /// for "Wild Tiger Shrimp", "salmon" for "Glen Cairn Salmon".
  final String? subject;

  /// Not printed on the menu but implied ("organic salmon" → farmed).
  final bool inferred;

  const MenuClaim({
    required this.entryKey,
    required this.matchedText,
    required this.inheritedFromHeader,
    this.appliesTo,
    this.subject,
    this.inferred = false,
  });
}

class MenuItem {
  final String id;
  String dishName;
  String description;
  String? section;
  List<ProteinFamily> proteins;
  List<MenuClaim> claims;
  bool minorProteinOnly;
  bool dismissed;
  bool userCorrected;

  /// Optional add-ons printed under the dish ("Lobster", "Seared Duck Foie Gras").
  List<String> addOns;

  /// Proteins that reach the dish only through an add-on; also listed in [proteins].
  List<ProteinFamily> addOnProteins;

  MenuItem({
    required this.id,
    required this.dishName,
    required this.description,
    required this.section,
    required this.proteins,
    required this.claims,
    required this.minorProteinOnly,
    this.dismissed = false,
    this.userCorrected = false,
    List<String>? addOns,
    List<ProteinFamily>? addOnProteins,
  })  : addOns = addOns ?? <String>[],
        addOnProteins = addOnProteins ?? <ProteinFamily>[];

  String get fullText =>
      [dishName, description, ...addOns].where((s) => s.isNotEmpty).join('\n');
}

class MenuResult {
  final DateTime capturedAt;
  final List<MenuPage> pages;
  final List<String> headerStatements;
  final List<MenuItem> items;
  final String glossaryVersion;
  final String? diningState;
  final bool layoutUncertain;

  MenuResult({
    required this.capturedAt,
    required this.pages,
    required this.headerStatements,
    required this.items,
    required this.glossaryVersion,
    required this.diningState,
    required this.layoutUncertain,
  });

  /// Dishes the diner hasn't dismissed; garnish-level proteins sink to the end.
  List<MenuItem> get visibleItems {
    final live = items.where((i) => !i.dismissed).toList();
    return [
      ...live.where((i) => !i.minorProteinOnly),
      ...live.where((i) => i.minorProteinOnly),
    ];
  }
}
