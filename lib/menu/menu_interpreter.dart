import 'dart:ui' show Rect;

import 'menu_lexicon.dart';
import 'menu_models.dart';

// MenuInterpreter — a parallel branch off OCR, beside LabelInterpreter and the
// service-case parser. Never touches FATResult, Status, or any network lookup.
// Four pure stages (Dart port of iOS MenuInterpreter.swift):
//   1. MenuSegmenter        OCR lines → dish blocks (columns, prices, headers)
//   2. MenuProteinClassifier block → protein families (+ garnish detection)
//   3. MenuClaimExtractor   block → claim phrases matched against the glossary
//   4. MenuClaimExplainer   claims → cards + top three questions (menu_explainer.dart)

class MenuInterpreter {
  final MenuGlossary glossary;
  MenuInterpreter(this.glossary);

  int _seq = 0;
  String _id() => 'dish-${_seq++}';

  MenuResult interpret(List<MenuPage> pages, {String? diningState, DateTime? capturedAt}) {
    final seg = MenuSegmenter.segment(pages);
    final extractor = MenuClaimExtractor(glossary);
    final items = <MenuItem>[];

    for (final block in seg.blocks) {
      final cls = MenuProteinClassifier.classify(block.text);
      var proteins = List<ProteinFamily>.from(cls.proteins);
      if (proteins.isEmpty && (block.sectionProteins?.isNotEmpty ?? false)) {
        proteins = List.of(block.sectionProteins!);
      }

      final claims = extractor.extract(block.text, proteins, inherited: false);
      for (final statement in block.headerStatements) {
        for (final c in extractor.extract(statement, proteins, inherited: true)) {
          if (claims.any((x) => x.entryKey == c.entryKey)) continue;
          // "All our beef is grass-fed" only reaches dishes with beef.
          if (c.appliesTo != null && !proteins.contains(c.appliesTo)) continue;
          claims.add(c);
        }
      }

      if (proteins.isEmpty && claims.isEmpty) continue;

      items.add(MenuItem(
        id: _id(),
        dishName: block.title,
        description: block.description,
        section: block.section,
        proteins: proteins,
        claims: claims,
        minorProteinOnly: cls.minorOnly,
      ));
    }

    return MenuResult(
      capturedAt: capturedAt ?? DateTime.now(),
      pages: pages,
      headerStatements: seg.allHeaderStatements,
      items: items,
      glossaryVersion: glossary.version,
      diningState: diningState,
      layoutUncertain: seg.layoutUncertain,
    );
  }

  /// Re-runs extraction for one dish after the diner corrects its proteins.
  /// Inherited header claims the dish already had are kept when still valid.
  MenuItem reinterpret(MenuItem item, MenuResult result) {
    final extractor = MenuClaimExtractor(glossary);
    final claims = extractor.extract(item.fullText, item.proteins, inherited: false);
    for (final statement in result.headerStatements) {
      for (final c in extractor.extract(statement, item.proteins, inherited: true)) {
        if (claims.any((x) => x.entryKey == c.entryKey)) continue;
        if (!item.claims.any((x) => x.inheritedFromHeader && x.entryKey == c.entryKey)) continue;
        if (c.appliesTo != null && !item.proteins.contains(c.appliesTo)) continue;
        claims.add(c);
      }
    }
    item.claims = claims;
    item.minorProteinOnly = false;
    item.userCorrected = true;
    return item;
  }
}

// ── 1. Segmenter ────────────────────────────────────────────────────────────

class MenuBlock {
  final List<String> lines;
  final String? section;
  final List<ProteinFamily>? sectionProteins;
  final List<String> headerStatements;
  MenuBlock(this.lines, this.section, this.sectionProteins, this.headerStatements);

  String get title => MenuText.stripPrice(lines.isEmpty ? '' : lines.first);
  String get description => lines
      .skip(1)
      .map(MenuText.stripPrice)
      .where((s) => s.isNotEmpty)
      .join(', ');
  String get text => [title, description].where((s) => s.isNotEmpty).join('\n');
}

class MenuSegmentation {
  final List<MenuBlock> blocks;
  final List<String> allHeaderStatements;
  final bool layoutUncertain;
  MenuSegmentation(this.blocks, this.allHeaderStatements, this.layoutUncertain);
}

class MenuSegmenter {
  static MenuSegmentation segment(List<MenuPage> pages) {
    final blocks = <MenuBlock>[];
    final statements = <String>[];
    var uncertain = false;

    final sortedPages = [...pages]..sort((a, b) => a.index.compareTo(b.index));
    for (final page in sortedPages) {
      final merged = mergeSameRowPrices(page.lines.where((l) => !isBoilerplate(l.text)).toList());
      final (columns, columnUncertain) = clusterColumns(merged);
      uncertain = uncertain || columnUncertain;

      final pageBlocks = <MenuBlock>[];
      final pageLevel = <String>[];

      for (final column in columns) {
        final lines = [...column]..sort((a, b) {
            if ((a.maxY - b.maxY).abs() > 0.004) return b.maxY.compareTo(a.maxY);
            return a.minX.compareTo(b.minX);
          });
        final medianH = _median(lines.map((l) => l.height).toList()) ?? 0.02;

        String? section;
        List<ProteinFamily>? sectionProteins;
        var sectionStatements = <String>[];
        var afterLastDish = <String>[];
        var current = <String>[];
        var priced = false;
        var hasDescription = false;
        MenuOCRLine? previous;

        void close() {
          if (current.isNotEmpty) {
            pageBlocks.add(MenuBlock(List.of(current), section, sectionProteins,
                List.of(sectionStatements)));
            afterLastDish = [];
          }
          current = [];
          priced = false;
          hasDescription = false;
        }

        void endSection() {
          // A statement with no dishes after it (a footer) applies to the page.
          pageLevel.addAll(afterLastDish);
          afterLastDish = [];
        }

        for (final line in lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;

          if (previous != null && previous.minY - line.maxY > medianH * 1.2) close();
          previous = line;

          final header = MenuText.sectionHeader(text);
          if (header != null) {
            close();
            endSection();
            section = header;
            final hp = MenuProteinClassifier.classify(header).proteins;
            sectionProteins = hp.isEmpty ? null : hp;
            sectionStatements = [];
            continue;
          }

          if (MenuText.isHeaderStatement(text)) {
            close();
            sectionStatements.add(text);
            afterLastDish.add(text);
            statements.add(text);
            continue;
          }

          if (MenuText.isPriceOnly(text)) {
            if (current.isNotEmpty) {
              current.add(text);
              close();
            }
            continue;
          }

          final title = MenuText.looksLikeTitle(text);
          bool startsNew;
          if (current.isEmpty) {
            startsNew = false;
          } else if (priced) {
            startsNew = title || MenuText.hasTrailingPrice(text);
          } else if (title && hasDescription) {
            startsNew = true;
          } else if (title && MenuText.isAllCaps(current.first) && MenuText.isAllCaps(text)) {
            // Consecutive ALL-CAPS course names on an unpriced tasting menu.
            startsNew = true;
          } else {
            startsNew = false;
          }
          if (startsNew) close();

          current.add(text);
          if (MenuText.hasTrailingPrice(text)) priced = true;
          if (current.length > 1 && !title) hasDescription = true;
          if (current.length > 1 && title && !MenuText.isAllCaps(text) && MenuText.isAllCaps(current[0])) {
            hasDescription = true;
          }
        }
        close();
        endSection();
      }

      if (pageLevel.isNotEmpty) {
        for (final b in pageBlocks) {
          for (final s in pageLevel) {
            if (!b.headerStatements.contains(s)) b.headerStatements.add(s);
          }
        }
      }
      blocks.addAll(pageBlocks);
    }
    return MenuSegmentation(blocks, statements, uncertain);
  }

  /// OCR often returns "Halibut ......" and "38" as separate observations.
  /// Glue a price-only observation onto the line to its left on the same row.
  static List<MenuOCRLine> mergeSameRowPrices(List<MenuOCRLine> lines) {
    final result = List<MenuOCRLine>.of(lines);
    final removed = <int>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!MenuText.isPriceOnly(line.text)) continue;
      int? best;
      for (var j = 0; j < lines.length; j++) {
        if (j == i || removed.contains(j)) continue;
        final other = lines[j];
        if (MenuText.isPriceOnly(other.text)) continue;
        final sameRow = (other.midY - line.midY).abs() <
            (line.height > other.height ? line.height : other.height) * 0.6;
        if (other.maxX <= line.minX + 0.02 && sameRow) {
          if (best == null || other.maxX > lines[best].maxX) best = j;
        }
      }
      if (best == null) continue;
      final t = result[best];
      result[best] = MenuOCRLine('${t.text} ${line.text}', t.box.expandToInclude(line.box));
      removed.add(i);
    }
    return [
      for (var i = 0; i < result.length; i++)
        if (!removed.contains(i)) result[i]
    ];
  }

  /// Splits a page into columns by left edge. Returns uncertain = true when
  /// clusters overlap and the page falls back to a single column.
  static (List<List<MenuOCRLine>>, bool) clusterColumns(List<MenuOCRLine> lines) {
    if (lines.length < 6) return ([lines], false);
    final sorted = [...lines]..sort((a, b) => a.minX.compareTo(b.minX));
    final clusters = <List<MenuOCRLine>>[
      [sorted.first]
    ];
    for (final line in sorted.skip(1)) {
      if (line.minX - clusters.last.last.minX > 0.15) {
        clusters.add([line]);
      } else {
        clusters.last.add(line);
      }
    }
    final merged = <List<MenuOCRLine>>[];
    for (final c in clusters) {
      if (c.length < 3 && merged.isNotEmpty) {
        merged.last.addAll(c);
      } else {
        merged.add(c);
      }
    }
    if (merged.length <= 1) return ([lines], false);

    for (var k = 0; k < merged.length - 1; k++) {
      final nextLeft = merged[k + 1].map((l) => l.minX).reduce((a, b) => a < b ? a : b);
      final overruns = merged[k].where((l) => l.maxX > nextLeft + 0.05).length;
      if (overruns / merged[k].length > 0.3) return ([lines], true);
    }
    return (merged, false);
  }

  static bool isBoilerplate(String text) {
    final t = text.toLowerCase();
    const markers = [
      'consuming raw', 'undercooked', 'foodborne illness', 'gratuity', 'service charge',
      'please inform', 'allerg', 'before placing your order', 'split plate', 'corkage',
      'prices subject', 'tax not included', 'www.', '@', 'instagram', 'reservations',
    ];
    return markers.any(t.contains);
  }

  static double? _median(List<double> v) {
    if (v.isEmpty) return null;
    final s = [...v]..sort();
    return s[s.length ~/ 2];
  }
}

// ── Text helpers ────────────────────────────────────────────────────────────

class MenuText {
  static const _priceCore =
      r'(?:[$£€¥]\s?)?\d{1,4}(?:[.,]\d{1,2})?(?:\s?/\s?(?:[$£€¥]\s?)?\d{1,4}(?:[.,]\d{1,2})?)?';
  static const _marketPrice = r'(?:mp|m\.p\.|market price|market)';

  static final _priceOnly = RegExp('^\\+?\\s?(?:$_priceCore|$_marketPrice)\$', caseSensitive: false);
  static final _trailingPrice =
      RegExp('(?:\\s|\\.{2,}|…|\\|)+\\+?\\s?(?:$_priceCore|$_marketPrice)\\s*\$', caseSensitive: false);

  static bool isPriceOnly(String text) => _priceOnly.hasMatch(text.trim());
  static bool hasTrailingPrice(String text) => _trailingPrice.hasMatch(text);

  static String stripPrice(String text) {
    var t = text;
    final m = _trailingPrice.firstMatch(t);
    if (m != null) t = t.replaceRange(m.start, m.end, '');
    return _trim(t, ' .…-–—|·*\t');
  }

  static String _trim(String s, String chars) {
    var a = 0, b = s.length;
    while (a < b && chars.contains(s[a])) {
      a++;
    }
    while (b > a && chars.contains(s[b - 1])) {
      b--;
    }
    return s.substring(a, b);
  }

  static bool isAllCaps(String text) {
    final letters = text.runes.where((r) => _isLetter(r)).toList();
    if (letters.length < 3) return false;
    final s = String.fromCharCodes(letters);
    return s == s.toUpperCase();
  }

  static bool _isLetter(int r) => RegExp(r'\p{L}', unicode: true).hasMatch(String.fromCharCode(r));

  static bool looksLikeTitle(String text) {
    final t = stripPrice(text);
    final first = RegExp(r'[\p{L}\p{N}]', unicode: true).firstMatch(t);
    if (first == null) return false;
    final ch = first.group(0)!;
    if (RegExp(r'\p{Ll}', unicode: true).hasMatch(ch)) return false;
    if (t.contains(',') || t.endsWith('.')) return false;
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 7;
  }

  static const _sectionWords = <String>{
    'starters', 'appetizers', 'appetisers', 'small plates', 'large plates', 'plates', 'entrees',
    'entrées', 'mains', 'main', 'main courses', 'main course', 'from the sea', 'from the land',
    'sea', 'land', 'raw bar', 'crudo', 'sushi', 'sashimi', 'nigiri', 'maki', 'rolls', 'sides',
    'side dishes', 'desserts', 'dessert', 'salads', 'soups', 'soup', 'pasta', 'pastas', 'primi',
    'secondi', 'antipasti', 'contorni', 'dolci', 'to share', 'for the table', 'for two', 'grill',
    'from the grill', 'wood fire', 'steaks', 'chops', 'steaks & chops', 'steaks and chops',
    'seafood', 'fish', 'poultry', 'burgers', 'sandwiches', 'brunch', 'lunch', 'dinner',
    'tasting menu', "chef's tasting", 'the menu', 'caviar', 'oysters', 'shellfish', 'meat',
    'meats', 'first course', 'second course', 'third course', "hors d'oeuvres", 'à la carte',
    'a la carte', 'prix fixe', 'kids', 'beverages', 'drinks',
  };

  /// Returns the header text if the whole line is a known section name.
  static String? sectionHeader(String text) {
    final cleaned = _trim(text.toLowerCase().replaceAll('’', "'"), ' .,:;!?-–—*()[]"\'\t');
    return _sectionWords.contains(cleaned) ? text.trim() : null;
  }

  static final _statementPatterns = [
    RegExp(r'^\W*(all|every|each)\s+(of\s+)?(our|the)?\s*\w+.*\b(is|are)\b'),
    RegExp(r'^\W*our\s+[\w\s-]+\s+(is|are|comes?|come)\b'),
    RegExp(r'^\W*we\s+(serve|source|use|buy|proudly|only|work)\b'),
    RegExp(r'^\W*(proudly\s+)?(sourced|raised)\s+(from|by|in)\b'),
  ];

  /// "All our beef is grass-fed", "We source our seafood from…".
  static bool isHeaderStatement(String text) {
    final t = text.toLowerCase().replaceAll('’', "'");
    return _statementPatterns.any((p) => p.hasMatch(t));
  }
}

// ── Phrase matching (shared by stages 2 and 3) ──────────────────────────────

class PhraseMatch {
  final int start, end; // string offsets, end exclusive
  final int wordStart, wordEnd, clause;
  PhraseMatch(this.start, this.end, this.wordStart, this.wordEnd, this.clause);
  bool overlaps(PhraseMatch o) => start < o.end && o.start < end;
}

class MenuMatcher {
  /// Whole-word, case-insensitive pattern tolerant of hyphen/space and
  /// straight/curly apostrophe variants.
  static RegExp regexFor(String phrase) {
    final b = StringBuffer(r'(?<![\p{L}\p{N}])');
    for (final ch in phrase.toLowerCase().split('')) {
      switch (ch) {
        case ' ':
        case '-':
          b.write(r'[\s\-‐–]+');
        case "'":
        case '’':
          b.write("['’]?");
        default:
          b.write(RegExp.escape(ch));
      }
    }
    b.write(r'(?![\p{L}\p{N}])');
    return RegExp(b.toString(), caseSensitive: false, unicode: true);
  }

  static Tokenized tokenize(String text) {
    final starts = <int>[];
    final clauses = <int>[];
    var clause = 0;
    var inWord = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      final wordChar = RegExp(r"[\p{L}\p{N}'’]", unicode: true).hasMatch(c);
      if (wordChar) {
        if (!inWord) {
          starts.add(i);
          clauses.add(clause);
          inWord = true;
        }
      } else {
        inWord = false;
        if (',;|·•/\n()'.contains(c)) clause++;
      }
    }
    return Tokenized(text, starts, clauses);
  }

  /// Longest-first, non-overlapping matches. `taken` accumulates claimed spans.
  static List<(String, PhraseMatch)> matches(
    List<(String, RegExp)> phrases,
    Tokenized tok,
    List<(int, int)> taken,
  ) {
    final found = <(String, PhraseMatch)>[];
    for (final (phrase, re) in phrases) {
      for (final m in re.allMatches(tok.text)) {
        if (taken.any((t) => t.$1 < m.end && m.start < t.$2)) continue;
        taken.add((m.start, m.end));
        final ws = tok.wordIndex(m.start);
        final we = tok.wordIndex(m.end - 1);
        found.add((
          phrase,
          PhraseMatch(m.start, m.end, ws, we, tok.clauseOfWord.isEmpty ? 0 : tok.clauseOfWord[ws])
        ));
      }
    }
    found.sort((a, b) => a.$2.start.compareTo(b.$2.start));
    return found;
  }
}

class Tokenized {
  final String text;
  final List<int> wordStarts;
  final List<int> clauseOfWord;
  Tokenized(this.text, this.wordStarts, this.clauseOfWord);

  int wordIndex(int offset) {
    var lo = 0, hi = wordStarts.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (wordStarts[mid] <= offset) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

// ── 2. ProteinClassifier ────────────────────────────────────────────────────

class ProteinHit {
  final List<ProteinFamily> family;
  final PhraseMatch match;
  final bool minor;
  ProteinHit(this.family, this.match, this.minor);
}

class ProteinClassification {
  final List<ProteinFamily> proteins;
  final bool minorOnly;
  final List<ProteinHit> matches;
  ProteinClassification(this.proteins, this.minorOnly, this.matches);
}

class MenuProteinClassifier {
  static final List<(String, RegExp, List<ProteinFamily>)> _lexicon = () {
    final rows = [...kProteinLexiconRaw]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return [
      for (final (w, fams) in rows)
        (w, MenuMatcher.regexFor(w), fams.map((f) => ProteinFamily.parse(f)!).toList())
    ];
  }();

  static final List<(String, RegExp)> _garnish = () {
    final g = [...kGarnishPhrases]..sort((a, b) => b.length.compareTo(a.length));
    return [for (final p in g) (p, MenuMatcher.regexFor(p))];
  }();

  static ProteinClassification classify(String text) {
    final tok = MenuMatcher.tokenize(text);
    final garnish = MenuMatcher.matches(_garnish, tok, <(int, int)>[]);

    final taken = <(int, int)>[];
    final pairs = [for (final r in _lexicon) (r.$1, r.$2)];
    final familyFor = <String, List<ProteinFamily>>{};
    for (final r in _lexicon) {
      familyFor.putIfAbsent(r.$1, () => r.$3);
    }
    final hits = MenuMatcher.matches(pairs, tok, taken);

    final all = <ProteinHit>[];
    for (final (phrase, m) in hits) {
      final minor = garnish.any((g) => g.$2.overlaps(m));
      all.add(ProteinHit(familyFor[phrase] ?? [ProteinFamily.other], m, minor));
    }

    final major = all.where((h) => !h.minor).toList();
    final source = major.isEmpty ? all : major;
    final proteins = <ProteinFamily>[];
    for (final h in source) {
      for (final f in h.family) {
        if (!proteins.contains(f)) proteins.add(f);
      }
    }
    // A generic "meat" adds nothing once a specific protein is present.
    final specificOther = source.any((h) =>
        h.family.length == 1 &&
        h.family.first == ProteinFamily.other &&
        !const ['meat', 'meats'].contains(tok.text.substring(h.match.start, h.match.end).toLowerCase()));
    if (proteins.length > 1 && !specificOther) {
      proteins.remove(ProteinFamily.other);
    }
    return ProteinClassification(proteins, major.isEmpty && all.isNotEmpty, all);
  }
}

// ── 3. ClaimExtractor ───────────────────────────────────────────────────────

class MenuClaimExtractor {
  final MenuGlossary glossary;
  late final List<(String, RegExp, ClaimEntry)> _phraseIndex;
  late final List<(RegExp, ClaimEntry)> _patternIndex;

  /// Words either side of a claim that count as "next to" a protein.
  static const adjacencyWindow = 4;

  /// Protein names that contain a place word but aren't an origin claim.
  static const shadowPhrases = ['cornish hen', 'cornish game hen', 'rock cornish', 'california roll'];

  MenuClaimExtractor(this.glossary) {
    final rows = <(String, RegExp, ClaimEntry)>[];
    final pats = <(RegExp, ClaimEntry)>[];
    for (final e in glossary.entries) {
      for (final p in e.phrases) {
        rows.add((p, MenuMatcher.regexFor(p), e));
      }
      for (final p in e.patterns) {
        pats.add((RegExp(p, unicode: true), e));
      }
    }
    rows.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    _phraseIndex = rows;
    _patternIndex = pats;
  }

  List<MenuClaim> extract(String text, List<ProteinFamily> dishProteins, {required bool inherited}) {
    final tok = MenuMatcher.tokenize(text);
    final proteinHits = MenuProteinClassifier.classify(text).matches;

    final taken = <(int, int)>[];
    for (final s in shadowPhrases) {
      for (final m in MenuMatcher.regexFor(s).allMatches(text)) {
        taken.add((m.start, m.end));
      }
    }

    final claims = <MenuClaim>[];
    final seen = <String>{};

    void consider(ClaimEntry entry, PhraseMatch match) {
      if (seen.contains(entry.key)) return;

      final nearby = <(List<ProteinFamily>, int)>[];
      for (final p in proteinHits) {
        if (p.match.clause != match.clause || p.match.overlaps(match)) continue;
        final d = p.match.wordStart > match.wordEnd
            ? p.match.wordStart - match.wordEnd
            : match.wordStart - p.match.wordEnd;
        if (d <= adjacencyWindow) nearby.add((p.family, d));
      }
      nearby.sort((a, b) => a.$2.compareTo(b.$2));

      // The claim may itself be a protein word ("salmon", "veal").
      List<ProteinFamily>? selfProtein;
      for (final p in proteinHits) {
        if (p.match.overlaps(match)) {
          selfProtein = p.family;
          break;
        }
      }

      if (entry.adjacentProtein && nearby.isEmpty && selfProtein == null) return;

      ProteinFamily? target =
          nearby.isNotEmpty ? nearby.first.$1.first : (selfProtein?.first);
      final allowed = entry.proteins;
      if (allowed != null) {
        if (target != null && !allowed.contains(target)) {
          target = null;
          for (final n in nearby) {
            for (final f in n.$1) {
              if (allowed.contains(f)) {
                target ??= f;
              }
            }
          }
          if (target == null && entry.adjacentProtein) return;
        }
        final pool = dishProteins.isEmpty ? (selfProtein ?? const <ProteinFamily>[]) : dishProteins;
        if (pool.isNotEmpty && !pool.any(allowed.contains)) return;
      }

      seen.add(entry.key);
      claims.add(MenuClaim(
        entryKey: entry.key,
        matchedText: text.substring(match.start, match.end),
        inheritedFromHeader: inherited,
        appliesTo: target,
      ));
    }

    final pairs = [for (final r in _phraseIndex) (r.$1, r.$2)];
    final entryFor = <String, ClaimEntry>{};
    for (final r in _phraseIndex) {
      entryFor.putIfAbsent(r.$1, () => r.$3);
    }
    final hits = [
      for (final (phrase, m) in MenuMatcher.matches(pairs, tok, taken)) (entryFor[phrase]!, m)
    ];

    for (final (re, entry) in _patternIndex) {
      for (final m in re.allMatches(text)) {
        if (taken.any((t) => t.$1 < m.end && m.start < t.$2)) continue;
        taken.add((m.start, m.end));
        final ws = tok.wordIndex(m.start);
        final we = tok.wordIndex(m.end - 1);
        hits.add((
          entry,
          PhraseMatch(m.start, m.end, ws, we, tok.clauseOfWord.isEmpty ? 0 : tok.clauseOfWord[ws])
        ));
      }
    }

    hits.sort((a, b) => a.$2.start.compareTo(b.$2.start));
    for (final (entry, m) in hits) {
      consider(entry, m);
    }
    return claims;
  }
}

/// Used by tests and the OCR adapter to build a normalized, bottom-left-origin
/// box from a top-left-origin pixel box.
Rect normalizedBottomLeft(Rect px, double w, double h) => Rect.fromLTRB(
      px.left / w,
      1.0 - px.bottom / h, // minY (bottom-left origin)
      px.right / w,
      1.0 - px.top / h, // maxY
    );
