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
      // "(Add Lobster $35 Supplement)" — an optional protein still belongs to
      // the dish, but is labeled as an add-on.
      final addOnProteins = <ProteinFamily>[];
      if (block.addOns.isNotEmpty) {
        for (final f in MenuProteinClassifier.classify(block.addOnText).proteins) {
          if (!proteins.contains(f)) addOnProteins.add(f);
        }
        proteins.addAll(addOnProteins);
      }

      final claims = extractor.extract(block.fullText, proteins, inherited: false);
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
        minorProteinOnly: cls.minorOnly && addOnProteins.isEmpty,
        addOns: [
          for (final a in block.addOns)
            if (MenuText.addOnLabel(a).isNotEmpty) MenuText.addOnLabel(a)
        ],
        addOnProteins: addOnProteins,
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
    item.addOnProteins = item.addOnProteins.where(item.proteins.contains).toList();
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

  /// Add-on / supplement lines attached to this dish, as printed.
  final List<String> addOns;
  MenuBlock(this.lines, this.section, this.sectionProteins, this.headerStatements,
      [List<String>? addOns])
      : addOns = addOns ?? <String>[];

  String get title => MenuText.stripPrice(lines.isEmpty ? '' : lines.first);
  String get description => lines
      .skip(1)
      .map(MenuText.stripPrice)
      .where((s) => s.isNotEmpty)
      .join(', ');
  String get text => [title, description].where((s) => s.isNotEmpty).join('\n');
  String get addOnText => addOns.join('\n');

  /// Dish text plus add-on lines — what claims are extracted from.
  String get fullText => addOns.isEmpty ? text : '$text\n$addOnText';
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
        final columnFirstBlock = pageBlocks.length;
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
        var addOns = <String>[];
        var priced = false;
        var hasDescription = false;
        MenuOCRLine? previous;

        void close() {
          if (current.isNotEmpty) {
            pageBlocks.add(MenuBlock(List.of(current), section, sectionProteins,
                List.of(sectionStatements), List.of(addOns)));
            afterLastDish = [];
          }
          current = [];
          addOns = [];
          priced = false;
          hasDescription = false;
        }

        void endSection() {
          // A statement with no dishes after it (a footer) applies to the page.
          pageLevel.addAll(afterLastDish);
          afterLastDish = [];
        }

        for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          final line = lines[lineIndex];
          final text = line.text.trim();
          if (text.isEmpty) continue;

          if (previous != null && previous.minY - line.maxY > medianH * 1.2) close();
          previous = line;

          String? nextText;
          for (final l in lines.skip(lineIndex + 1)) {
            if (l.text.trim().isNotEmpty) {
              nextText = l.text.trim();
              break;
            }
          }
          final header = MenuText.sectionHeader(text) ?? MenuText.genericSectionHeader(text, nextText);
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

          if (MenuText.isAddOn(text)) {
            // Supplements belong to the dish above, never a dish of their own.
            if (current.isNotEmpty) {
              addOns.add(text);
              continue;
            } else if (pageBlocks.length > columnFirstBlock) {
              pageBlocks.last.addOns.add(text);
              continue;
            }
          }

          final title = MenuText.looksLikeTitle(text);
          // "CAVATELLI PASTA, BERKSHIRE PORK OSSO BUCO RAGU": an upper-case dish
          // name can carry commas, and still starts a new dish.
          final capsTitle = MenuText.isCapsTitle(text);
          bool startsNew;
          if (current.isEmpty) {
            startsNew = false;
          } else if (priced) {
            startsNew = title || MenuText.hasTrailingPrice(text);
          } else if (title && hasDescription) {
            startsNew = true;
          } else if (capsTitle && hasDescription && current.any((l) => !MenuText.isCapsTitle(l))) {
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
          if (current.length > 1 && !title && !capsTitle) hasDescription = true;
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
    'classics', 'the classics', 'seasonal', 'seasonal specials', 'specials', 'daily specials',
    "chef's specials", 'features', 'signatures', 'house specialties', 'sides to share', 'shared sides',
    'small bites', 'bites', 'snacks', 'shareables', 'large format', 'accompaniments', 'enhancements',
    'add-ons', 'vegetables', 'greens', 'from the garden', 'pizza', 'pizzas', 'noodles', 'sweets',
    'cheese', 'cheeses', 'entrée', 'entree', 'main plates', 'kids menu', "children's menu",
  };

  /// "C L A S S I C S" → "CLASSICS"; "S I D E S  T O  S H A R E" → "SIDES TO SHARE".
  /// Words are separated by two or more spaces; anything else is returned unchanged.
  static String collapseLetterSpacing(String text) {
    final t = text.trim();
    final groups = t.split('  ').map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
    final split = [for (final g in groups) g.split(' ').where((p) => p.isNotEmpty).toList()];
    if (split.isEmpty ||
        !split.every((g) => g.every((p) => p.runes.length == 1)) ||
        split.fold<int>(0, (n, g) => n + g.length) < 4) {
      return t;
    }
    return split.map((g) => g.join()).join(' ');
  }

  /// Returns the header text if the whole line is a known section name.
  static String? sectionHeader(String text) {
    final collapsed = collapseLetterSpacing(text);
    final cleaned = _trim(collapsed.toLowerCase().replaceAll('’', "'"), ' .,:;!?-–—*()[]"\'\t');
    return _sectionWords.contains(cleaned) ? collapsed : null;
  }

  /// An unlisted section name: a short ALL-CAPS line (1–3 words) with no
  /// digits, punctuation or protein word, directly followed by an upper-case
  /// dish title rather than a description.
  static String? genericSectionHeader(String text, String? next) {
    final t = collapseLetterSpacing(text);
    if (next == null || !isCapsTitle(next) || !isAllCaps(t)) return null;
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words < 1 || words > 3) return null;
    if (RegExp(r'[\p{Nd},()*$:]', unicode: true).hasMatch(t)) return null;
    if (MenuProteinClassifier.classify(t).proteins.isNotEmpty) return null;
    return t;
  }

  /// Strips "(GF)"-style tags, footnote stars and tokens with digits ("32oz").
  static String _titleCore(String text) {
    final t = stripPrice(text).replaceAll(RegExp(r'\([^)]*\)'), ' ');
    return t
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !RegExp(r'\p{N}', unicode: true).hasMatch(w))
        .join(' ');
  }

  /// The part before the first comma is upper case ("BAKED JAPANESE SWEET
  /// POTATO, Miso Butter"), so the line is a dish title even with commas.
  static bool isCapsTitle(String text) {
    final first = _titleCore(text).split(',').first;
    if (!isAllCaps(first)) return false;
    return first.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 10;
  }

  static final _addOnStart = RegExp(
      r'^[\(\[]?\s*(\+\s*[$£€]?\s*\d|\+\s*\p{L}|add\b|add-on|supplement\b|enhance\b|with the addition)',
      unicode: true);
  static final _addOnParen = RegExp(r'^\(.*\b(add|supplement)\b.*\)$');

  /// "(Add Lobster $35 Supplement)", "Add foie gras +18", "+ $12 shrimp", "Supplement: truffle".
  static bool isAddOn(String text) {
    final t = text.trim().toLowerCase();
    return _addOnStart.hasMatch(t) || _addOnParen.hasMatch(t);
  }

  /// "(Add 2oz Seared Duck Foie Gras for $15 Supplement)" → "Seared Duck Foie Gras".
  static String addOnLabel(String text) {
    var t = text.replaceAll(RegExp(r'[\(\)\[\]]'), ' ');
    t = t.replaceAll(RegExp(r'\+?\s*[$£€]\s?\d+(?:[.,]\d{1,2})?'), ' ');
    t = t.replaceAll(RegExp(r'\b\d+\s?(?:oz|g|pc|pcs|piece|pieces)\b', caseSensitive: false), ' ');
    t = t.replaceAll(
        RegExp(r'\b(?:add-on|add|supplement|for|extra|optional|enhance|with the addition of)\b',
            caseSensitive: false),
        ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return _trim(t, ' +:;,.-–—*\t');
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
  /// Dish names whose usual species ("osso buco" → veal) yields to a species word in front.
  static const speciesDefaultDishes = <String>{
    'osso buco', 'ragu', 'ragù', 'bolognese', 'meatball', 'meatballs', 'burger', 'burgers',
    'sausage', 'sausages', 'chorizo', 'hot dog',
  };

  /// Plain species words that can modify those dish names.
  static const speciesModifiers = <String>{
    'beef', 'veal', 'pork', 'berkshire', 'kurobuta', 'wagyu', 'angus', 'lamb', 'mutton', 'goat',
    'chicken', 'duck', 'turkey', 'rabbit', 'venison', 'boar', 'wild boar', 'bison', 'elk',
    'lobster', 'crab', 'shrimp', 'octopus', 'fish', 'seafood', 'tuna', 'salmon',
  };

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

    // "PORK OSSO BUCO", "lamb ragù", "chicken sausage": a species word just
    // before a dish name decides the species, not the dish's usual default.
    final modifierHits = [
      for (final h in hits)
        if (speciesModifiers.contains(h.$1.toLowerCase())) h.$2
    ];
    final all = <ProteinHit>[];
    for (final (phrase, m) in hits) {
      if (speciesDefaultDishes.contains(phrase.toLowerCase()) &&
          modifierHits.any((mod) =>
              mod.clause == m.clause && mod.wordEnd < m.wordStart && m.wordStart - mod.wordEnd <= 3)) {
        continue;
      }
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

  /// Claims that describe the item printed right after them: "Wild Tiger
  /// Shrimp" → wild belongs to the tiger shrimp, not the dish.
  static const qualifierKeys = <String>{'wild_caught', 'farm_raised'};

  /// Species claims for which "organic" means farmed (organic salmon is farmed).
  static const organicFarmedSpeciesKeys = <String>{'atlantic_salmon'};

  /// Names found by the named-source heuristic ("GLEN CAIRN SALMON").
  static const menuNamedSourceKey = 'menu_named_source';

  /// Claims shown as "Named source: …".
  static const namedSourceKeys = <String>{'named_source', 'menu_named_source'};

  List<MenuClaim> extract(String text, List<ProteinFamily> dishProteins, {required bool inherited}) {
    final tok = MenuMatcher.tokenize(text);
    final proteinHits = MenuProteinClassifier.classify(text).matches;

    final taken = <(int, int)>[];
    for (final s in shadowPhrases) {
      for (final m in MenuMatcher.regexFor(s).allMatches(text)) {
        taken.add((m.start, m.end));
      }
    }

    final pairs = [for (final r in _phraseIndex) (r.$1, r.$2)];
    final entryFor = <String, ClaimEntry>{};
    for (final r in _phraseIndex) {
      entryFor.putIfAbsent(r.$1, () => r.$3);
    }
    final hits = [for (final (phrase, m) in MenuMatcher.matches(pairs, tok, taken)) (entryFor[phrase]!, m)];

    for (final (re, entry) in _patternIndex) {
      for (final m in re.allMatches(text)) {
        if (taken.any((t) => t.$1 < m.end && m.start < t.$2)) continue;
        taken.add((m.start, m.end));
        final ws = tok.wordIndex(m.start);
        final we = tok.wordIndex(m.end - 1);
        hits.add((entry, PhraseMatch(m.start, m.end, ws, we, tok.clauseOfWord.isEmpty ? 0 : tok.clauseOfWord[ws])));
      }
    }
    hits.sort((a, b) => a.$2.start.compareTo(b.$2.start));
    final speciesHits = [
      for (final h in hits)
        if (h.$1.family == ClaimFamily.speciesOrForm) h,
    ];

    /// The printed name of a protein item: the species claim on it if any
    /// ("tiger shrimp"), else the protein word ("halibut").
    String subjectText(PhraseMatch p) {
      for (final s in speciesHits) {
        if (s.$2.overlaps(p)) return text.substring(s.$2.start, s.$2.end).toLowerCase();
      }
      return text.substring(p.start, p.end).toLowerCase();
    }

    final claims = <MenuClaim>[];
    final positions = <double>[];
    final seen = <String>{};
    PhraseMatch? organicMatch;

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

      ProteinFamily? target = nearby.isNotEmpty ? nearby.first.$1.first : (selfProtein?.first);
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

      // "Wild Tiger Shrimp": the qualifier belongs to the next protein item.
      String? subject;
      if (qualifierKeys.contains(entry.key)) {
        ProteinHit? next;
        for (final p in proteinHits) {
          if (p.match.clause != match.clause || p.match.wordStart <= match.wordEnd) continue;
          if (p.match.wordStart - match.wordEnd > adjacencyWindow) continue;
          if (next == null || p.match.wordStart < next.match.wordStart) next = p;
        }
        if (next != null) {
          subject = subjectText(next.match);
          for (final f in next.family) {
            if (allowed == null || allowed.contains(f)) {
              target = f;
              break;
            }
          }
        }
      }

      seen.add(entry.key);
      if (entry.key == 'organic') organicMatch = match;
      claims.add(
        MenuClaim(
          entryKey: entry.key,
          matchedText: text.substring(match.start, match.end),
          inheritedFromHeader: inherited,
          appliesTo: target,
          subject: subject,
        ),
      );
      positions.add(match.start.toDouble());
    }

    for (final (entry, m) in hits) {
      consider(entry, m);
    }

    if (!inherited) {
      // Named sources in the dish title: "GLEN CAIRN" salmon, "CRESCENT FARMS" duck.
      final sources = MenuNamedSources.find(
        text,
        tok,
        proteinHits,
        taken,
        isKnown: (name, protein) => glossary.knownSource(name, subjectText(protein)) != null,
      );
      if (glossary.entry(menuNamedSourceKey) != null) {
        for (final s in sources) {
          claims.add(
            MenuClaim(
              entryKey: menuNamedSourceKey,
              matchedText: text.substring(s.start, s.end),
              inheritedFromHeader: false,
              appliesTo: s.protein.family.first,
              subject: subjectText(s.protein.match),
            ),
          );
          positions.add(s.start.toDouble());
        }
      }

      // "ORGANIC (GLEN CAIRN) SALMON": organic salmon is farmed. Only a named
      // source may sit between the two words.
      final om = organicMatch;
      if (om != null && !seen.contains('farm_raised') && glossary.entry('farm_raised') != null) {
        final following = [
          for (final p in proteinHits)
            if (p.match.clause == om.clause && p.match.wordStart > om.wordEnd) p,
        ]..sort((a, b) => a.match.wordStart.compareTo(b.match.wordStart));
        if (following.isNotEmpty) {
          final p = following.first;
          (ClaimEntry, PhraseMatch)? species;
          for (final s in speciesHits) {
            if (s.$2.overlaps(p.match)) {
              species = s;
              break;
            }
          }
          var between = true;
          for (var w = om.wordEnd + 1; w < p.match.wordStart; w++) {
            if (!sources.any((s) => s.wordStart <= w && w <= s.wordEnd)) between = false;
          }
          if (species != null && organicFarmedSpeciesKeys.contains(species.$1.key) && between) {
            claims.add(
              MenuClaim(
                entryKey: 'farm_raised',
                matchedText: 'farmed',
                inheritedFromHeader: false,
                appliesTo: ProteinFamily.finfish,
                subject: subjectText(p.match),
                inferred: true,
              ),
            );
            positions.add(species.$2.start + 0.5);
          }
        }
      }
    }

    final order = List<int>.generate(claims.length, (i) => i)
      ..sort((a, b) {
        final c = positions[a].compareTo(positions[b]);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final i in order) claims[i]];
  }
}

// ── 3b. Named sources ───────────────────────────────────────────────────────

/// A farm, ranch, brand or place name printed in a dish title just before the
/// species or cut: "ORGANIC GLEN CAIRN SALMON", "OVEN ROASTED CRYSTAL VALLEY
/// CHICKEN", "GRILLED PRIME ALLEN BROTHERS PORTERHOUSE".
///
/// Conservative: only capitalized words, read backwards from the first protein
/// word in each clause of the title, stopping at a cooking method or a known
/// claim/protein word. Function words, descriptors and lower-case words reject
/// the candidate. A name at the very start of the title needs two words.
class MenuNamedSourceHit {
  final int start, end; // string offsets, end exclusive
  final int wordStart, wordEnd;
  final ProteinHit protein;
  MenuNamedSourceHit(this.start, this.end, this.wordStart, this.wordEnd, this.protein);
}

enum _Edge { start, known, reject }

class MenuNamedSources {
  /// Cooking methods and preparations: a valid left edge for a name.
  static const cookingWords = <String>{
    'grilled',
    'grill',
    'roasted',
    'roast',
    'oven',
    'pan',
    'seared',
    'crusted',
    'braised',
    'provençale',
    'provencale',
    'smoked',
    'fried',
    'poached',
    'baked',
    'broiled',
    'charred',
    'chargrilled',
    'blackened',
    'glazed',
    'cured',
    'confit',
    'sautéed',
    'sauteed',
    'steamed',
    'stuffed',
    'wood',
    'fired',
    'rotisserie',
    'slow',
    'cooked',
    'crispy',
    'marinated',
    'tandoori',
    'jerk',
    'bbq',
    'barbecue',
    'barbecued',
    'sous',
    'vide',
    'torched',
    'seasoned',
    'spiced',
    'rubbed',
    'aged',
    'dry',
    'brined',
    'plancha',
    'griddled',
    'flame',
    'flamed',
    'basted',
    'pressed',
    'pulled',
    'carved',
    'sliced',
    'shaved',
    'raw',
    'herb',
    'pistachio',
    'almond',
    'hazelnut',
    'pecan',
    'parmesan',
    'panko',
    'breaded',
    'battered',
    'teriyaki',
    'miso',
    'honey',
    'maple',
    'citrus',
    'lemon',
    'garlic',
    'pepper',
    'peppercorn',
  };

  /// Words that are never part of a name: function words, sizes, colours,
  /// styles and cuisine adjectives. Meeting one rejects the candidate.
  static const rejectWords = <String>{
    'al',
    'alla',
    'all\'',
    'di',
    'del',
    'della',
    'de',
    'du',
    'des',
    'la',
    'le',
    'les',
    'el',
    'en',
    'au',
    'aux',
    'a',
    'an',
    'the',
    'of',
    'for',
    'with',
    'and',
    'or',
    '&',
    'on',
    'in',
    'our',
    'my',
    'your',
    'half',
    'whole',
    'baby',
    'young',
    'little',
    'big',
    'mini',
    'jumbo',
    'giant',
    'colossal',
    'large',
    'small',
    'lump',
    'bone',
    'boneless',
    'center',
    'cut',
    'thick',
    'double',
    'triple',
    'petite',
    'extra',
    'house',
    'classic',
    'traditional',
    'famous',
    'original',
    'signature',
    'homemade',
    'chef',
    'chef\'s',
    'chefs',
    'family',
    'style',
    'country',
    'southern',
    'hot',
    'spicy',
    'sweet',
    'sour',
    'sticky',
    'salt',
    'marsh',
    'black',
    'white',
    'red',
    'green',
    'blue',
    'golden',
    'gold',
    'pink',
    'yellow',
    'nero',
    'rosso',
    'korean',
    'thai',
    'chinese',
    'japanese',
    'mexican',
    'italian',
    'french',
    'spanish',
    'indian',
    'cajun',
    'creole',
    'greek',
    'moroccan',
    'vietnamese',
    'peruvian',
    'brazilian',
    'argentinian',
    'argentine',
    'turkish',
    'lebanese',
    'persian',
    'szechuan',
    'sichuan',
    'hunan',
    'cantonese',
    'mongolian',
    'hawaiian',
    'caribbean',
    'jamaican',
    'cuban',
    'tuscan',
    'sicilian',
    'roman',
    'neapolitan',
    'parisian',
    'mediterranean',
    'asian',
    'oriental',
    'continental',
    'american',
    'new',
    'fresh',
    'special',
    'daily',
    'seasonal',
    'spaghetti',
    'pasta',
    'risotto',
    'salad',
    'soup',
    'stew',
    'sandwich',
    'tacos',
    'taco',
    'pizza',
    'bowl',
    'plate',
    'platter',
    'board',
    'trio',
    'duo',
    'tasting',
    'surf',
    'turf',
    'mixed',
    'assorted',
    'spring',
    'summer',
    'autumn',
    'fall',
    'winter',
  };

  static final _wordChar = RegExp(r"[\p{L}\p{N}'’]", unicode: true);
  static final _upper = RegExp(r'\p{Lu}', unicode: true);
  static final _digit = RegExp(r'\p{N}', unicode: true);

  static List<MenuNamedSourceHit> find(
    String text,
    Tokenized tok,
    List<ProteinHit> proteinHits,
    List<(int, int)> claimRanges, {
    bool Function(String name, PhraseMatch protein)? isKnown,
  }) {
    final nl = text.indexOf('\n');
    final titleEnd = nl < 0 ? text.length : nl;
    final words = <(int, int)>[];
    for (final s in tok.wordStarts) {
      var e = s;
      while (e < text.length && _wordChar.hasMatch(text[e])) {
        e++;
      }
      words.add((s, e));
    }

    final out = <MenuNamedSourceHit>[];
    final clausesDone = <int>{};
    final sorted = [...proteinHits]..sort((a, b) => a.match.start.compareTo(b.match.start));
    for (final p in sorted) {
      if (p.match.start >= titleEnd || p.minor) continue;
      if (clausesDone.contains(p.match.clause)) continue;
      clausesDone.add(p.match.clause);

      var edge = _Edge.start;
      final candidate = <int>[];
      var w = p.match.wordStart - 1;
      while (w >= 0) {
        if (tok.clauseOfWord[w] != p.match.clause) {
          edge = _Edge.start;
          break;
        }
        final (ws, we) = words[w];
        final word = text.substring(ws, we);
        final lower = word.toLowerCase();
        if (claimRanges.any((r) => r.$1 < we && ws < r.$2) ||
            proteinHits.any((h) => h.match.start < we && ws < h.match.end) ||
            cookingWords.contains(lower)) {
          edge = _Edge.known;
          break;
        }
        if (rejectWords.contains(lower) || _digit.hasMatch(word)) {
          edge = _Edge.reject;
          break;
        }
        if (word.isEmpty || !_upper.hasMatch(word[0])) {
          edge = _Edge.reject;
          break;
        }
        candidate.insert(0, w);
        w--;
      }
      if (candidate.isEmpty || candidate.length > 4) continue;
      final start = words[candidate.first].$1, end = words[candidate.last].$2;
      // A curated name ("Glencairn") passes on its own.
      final known = isKnown?.call(text.substring(start, end), p.match) ?? false;
      if (edge == _Edge.reject && !known) continue;
      if (edge == _Edge.start && candidate.length < 2 && !known) continue;
      out.add(MenuNamedSourceHit(start, end, candidate.first, candidate.last, p));
    }
    return out;
  }

  /// "GLEN CAIRN" → "Glen Cairn"; mixed case is kept as printed.
  static String displayName(String raw) {
    if (!MenuText.isAllCaps(raw)) return raw;
    final b = StringBuffer();
    var prevLetter = false;
    for (final ch in raw.split('')) {
      final isLetter = ch.toLowerCase() != ch.toUpperCase();
      b.write(isLetter ? (prevLetter ? ch.toLowerCase() : ch.toUpperCase()) : ch);
      prevLetter = isLetter;
    }
    return b.toString();
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
