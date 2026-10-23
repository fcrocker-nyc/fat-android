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

  /// OCR height of the first line, to spot small-print descriptions.
  final double firstLineHeight;
  MenuBlock(this.lines, this.section, this.sectionProteins, this.headerStatements,
      [List<String>? addOns, this.firstLineHeight = 0])
      : addOns = addOns ?? <String>[];

  /// "Pacific saury*, Gim bugak, Perilla": on a tasting menu the dish name is
  /// the first item and the rest are its components. Upper-case titles with
  /// commas ("FARM-RAISED, SUSTAINABLE CAVIAR") are kept whole.
  (String, String?) get _titleSplit {
    final first = MenuText.cleanTitle(MenuText.stripPrice(lines.isEmpty ? '' : lines.first));
    final comma = first.indexOf(', ');
    if (comma < 0) return (first, null);
    final head = MenuText._trim(first.substring(0, comma), ' *');
    final rest = first.substring(comma + 2).trim();
    if (MenuText.isAllCaps(head) || rest.isEmpty ||
        head.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length > 5) {
      return (first, null);
    }
    return (head, rest);
  }

  String get title => _titleSplit.$1;
  String get description => [
        if (_titleSplit.$2 != null) _titleSplit.$2!,
        ...lines.skip(1).map(MenuText.stripPrice),
      ].where((s) => s.isNotEmpty).join(', ');
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

/// Dart port of the iOS MenuSegmenter (MenuInterpreter.swift) — keep in sync.
class MenuSegmenter {
  static MenuSegmentation segment(List<MenuPage> pages) {
    final blocks = <MenuBlock>[];
    final statements = <String>[];
    var uncertain = false;

    final sortedPages = [...pages]..sort((a, b) => a.index.compareTo(b.index));
    for (final page in sortedPages) {
      final cleaned = <MenuOCRLine>[];
      for (final l in page.lines) {
        final t = MenuText.dropForeignScript(l.text);
        if (t.isNotEmpty) cleaned.add(MenuOCRLine(t, l.box));
      }
      final merged = mergeSameRowPrices(
          cleaned.where((l) => !isBoilerplate(l.text) && !isWinePairing(l.text)).toList());
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
        final breakGap = dishBreakGap(lines, medianH);
        final groupOf = gapGroups(lines, breakGap);

        String? section;
        List<ProteinFamily>? sectionProteins;
        var sectionStatements = <String>[];
        var afterLastDish = <String>[];
        var current = <String>[];
        var currentHeights = <double>[];
        var addOns = <String>[];
        var priced = false;
        var hasDescription = false;
        MenuOCRLine? previous;

        void close() {
          // "O0", "18/pc", "• 82 per person •": not a dish name.
          while (current.isNotEmpty && MenuText.isJunkTitle(current.first)) {
            current.removeAt(0);
            currentHeights.removeAt(0);
          }
          // Small print right under a one-line dish name is its description,
          // even when a gap (a dropped subtitle line) sits between them; so is
          // a fragment ("Soft poached and chilled prawn,") under a priced title.
          if (current.isNotEmpty &&
              currentHeights.isNotEmpty &&
              !MenuText.isCapsTitle(current.first) &&
              pageBlocks.length > columnFirstBlock &&
              pageBlocks.last.lines.length == 1) {
            final first = current.first;
            final h = currentHeights.first;
            final prev = pageBlocks.last;
            final smaller = !MenuText.looksLikeTitle(first) && h < prev.firstLineHeight * 0.78;
            final fragment = (MenuText.endsMidPhrase(first) || MenuText.startsLowercase(first)) &&
                MenuText.hasTrailingPrice(prev.lines.first);
            if (smaller || fragment) {
              prev.lines.addAll(current);
              prev.addOns.addAll(addOns);
              current = [];
              currentHeights = [];
              addOns = [];
            }
          }
          if (current.isNotEmpty && MenuText.isProse(current)) {
            // An essay paragraph ("Black Angus is the dominant beef breed…")
            // is not a dish; its claim words would only add noise.
            current = [];
            addOns = [];
          }
          if (current.isNotEmpty) {
            pageBlocks.add(MenuBlock(List.of(current), section, sectionProteins,
                List.of(sectionStatements), List.of(addOns), currentHeights.isEmpty ? 0 : currentHeights.first));
            afterLastDish = [];
          }
          current = [];
          currentHeights = [];
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

          // A line that stops mid-phrase ("Crispy gem lettuce, baby arugula,")
          // continues on the next line however far down it is.
          if (previous != null && previous.minY - line.maxY > breakGap && !MenuText.endsMidPhrase(previous.text)) {
            close();
          }
          final prevLine = previous;
          previous = line;

          // "OR" between two tasting-menu choices separates dishes.
          if (MenuText.isSeparator(text)) {
            close();
            continue;
          }

          String? nextText;
          for (final l in lines.skip(lineIndex + 1)) {
            if (l.text.trim().isNotEmpty) {
              nextText = l.text.trim();
              break;
            }
          }
          final header = MenuText.sectionHeader(text) ??
              MenuText.genericSectionHeader(text, nextText) ??
              MenuText.largeHeading(text, line.height, medianH);
          if (header != null && !isDishTitleGroup(lineIndex, lines, groupOf, medianH)) {
            close();
            endSection();
            section = header;
            final hp = MenuProteinClassifier.classify(header).proteins;
            sectionProteins = hp.isEmpty ? null : hp;
            sectionStatements = [];
            continue;
          }

          // A statement line inside an essay paragraph is prose, not a
          // menu-wide sourcing statement.
          final standsAlone = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 16 &&
              !MenuText.endsMidPhrase(text) &&
              !(nextText != null && MenuText.startsLowercase(nextText)) &&
              !(lineIndex > 0 &&
                  MenuText.isProseFragment(lines[lineIndex - 1].text) &&
                  lines[lineIndex - 1].minY - line.maxY <= breakGap);
          if (MenuText.isHeaderStatement(text) && standsAlone) {
            close();
            sectionStatements.add(text);
            afterLastDish.add(text);
            statements.add(text);
            continue;
          }

          if (MenuText.isPriceOnly(text)) {
            if (current.isNotEmpty) {
              current.add(text);
              currentHeights.add(line.height);
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
            startsNew = title || capsTitle || MenuText.hasTrailingPrice(text);
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
          if (startsNew && !(prevLine != null && MenuText.endsMidPhrase(prevLine.text) && prevLine.text != text)) {
            close();
          }

          current.add(text);
          currentHeights.add(line.height);
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

  /// Splits a page into reading-order pieces with a recursive XY-cut: cut at
  /// a clean vertical gutter when one exists (columns), otherwise at a wide
  /// horizontal gap (a new section band), and repeat inside each piece.
  /// Handles centered columns (Le Bernardin) and pages whose column layout
  /// changes partway down (Cote). A right-hand strip of prices is glued onto
  /// the rows it sits beside rather than read as a column.
  static (List<List<MenuOCRLine>>, bool) clusterColumns(List<MenuOCRLine> lines) {
    if (lines.length < 6) return ([lines], false);
    return (_xyCut(lines, 0).where((p) => p.isNotEmpty).toList(), false);
  }

  static List<List<MenuOCRLine>> _xyCut(List<MenuOCRLine> lines, int depth) {
    if (lines.length < 6 || depth >= 8) return [lines];
    final v = _verticalCut(lines);
    if (v != null) {
      final (left, right) = v;
      if (right.isEmpty) return _xyCut(left, depth + 1); // price strip glued on
      return [..._xyCut(left, depth + 1), ..._xyCut(right, depth + 1)];
    }
    final h = _horizontalCut(lines);
    if (h != null) {
      final (top, bottom) = h;
      return [..._xyCut(top, depth + 1), ..._xyCut(bottom, depth + 1)];
    }
    return [lines];
  }

  /// Widest empty vertical strip with real text on both sides.
  static (List<MenuOCRLine>, List<MenuOCRLine>)? _verticalCut(List<MenuOCRLine> lines) {
    final minX = lines.map((l) => l.minX).reduce((a, b) => a < b ? a : b);
    final maxX = lines.map((l) => l.maxX).reduce((a, b) => a > b ? a : b);
    final width = maxX - minX;
    if (width <= 0.1) return null;
    // Banner lines spanning most of the piece don't count against gutters.
    final body = lines.where((l) => l.width < width * 0.6);
    const bins = 300;
    final cover = List<int>.filled(bins, 0);
    for (final l in body) {
      final lo = ((l.minX - minX) / width * (bins - 1)).floor();
      final hi = ((l.maxX - minX) / width * (bins - 1)).floor();
      for (var b = lo < 0 ? 0 : lo; b <= (hi < lo ? lo : hi) && b < bins; b++) {
        cover[b]++;
      }
    }
    // Allow one stray crossing line per gutter.
    (int, int)? best;
    int? runStart;
    for (var b = 0; b <= bins; b++) {
      final empty = b < bins && cover[b] <= 1;
      if (empty && runStart == null) runStart = b;
      if (!empty && runStart != null) {
        final st = runStart;
        if (st > 0 && b < bins && b - st > (best?.$2 ?? 0)) best = (st, b - st);
        runStart = null;
      }
    }
    if (best == null || best.$2 / bins * width < 0.006) return null;
    final cutX = minX + (best.$1 + best.$2 / 2) / bins * width;
    final left = lines.where((l) => l.midX < cutX).toList();
    final right = lines.where((l) => l.midX >= cutX).toList();
    // A short right-hand strip of prices or tags belongs to the rows it sits
    // beside: glue it on and keep reading the left side as one piece.
    final pricey = right
        .where((l) => RegExp(r'\d|price|supplement', caseSensitive: false).hasMatch(l.text))
        .length;
    if (right.isNotEmpty &&
        right.length * 3 < left.length &&
        (right.length < 3 || pricey / right.length >= 0.6)) {
      return (_glueOntoRows(right, left), <MenuOCRLine>[]);
    }
    if (left.length < 3 || right.length < 3) return null;
    return (left, right);
  }

  /// Largest vertical gap between consecutive lines, if it is a clear
  /// section break (at least 2.5 line-heights).
  static (List<MenuOCRLine>, List<MenuOCRLine>)? _horizontalCut(List<MenuOCRLine> lines) {
    final sorted = [...lines]..sort((a, b) => b.maxY.compareTo(a.maxY));
    final h = _median(sorted.map((l) => l.height).toList()) ?? 0.02;
    (int, double)? best;
    var lowestTop = sorted.first.minY;
    for (var i = 1; i < sorted.length; i++) {
      final gap = lowestTop - sorted[i].maxY;
      if (gap > (best?.$2 ?? 0)) best = (i, gap);
      if (sorted[i].minY < lowestTop) lowestTop = sorted[i].minY;
    }
    if (best == null || best.$2 < h * 2.5 || best.$1 < 2 || sorted.length - best.$1 < 2) return null;
    return (sorted.sublist(0, best.$1), sorted.sublist(best.$1));
  }

  /// Appends each stray line to the line on its left on the same row.
  static List<MenuOCRLine> _glueOntoRows(List<MenuOCRLine> strays, List<MenuOCRLine> lines) {
    final out = List<MenuOCRLine>.of(lines);
    for (final s in strays) {
      int? t;
      for (var i = 0; i < out.length; i++) {
        final o = out[i];
        final sameRow = (o.midY - s.midY).abs() < (o.height > s.height ? o.height : s.height) * 0.6;
        if (o.maxX <= s.minX + 0.02 && sameRow && (t == null || o.maxX > out[t].maxX)) t = i;
      }
      if (t != null) {
        out[t] = MenuOCRLine('${out[t].text} ${s.text}', out[t].box.expandToInclude(s.box));
      } else {
        out.add(s);
      }
    }
    return out;
  }

  /// The vertical gap that separates two dishes on this column, learned from
  /// the column's own line gaps (inside-dish gaps cluster near zero, between-
  /// dish gaps higher). Falls back to 0.75 line-heights.
  static double dishBreakGap(List<MenuOCRLine> lines, double h) {
    final fallback = h * 0.75;
    if (lines.length < 4) return fallback;
    // Cap at two line-heights: a section break or a skipped line is still
    // just "a big gap" and must not pull the threshold up.
    final gaps = <double>[
      for (var i = 1; i < lines.length; i++)
        (lines[i - 1].minY - lines[i].maxY).clamp(0.0, h * 2).toDouble()
    ]..sort();
    var bestScore = double.infinity, bestT = fallback, bestSep = 0.0;
    for (var k = 1; k < gaps.length; k++) {
      final lo = gaps.sublist(0, k), hi = gaps.sublist(k);
      final mLo = lo.reduce((a, b) => a + b) / lo.length;
      final mHi = hi.reduce((a, b) => a + b) / hi.length;
      final v = lo.fold<double>(0, (s, g) => s + (g - mLo) * (g - mLo)) +
          hi.fold<double>(0, (s, g) => s + (g - mHi) * (g - mHi));
      if (v < bestScore) {
        bestScore = v;
        bestT = (gaps[k - 1] + gaps[k]) / 2;
        bestSep = mHi - mLo;
      }
    }
    if (bestSep <= h * 0.3) return fallback;
    return bestT.clamp(h * 0.3, h * 1.2).toDouble();
  }

  /// Numbers the runs of lines between dish breaks.
  static List<int> gapGroups(List<MenuOCRLine> lines, double breakGap) {
    final groups = <int>[];
    var g = 0;
    for (var i = 0; i < lines.length; i++) {
      if (i > 0 && lines[i - 1].minY - lines[i].maxY > breakGap) g++;
      groups.add(g);
    }
    return groups;
  }

  /// A section word ("Caviar", "Oysters", "Sashimi") that opens a short,
  /// unpriced run of 2–4 lines, or is followed by a lowercase description,
  /// and isn't set larger than the text around it, is a dish title.
  static bool isDishTitleGroup(int index, List<MenuOCRLine> lines, List<int> groupOf, double medianH) {
    if (index >= groupOf.length) return false;
    if (lines[index].height >= medianH * 1.12) return false;
    if (index + 1 < lines.length && MenuText.startsLowercase(lines[index + 1].text)) return true;
    final g = groupOf[index];
    if (index > 0 && groupOf[index - 1] == g) return false;
    final run = [for (var i = 0; i < lines.length; i++) if (groupOf[i] == g) i];
    if (run.length < 2 || run.length > 4) return false;
    return !run.skip(1).any((i) => MenuText.hasTrailingPrice(lines[i].text) || MenuText.isPriceOnly(lines[i].text));
  }

  /// Wine-pairing lines: "Linden, Petit Manseng, Virginia (2020)", "(N.V)".
  static final _wine = RegExp(r'\((?:(?:19|20)\d{2}|N\.?\s?V\.?)\)', caseSensitive: false);
  static bool isWinePairing(String text) => _wine.hasMatch(text);

  static bool isBoilerplate(String text) {
    final t = text.toLowerCase();
    const markers = [
      'consuming raw', 'undercooked', 'foodborne illness', 'gratuity', 'service charge',
      'please inform', 'allerg', 'before placing your order', 'split plate', 'corkage',
      'prices subject', 'tax not included', 'www.', '@', 'instagram', 'reservations',
      'book now', 'make a reservation', 'reserve a table', 'gift card', 'order online',
      'private dining', 'private events',
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
      r'(?:[$£€¥]\s?)?\d{1,4}(?:[.,]\d{1,2})?(?:\s?/\s?(?:[$£€¥]\s?)?\d{1,4}(?:[.,]\d{1,2})?)?(?:\s?/\s?(?:pc|pcs|piece|oz|lb|tin|ea|each|person|guest))?';
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

  /// "OR" / "and" alone on a line between two choices.
  static bool isSeparator(String text) {
    final t = _trim(text.toLowerCase(), ' \t.,:;!?-–—•·*~()[]"\'');
    return t == 'or' || t == 'and' || (t.isEmpty && text.trim().isNotEmpty);
  }

  /// Running prose rather than a dish: three or more sentences, or a long
  /// paragraph of full lines.
  static bool isProse(List<String> lines) {
    final joined = lines.join(' ');
    final sentences = joined
        .split(RegExp(r'[.!?]'))
        .where((s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 4)
        .length;
    if (sentences >= 3) return true;
    final words = joined.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words >= 30 && words / lines.length >= 7;
  }

  /// A long line of running text that doesn't end its sentence.
  static bool isProseFragment(String text) {
    final t = text.trim();
    if (endsMidPhrase(t)) return true;
    if (t.isEmpty || '.!?:'.contains(t[t.length - 1])) return false;
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 8;
  }

  /// A line that stops mid-phrase: ends with a comma, "and", "with", "&"…
  static bool endsMidPhrase(String text) {
    final t = text.trim().toLowerCase();
    if (t.endsWith(',') || t.endsWith('&') || t.endsWith('-') || t.endsWith(';')) return true;
    final words = t.split(RegExp(r'\s+'));
    const tails = ['and', 'with', 'of', 'in', 'on', 'or', 'the', 'a', 'de', 'du', 'au', 'et'];
    return words.isNotEmpty && tails.contains(words.last);
  }

  /// "1 COTE Galbi" → "COTE Galbi", "• American Wagyu •" → "American Wagyu".
  static String cleanTitle(String text) {
    var t = text.replaceFirst(RegExp(r'^[\s•·◦*\-–—]+'), '');
    t = t.replaceFirst(RegExp(r'^\d{1,2}\s+(?=\p{L}{2})', unicode: true), '');
    t = t.replaceFirst(RegExp(r'[\s•·◦]+$'), '');
    return t.trim();
  }

  /// Fewer than three letters, or mostly digits and symbols.
  static bool isJunkTitle(String text) {
    final t = cleanTitle(stripPrice(text));
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
    final visible = t.replaceAll(RegExp(r'\s'), '').length;
    if (letters < 3) return true;
    if (RegExp(r'\bper (person|guest)\b', caseSensitive: false).hasMatch(t) && letters < 20) return true;
    return letters / (visible == 0 ? 1 : visible) < 0.5;
  }

  /// OCR of Korean, Japanese or Chinese text with a Latin model comes out as
  /// stray Cyrillic and symbol runs; drop those tokens.
  static String dropForeignScript(String text) {
    final t = text.replaceAll(
        RegExp(r'\S*[\p{Script=Cyrillic}\p{Script=Hangul}\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}₫]\S*',
            unicode: true),
        ' ');
    return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  static bool startsLowercase(String text) {
    final m = RegExp(r'\p{L}', unicode: true).firstMatch(text);
    return m != null && RegExp(r'\p{Ll}', unicode: true).hasMatch(m.group(0)!);
  }

  /// A course heading set larger than the menu text ("Lightly Cooked"):
  /// short, unpriced, no comma and no protein word.
  static String? largeHeading(String text, double height, double medianH) {
    if (height < medianH * 1.2) return null;
    final t = collapseLetterSpacing(text);
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words < 1 || words > 4 || t.contains(',') || hasTrailingPrice(t) || isPriceOnly(t)) return null;
    if (MenuProteinClassifier.classify(t).proteins.isNotEmpty) return null;
    return t;
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
