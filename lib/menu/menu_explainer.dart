import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'menu_interpreter.dart';
import 'menu_models.dart';

// 4. ClaimExplainer — turns a dish's claims into cards (What it means / What it
// doesn't tell you / Ask) and picks the top three questions for the question
// sheet. The sheet is derived, never stored, so a glossary update changes it
// without migrating saved data.

class MenuClaimCard {
  final String id;
  final ClaimEntry? entry;
  final String matchedText;
  final bool inheritedFromHeader;
  final String title;
  final String meaning;
  final String? authority;
  final String gap;
  final List<String> questions;
  final String? stateNote;

  /// Curated note for a known named source, with its attribution.
  final String? sourceNote;

  const MenuClaimCard({
    required this.id,
    required this.entry,
    required this.matchedText,
    required this.inheritedFromHeader,
    required this.title,
    required this.meaning,
    required this.authority,
    required this.gap,
    required this.questions,
    required this.stateNote,
    this.sourceNote,
  });
}

/// One chip on the dish row. Claims attach to the item they modify:
/// "salmon (farmed)", "tiger shrimp (wild)", "Named source: Glen Cairn".
class MenuClaimTag {
  final String text;
  final bool inheritedFromHeader;

  /// A species or market-name note ("tuna", "shrimp") — FAT has a card for the
  /// word, but the menu made no sourcing claim.
  final bool isNote;
  const MenuClaimTag(this.text, this.inheritedFromHeader, [this.isNote = false]);
}

class MenuClaimExplainer {
  static const assetPath = 'assets/data/menu_claim_glossary.json';

  static MenuGlossary? _cached;

  static Future<MenuGlossary> loadGlossary() async {
    return _cached ??= MenuGlossary.fromJson(
      jsonDecode(await rootBundle.loadString(assetPath)) as Map<String, dynamic>,
    );
  }

  /// A claim about where the food came from or how it was raised or caught.
  /// A bare species word ("tuna", "Dover sole") is not one.
  static bool isSourcingClaim(MenuClaim c, [MenuGlossary? glossary]) {
    if (isNamedSource(c)) return true;
    final g = glossary ?? _cached;
    final e = g?.entry(c.entryKey);
    if (e == null) return true;
    // "fresh" (not frozen) and "foie gras" (an ingredient) don't say where the
    // meat or fish came from or how it was raised or caught.
    if (nonSourcingKeys.contains(e.key)) return false;
    return e.family != ClaimFamily.speciesOrForm;
  }

  static const nonSourcingKeys = {'fresh', 'foie_gras'};

  static bool hasSourcingClaim(MenuItem item, [MenuGlossary? glossary]) =>
      item.claims.any((c) => isSourcingClaim(c, glossary));

  static List<MenuClaimCard> cards(MenuItem item, MenuGlossary glossary, String? diningState) {
    final entries = _ordered(item, glossary);
    // Species notes explain the word but are not sourcing claims, so a dish
    // with only notes still leads with the "No sourcing claim" card.
    final lead = hasSourcingClaim(item, glossary)
        ? <MenuClaimCard>[]
        : [
        MenuClaimCard(
          id: 'no_claim',
          entry: null,
          matchedText: '',
          inheritedFromHeader: false,
          title: 'No sourcing claim',
          meaning:
              'The menu doesn’t say where this ${noun(item)} comes from or how it was raised or caught.',
          authority: null,
          gap: 'That’s common — most menus don’t. The kitchen usually knows, and the '
              'case label in the walk-in shows the supplier.',
          questions: generalQuestions(item, glossary),
          stateNote: null,
        ),
      ];
    return [
      ...lead,
      for (final (claim, entry) in entries)
        () {
          final text = resolvedText(claim, entry);
          return MenuClaimCard(
            id: '${entry.key}:${claim.matchedText}',
            entry: entry,
            matchedText: claim.matchedText,
            inheritedFromHeader: claim.inheritedFromHeader,
            title: isSourcingClaim(claim, glossary) ? _title(claim) : 'About “${claim.matchedText}”',
            meaning: text.meaning,
            authority: text.authority,
            gap: text.gap,
            questions: text.questions,
            stateNote: diningState == null ? null : entry.stateNote?[diningState],
            sourceNote: isNamedSource(claim)
                ? glossary.knownSource(claim.matchedText, claim.subject)?.note
                : null,
          );
        }(),
    ];
  }

  static bool isNamedSource(MenuClaim claim) =>
      MenuClaimExtractor.namedSourceKeys.contains(claim.entryKey);

  static String _title(MenuClaim claim) {
    if (isNamedSource(claim)) {
      return 'Named source: ${MenuNamedSources.displayName(claim.matchedText)}';
    }
    if (claim.inferred) return 'Farmed (not printed)';
    return '“${claim.matchedText}”';
  }

  /// Glossary wording for one claim: protein variant, "{name}" filled in, and
  /// a lead-in for claims the menu implies but doesn't print.
  static ClaimText resolvedText(MenuClaim claim, ClaimEntry entry) {
    final t = entry.textFor(claim.appliesTo);
    final name = MenuNamedSources.displayName(claim.matchedText);
    var meaning = t.meaning;
    if (claim.inferred && claim.subject != null) {
      meaning = 'The menu doesn’t say farmed, but organic ${claim.subject} is farmed. $meaning';
    }
    return ClaimText(meaning, t.authority, t.gap, [
      for (final q in t.questions) q.replaceAll('{name}', name),
    ]);
  }

  /// Chips for the dish row, in menu order. A qualifier ("wild", inferred
  /// "farmed") joins the species it modifies; a species without one stays plain.
  static List<MenuClaimTag> tags(MenuItem item) {
    bool isQualifier(MenuClaim c) => MenuClaimExtractor.qualifierKeys.contains(c.entryKey);
    final qualifiers = [
      for (final c in item.claims)
        if (isQualifier(c) && c.subject != null) c,
    ];
    final plainTexts = {
      for (final c in item.claims)
        if (!isQualifier(c) && !isNamedSource(c)) c.matchedText.toLowerCase(),
    };
    String qualifierText(MenuClaim c) => c.inferred ? 'farmed' : c.matchedText.toLowerCase();

    final out = <MenuClaimTag>[];
    for (final c in item.claims) {
      final String text;
      if (c.subject != null && isQualifier(c)) {
        if (plainTexts.contains(c.subject)) continue; // shown on the species chip
        text = '${c.subject} (${qualifierText(c)})';
      } else if (isNamedSource(c)) {
        text = 'Named source: ${MenuNamedSources.displayName(c.matchedText)}';
      } else {
        final t = c.matchedText.toLowerCase();
        final qs = [
          for (final q in qualifiers)
            if (q.subject == t) qualifierText(q),
        ];
        text = qs.isEmpty ? t : '$t (${qs.join(', ')})';
      }
      out.add(MenuClaimTag(text, c.inheritedFromHeader, !isSourcingClaim(c)));
    }
    // Real claims first, species notes after.
    return [...out.where((t) => !t.isNote), ...out.where((t) => t.isNote)];
  }

  /// Top three questions for one dish: one question per claim in family
  /// priority order (species and origin first), then second questions, then
  /// the general questions to fill. De-duplicated.
  static List<String> topQuestions(MenuItem item, MenuGlossary glossary, {int limit = 3}) {
    final entries = _ordered(item, glossary).map((e) => resolvedText(e.$1, e.$2)).toList();
    final out = <String>[];
    void push(String q) {
      if (out.length < limit && !out.contains(q)) out.add(q);
    }

    var round = 0;
    while (out.length < limit && entries.any((e) => e.questions.length > round)) {
      for (final e in entries) {
        if (e.questions.length > round) push(e.questions[round]);
      }
      round++;
    }
    for (final q in generalQuestions(item, glossary)) {
      push(q);
    }
    return out;
  }

  static List<String> generalQuestions(MenuItem item, MenuGlossary glossary) =>
      glossary.generalQuestions.map((q) => q.replaceAll('{protein}', noun(item))).toList();

  static String noun(MenuItem item) {
    switch (item.proteins.length) {
      case 0:
        return 'meat or fish';
      case 1:
        return item.proteins.first.questionNoun;
      default:
        return item.proteins.take(2).map((p) => p.questionNoun).join(' and ');
    }
  }

  static List<(MenuClaim, ClaimEntry)> _ordered(MenuItem item, MenuGlossary glossary) {
    final pairs = <(MenuClaim, ClaimEntry)>[];
    for (final c in item.claims) {
      final e = glossary.entry(c.entryKey);
      if (e != null) pairs.add((c, e));
    }
    final indexed = pairs.asMap().entries.toList()
      ..sort((a, b) {
        final pa = a.value.$2.family.priority, pb = b.value.$2.family.priority;
        return pa != pb ? pa.compareTo(pb) : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  // ── "Ask about this dish" ────────────────────────────────────────────────
  //
  // The 2–3 most useful questions for one dish, shared by the dish-row button
  // and the detail screen's "Questions for the table". Deterministic and kept
  // identical to the iOS MenuClaimExplainer.askQuestions (shared expectation:
  // test/menu_fine_dining_questions_expected.json).
  //
  // 1. Claims on the dish itself (not its add-on) are ranked: claims printed
  //    in the dish name first, then species/origin, production (wild/farmed,
  //    organic, inferred farmed), named source, others; menu order breaks ties.
  // 2. Each claim's glossary questions, minus "wild or farmed?" when the menu
  //    already says which, with closely related pairs merged (askMerges).
  // 3. One question per claim per round, skipping near-duplicates, up to 3
  //    (2 when the dish has an add-on).
  // 4. No sourcing claim: species-note questions, else fallbackAsk by species.
  // 5. Add-on: one question (its claim's first question, else addOnAsk).

  static const _birdWords = ['chicken', 'duck', 'turkey', 'quail', 'goose', 'pheasant', 'squab', 'hen'];

  static List<String> askQuestions(MenuItem item, MenuGlossary glossary) {
    final name = item.dishName.toLowerCase();
    final desc = item.description.toLowerCase();
    final addOnText = item.addOns.join(' ').toLowerCase();
    bool isAddOnClaim(MenuClaim c) {
      final m = c.matchedText.toLowerCase();
      return addOnText.isNotEmpty && addOnText.contains(m) && !name.contains(m) && !desc.contains(m);
    }

    final mainClaims = [for (final c in item.claims) if (!isAddOnClaim(c)) c];
    final addOnClaims = [for (final c in item.claims) if (isAddOnClaim(c)) c];
    final hasAddOn = item.addOnProteins.isNotEmpty || addOnClaims.isNotEmpty;

    final out = <String>[];
    void push(String q, int limit) {
      if (out.length < limit && !out.any((o) => _nearDuplicate(o, q))) out.add(q);
    }

    void roundRobin(List<List<String>> lists, int limit) {
      var round = 0;
      while (out.length < limit && lists.any((l) => l.length > round)) {
        for (final l in lists) {
          if (l.length > round) push(l[round], limit);
        }
        round++;
      }
    }

    final mainLimit = hasAddOn ? 2 : 3;
    final ranked = _askRanked(mainClaims, item, glossary);
    if (mainClaims.any((c) => isSourcingClaim(c, glossary))) {
      roundRobin([for (final (c, e) in ranked) _askFor(c, e, item, glossary)], mainLimit);
    } else {
      // Species notes ("tuna") carry species-specific questions.
      roundRobin([for (final (c, e) in ranked) _askFor(c, e, item, glossary)], mainLimit);
      if (out.isEmpty) {
        final bird = _birdWord(item);
        roundRobin([
          for (final p in item.proteins)
            if (!item.addOnProteins.contains(p))
              [
                for (final q in glossary.fallbackAsk[p.name] ?? const <String>[])
                  _nameSubject(
                      bird != null && p == ProteinFamily.poultry
                          ? q.replaceAll('chicken (or duck)', bird)
                          : q,
                      _familyNoun(p, item),
                      false),
              ],
        ], mainLimit);
      }
    }

    if (hasAddOn) {
      String? q;
      for (final c in addOnClaims) {
        final e = glossary.entry(c.entryKey);
        if (e == null) continue;
        final qs = _askFor(c, e, item, glossary);
        if (qs.isNotEmpty) {
          q = qs.first;
          break;
        }
      }
      if (q == null && item.addOns.isNotEmpty && glossary.addOnAsk != null) {
        final addOn = item.addOns.first.toLowerCase();
        q = _nameSubject(
            glossary.addOnAsk!.replaceAll('{addon}', addOn), _plainNoun(addOn) ?? addOn, false);
      }
      if (q != null) push(q, 3);
    }

    if (out.isEmpty && glossary.generalQuestions.isNotEmpty) {
      out.add(generalQuestions(item, glossary).first);
    }
    return out;
  }

  static int _askTier(ClaimEntry e) {
    if (e.key == 'organic') return 1;
    switch (e.family) {
      case ClaimFamily.speciesOrForm:
      case ClaimFamily.originRegion:
        return 0;
      case ClaimFamily.productionMethod:
        return 1;
      case ClaimFamily.originFarm:
        return 2;
      case ClaimFamily.certification:
      case ClaimFamily.gradeOrBreed:
        return 3;
    }
  }

  static bool _inDishName(MenuClaim c, MenuItem item) {
    final name = item.dishName.toLowerCase();
    if (name.contains(c.matchedText.toLowerCase())) return true;
    return c.inferred && c.subject != null && name.contains(c.subject!);
  }

  static List<(MenuClaim, ClaimEntry)> _askRanked(
      List<MenuClaim> claims, MenuItem item, MenuGlossary glossary) {
    final pairs = <(int, MenuClaim, ClaimEntry)>[];
    for (var i = 0; i < claims.length; i++) {
      final e = glossary.entry(claims[i].entryKey);
      if (e != null) pairs.add((i, claims[i], e));
    }
    int headline(MenuClaim c) => _inDishName(c, item) ? 0 : 1;
    pairs.sort((a, b) {
      final h = headline(a.$2).compareTo(headline(b.$2));
      if (h != 0) return h;
      final t = _askTier(a.$3).compareTo(_askTier(b.$3));
      if (t != 0) return t;
      return a.$1.compareTo(b.$1);
    });
    return [for (final p in pairs) (p.$2, p.$3)];
  }

  /// One claim's questions for the ask sheet: "wild or farmed?" dropped when
  /// the menu already says which for that item, related pairs merged.
  static List<String> _askFor(MenuClaim claim, ClaimEntry entry, MenuItem item, MenuGlossary glossary) {
    var qs = resolvedText(claim, entry).questions;
    final speciesOrOrigin =
        entry.family == ClaimFamily.speciesOrForm || entry.family == ClaimFamily.originRegion;
    if (speciesOrOrigin && _hasQualifier(claim, item)) {
      qs = [for (final q in qs) if (!_asksWildOrFarmed(q)) q];
    }
    for (final m in glossary.askMerges) {
      if (m.questions.isEmpty || !m.questions.every(qs.contains)) continue;
      final at = qs.indexOf(m.questions.first);
      qs = [
        for (var i = 0; i < qs.length; i++)
          if (i == at) m.merged else if (!m.questions.contains(qs[i])) qs[i],
      ];
    }
    final noun = _claimNoun(claim, item);
    if (noun == null) return qs;
    return [for (final q in qs) _nameSubject(q, noun.$1, noun.$2)];
  }

  // ── Naming the subject ────────────────────────────────────────────────────
  //
  // A bare "it" is ambiguous on a multi-item dish, so each question names the
  // item its claim is about: "Which country is the shrimp from?", "Is Crystal
  // Valley the farm itself…". "{item}" in a glossary question is filled the
  // same way. A question that already names the item is left as written.

  /// Plain item words, longest first so "foie gras" wins over shorter words.
  static const _itemWords = [
    'foie gras', 'sea bass', 'swordfish', 'branzino', 'halibut', 'snapper', 'grouper',
    'salmon', 'tuna', 'codfish', 'cod', 'trout', 'sole', 'shrimp', 'prawns', 'prawn',
    'lobster', 'crab', 'scallops', 'scallop', 'oysters', 'mussels', 'clams', 'octopus',
    'calamari', 'squid', 'caviar', 'sea urchin', 'uni', 'hamachi', 'yellowtail', 'hiramasa',
    'kanpachi', 'kampachi', 'monkfish', 'fluke', 'flounder', 'beef', 'veal', 'pork', 'lamb', 'chicken', 'duck',
    'turkey', 'quail', 'goose', 'pheasant', 'venison', 'rabbit', 'bison', 'elk', 'boar',
  ];

  /// The first plain item word in [text], by position.
  static String? _plainNoun(String text) {
    final t = text.toLowerCase();
    var best = -1;
    String? word;
    for (final w in _itemWords) {
      final m = RegExp('\\b$w\\b').firstMatch(t);
      if (m != null && (best < 0 || m.start < best)) {
        best = m.start;
        word = w;
      }
    }
    return word;
  }

  static String _familyNoun(ProteinFamily p, MenuItem item) {
    switch (p) {
      case ProteinFamily.beef:
        return 'beef';
      case ProteinFamily.pork:
        return 'pork';
      case ProteinFamily.lamb:
        return 'lamb';
      case ProteinFamily.poultry:
        return _birdWord(item) ?? 'chicken';
      case ProteinFamily.finfish:
        return _plainNoun(item.dishName) ?? 'fish';
      case ProteinFamily.shellfish:
        return _plainNoun(item.dishName) ?? 'shellfish';
      case ProteinFamily.other:
        return _plainNoun(item.dishName) ?? 'meat';
    }
  }

  /// The item a claim is about, and whether it is a proper name (no "the").
  static (String, bool)? _claimNoun(MenuClaim c, MenuItem item) {
    if (isNamedSource(c)) return (MenuNamedSources.displayName(c.matchedText), true);
    final fromText = (c.subject == null ? null : _plainNoun(c.subject!)) ?? _plainNoun(c.matchedText);
    if (fromText != null) return (fromText, false);
    final p = c.appliesTo ??
        (item.proteins.where((p) => !item.addOnProteins.contains(p)).firstOrNull);
    return p == null ? null : (_familyNoun(p, item), false);
  }

  static final _bareIt = RegExp(r"(?<![\w’'])[Ii]t(?![\w’'])");

  static String _nameSubject(String q, String noun, bool proper) {
    final phrase = proper ? noun : 'the $noun';
    if (q.contains('{item}')) return _pluralAgree(q.replaceAll('{item}', phrase), noun);
    if (RegExp('\\b${RegExp.escape(noun.toLowerCase())}\\b').hasMatch(q.toLowerCase())) return q;
    final m = _bareIt.firstMatch(q);
    if (m == null) return q;
    final cap = q[m.start] == 'I';
    final rep = cap ? phrase[0].toUpperCase() + phrase.substring(1) : phrase;
    return _pluralAgree(q.replaceRange(m.start, m.end, rep), noun);
  }

  /// Plural item words take a plural verb once "it" becomes the noun:
  /// "Is the oysters wild…" → "Are the oysters wild…".
  static const pluralNouns = {'oysters', 'prawns', 'scallops', 'mussels', 'clams'};

  static String _pluralAgree(String q, String noun) {
    if (!pluralNouns.contains(noun.toLowerCase())) return q;
    final n = RegExp.escape(noun);
    var out = q;
    for (final (sing, plur) in [('Is', 'Are'), ('is', 'are'), ('Was', 'Were'), ('was', 'were')]) {
      out = out.replaceAll(RegExp('\\b$sing the $n\\b'), '$plur the $noun');
    }
    return out;
  }

  static bool _hasQualifier(MenuClaim claim, MenuItem item) {
    final m = claim.matchedText.toLowerCase();
    return item.claims.any((q) {
      if (!MenuClaimExtractor.qualifierKeys.contains(q.entryKey)) return false;
      final s = q.subject;
      if (s == null || s.isEmpty) return q.appliesTo != null && q.appliesTo == claim.appliesTo;
      return s == m || s.contains(m) || m.contains(s);
    });
  }

  static bool _asksWildOrFarmed(String q) {
    final t = q.toLowerCase();
    return t.contains('wild') && (t.contains('farmed') || t.contains('ranched'));
  }

  static String _askNorm(String q) => q
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^a-z0-9']+"), ' ')
      .trim();

  /// Same question, or two "which country" questions about one dish.
  static bool _nearDuplicate(String a, String b) {
    final na = _askNorm(a), nb = _askNorm(b);
    if (na == nb) return true;
    final ta = na.split(' ').toSet(), tb = nb.split(' ').toSet();
    return ta.contains('country') && tb.contains('country');
  }

  static String? _birdWord(MenuItem item) {
    for (final text in [item.dishName, item.description]) {
      final t = text.toLowerCase();
      var best = -1;
      String? word;
      for (final w in _birdWords) {
        final m = RegExp('\\b$w\\b').firstMatch(t);
        if (m != null && (best < 0 || m.start < best)) {
          best = m.start;
          word = w;
        }
      }
      if (word != null) return word;
    }
    return null;
  }

  /// Plain-text export for the share button.
  static String shareText(MenuItem dish, List<String> questions) {
    final lines = ['Questions about ${dish.dishName}:', ''];
    for (var i = 0; i < questions.length; i++) {
      lines.add('${i + 1}. ${questions[i]}');
    }
    lines.addAll(['', '— from the FAT App · farmanimaltransparency.com']);
    return lines.join('\n');
  }
}

/// Verbatim labels for the "Ask about this dish" button and sheet. Kept
/// identical to iOS MenuAskCopy; checked by the acronym guard tests.
class MenuAskCopy {
  static const rowButton = 'Ask about this dish';
  static const sheetSubtitle = 'Questions to ask your server or chef';
  static const showToServer = 'Show to server';
  static const copy = 'Copy';
  static const copied = 'Questions copied';
  static const moreAboutDish = 'More about this dish';
  static const serverHint = 'Tap anywhere to close';
  static const thanks = 'Thank you — we like knowing where our food comes from.';

  static const all = [rowButton, sheetSubtitle, showToServer, copy, copied, moreAboutDish, serverHint, thanks];
}
