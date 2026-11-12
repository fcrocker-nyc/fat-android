import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'menu_interpreter.dart';
import 'menu_models.dart';

// 4. ClaimExplainer — turns a dish's claims into cards (What it means / What it
// doesn't tell you / Ask) and picks the two questions for the ask sheet. Both
// are derived, never stored, so a glossary update changes them without
// migrating saved data.

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
          gap: 'That’s common — most menus don’t say. The kitchen usually knows where '
              'its meat and fish come from.',
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
            questions: namedQuestions(claim, entry, item),
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
    final questions = claim.inferred ? (entry.inferredQuestions ?? t.questions) : t.questions;
    return ClaimText(meaning, t.authority, t.gap, [
      for (final q in questions) q.replaceAll('{name}', name),
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
  // Exactly two questions per dish (one only when no second applies), shared
  // by the dish-row button and the detail screen's "Questions for the table".
  // They are for asking out loud. Deterministic and kept identical to iOS
  // MenuClaimExplainer.askQuestions (shared expectations:
  // test/menu_fine_dining_questions_expected.json and
  // test/menu_phrase_questions_expected.json).
  //
  // 1. Claims on the dish itself (not its add-on) are ranked: claims printed
  //    in the dish name first, then named source > breed/grade > production
  //    claim (method, origin, certification) > species; within a tier the
  //    verbatim Berkshire pair leads, inferred claims trail, and menu order
  //    breaks ties.
  // 2. Q1 = the top claim's first question.
  // 3. Q2 = the best concrete question from the same claim or the next: the
  //    top claim's second question, then later claims' (second question
  //    first). A named source's "Have you visited the farm?" yields to a later
  //    claim's animal question. Never two "why did you choose" questions;
  //    near-duplicates skipped; "wild or farmed?" dropped when the menu says.
  // 4. Short of two: the species fallback (fallbackAsk) fills in.
  // 5. Add-on: asked about only when it is the dish's only animal protein —
  //    the add-on question stands in for Q2. Never a question about the whole
  //    plate (sides, sauces, "everything in this dish").

  static const _birdWords = ['chicken', 'duck', 'turkey', 'quail', 'goose', 'pheasant', 'squab', 'hen'];

  static const askLimit = 2;

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
    final mainProteins = [for (final p in item.proteins) if (!item.addOnProteins.contains(p)) p];
    final addOnOnly =
        mainProteins.isEmpty && (item.addOnProteins.isNotEmpty || addOnClaims.isNotEmpty);

    final out = <String>[];
    void push(String q) {
      if (out.length >= askLimit || out.any((o) => _nearDuplicate(o, q))) return;
      if (isWhyQuestion(q) && out.any(isWhyQuestion)) return;
      out.add(q);
    }

    if (addOnOnly) {
      // e.g. a vegetable stew with a lobster add-on.
      final addOn = item.addOns.isEmpty ? '' : item.addOns.first.toLowerCase();
      String? first;
      for (final (c, e) in _askRanked(addOnClaims, item, glossary)) {
        final qs = _askFor(c, e, item, glossary);
        if (qs.isNotEmpty) {
          first = qs.first;
          break;
        }
      }
      if (first != null) {
        push(first);
      } else if (item.addOnProteins.isNotEmpty) {
        final p = item.addOnProteins.first;
        final qs = glossary.fallbackAsk[p.name] ?? const <String>[];
        if (qs.isNotEmpty) push(nameSubject(qs.first, _plainNoun(addOn) ?? _familyNoun(p, item), false));
      }
      if (glossary.addOnAsk != null && addOn.isNotEmpty) {
        push(nameSubject(
            glossary.addOnAsk!.replaceAll('{addon}', addOn), _plainNoun(addOn) ?? addOn, false));
      }
      return out;
    }

    final ranked = [
      for (final (c, e) in _askRanked(mainClaims, item, glossary)) (c, _askFor(c, e, item, glossary)),
    ];
    if (ranked.isNotEmpty) {
      final (topClaim, topQs) = ranked.first;
      if (topQs.isNotEmpty) push(topQs.first);
      final same = topQs.skip(1).toList();
      final later = [
        for (final (_, qs) in ranked.skip(1)) ...(qs.length > 1 ? [qs[1], qs[0]] : qs),
      ];
      final candidates =
          isNamedSource(topClaim) && later.isNotEmpty ? [...later, ...same] : [...same, ...later];
      candidates.forEach(push);
    }

    if (out.length < askLimit) {
      for (final p in mainProteins) {
        final qs = [
          for (final q in glossary.fallbackAsk[p.name] ?? const <String>[])
            nameSubject(q, _familyNoun(p, item), false),
        ];
        (out.isEmpty ? qs : qs.reversed.toList()).forEach(push);
      }
    }

    if (out.isEmpty) {
      generalQuestions(item, glossary).forEach(push);
    }
    return out;
  }

  /// "Why did you choose…", "What made you decide to feature…".
  static bool isWhyQuestion(String q) {
    final t = q.toLowerCase();
    return t.startsWith('why ') || t.startsWith('what made you');
  }

  /// named source 0 · breed/grade 1 · production claim 2 · species 3.
  static int _askTier(MenuClaim c, ClaimEntry e) {
    if (isNamedSource(c)) return 0;
    if (nonSourcingKeys.contains(e.key)) return 3;
    switch (e.family) {
      case ClaimFamily.gradeOrBreed:
        return 1;
      case ClaimFamily.productionMethod:
      case ClaimFamily.certification:
      case ClaimFamily.originRegion:
      case ClaimFamily.originFarm:
        return 2;
      case ClaimFamily.speciesOrForm:
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
    final rows = <(List<int>, MenuClaim, ClaimEntry)>[];
    for (var i = 0; i < claims.length; i++) {
      final c = claims[i];
      final e = glossary.entry(c.entryKey);
      if (e == null) continue;
      rows.add((
        [_inDishName(c, item) ? 0 : 1, _askTier(c, e), e.questionsVerbatim ? 0 : 1, c.inferred ? 1 : 0, i],
        c,
        e,
      ));
    }
    rows.sort((a, b) {
      for (var k = 0; k < a.$1.length; k++) {
        final d = a.$1[k].compareTo(b.$1[k]);
        if (d != 0) return d;
      }
      return 0;
    });
    return [for (final r in rows) (r.$2, r.$3)];
  }

  /// One claim's questions, named for the item they're about: "wild or
  /// farmed?" dropped when the menu already says which for that item.
  static List<String> _askFor(MenuClaim claim, ClaimEntry entry, MenuItem item, MenuGlossary glossary) {
    var qs = namedQuestions(claim, entry, item);
    final speciesOrOrigin =
        entry.family == ClaimFamily.speciesOrForm || entry.family == ClaimFamily.originRegion;
    if (speciesOrOrigin && _hasQualifier(claim, item)) {
      qs = [for (final q in qs) if (!_asksWildOrFarmed(q)) q];
    }
    return qs;
  }

  /// A claim's two questions as shown on its card and in the ask sheet:
  /// "{name}" filled, and a bare "it" (or "{item}"/"{noun}") replaced by the
  /// item the claim is about, unless the entry is marked verbatim.
  static List<String> namedQuestions(MenuClaim claim, ClaimEntry entry, MenuItem item) {
    final qs = resolvedText(claim, entry).questions;
    if (entry.questionsVerbatim) return qs;
    final noun = _claimNoun(claim, item);
    if (noun == null) return qs;
    return [for (final q in qs) nameSubject(q, noun.$1, noun.$2)];
  }

  // ── Naming the subject ────────────────────────────────────────────────────
  //
  // A bare "it" is ambiguous on a multi-item dish, so each question names the
  // item its claim is about: "Which country is the shrimp from?", "Is Crystal
  // Valley the farm itself…". "{item}" in a glossary question is filled the
  // same way, and "{noun}" takes the bare word ("this lamb", "organic
  // salmon"). A question that already names the item is left as written.

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

  static String nameSubject(String q, String noun, bool proper) {
    final phrase = proper ? noun : 'the $noun';
    if (q.contains('{noun}')) {
      final det = pluralNouns.contains(noun.toLowerCase()) ? 'these' : 'this';
      return q.replaceAll('this {noun}', '$det {noun}').replaceAll('{noun}', noun);
    }
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
    // "…and where is it from?" → "…and where are they from?"
    for (final (sing, plur) in [('is it', 'are they'), ('was it', 'were they')]) {
      out = out.replaceAll(RegExp('\\b$sing\\b'), plur);
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
    final lines = ['${MenuAskCopy.sheetTitle} — ${dish.dishName}:', ''];
    for (var i = 0; i < questions.length; i++) {
      lines.add('${i + 1}. ${questions[i]}');
    }
    lines.addAll(['', '— from the FAT App · farmanimaltransparency.com']);
    return lines.join('\n');
  }
}

/// Verbatim text for the "Ask about this dish" button and sheet. Kept
/// identical to iOS MenuAskCopy; checked by the acronym and menu-wording guard
/// tests. The questions are for asking out loud.
class MenuAskCopy {
  static const rowButton = 'Ask about this dish';
  static const sheetTitle = 'Questions worth asking your server';
  static const copy = 'Copy';
  static const copied = 'Questions copied';
  static const moreAboutDish = 'More about this dish';
  static const thanks = 'Thank you — we like knowing where our food comes from.';
  static const closeWith = 'Close with: “$thanks”';
  static const kitchenNote = '“I’ll check with the kitchen” is a fine answer.';
  static const learnMore = 'Learn more';
  static const closingThought = 'Learn about your food.';

  static const all = [
    rowButton, sheetTitle, copy, copied, moreAboutDish, thanks, closeWith, kitchenNote,
    learnMore, closingThought,
  ];
}

// ── Learn more ─────────────────────────────────────────────────────────────
//
// Consumer-useful reading for one dish, on the detail screen. Pork dishes get
// exactly three links; every other dish gets "Menu words, explained". No
// supply-chain, market-concentration or environmental links from the menu
// flow. Kept identical to iOS MenuLearnLinks.

class MenuLearnLink {
  final String title;
  final String? blurb;
  final String url;
  const MenuLearnLink(this.title, this.blurb, this.url);
}

class MenuLearnLinks {
  static const ractopamine = MenuLearnLink(
    'Ractopamine',
    'A growth drug that is legal and unlabeled in conventional U.S. pork, and banned in many export markets. ‘Never fed’ claims are verified under a USDA program; FAT lists who is on it.',
    'https://farmanimaltransparency.com/ractopamine-us-pork-labels-verification/',
  );
  static const menuWords = MenuLearnLink(
    'Menu words, explained',
    null,
    'https://farmanimaltransparency.com/how-fat-reads-menus/',
  );
  static const porkResearch = MenuLearnLink(
    'How U.S. pork is raised and processed',
    null,
    'https://farmanimaltransparency.com/category/fatresearch/pork-industry-research-series/',
  );

  static List<MenuLearnLink> linksFor(MenuItem item) {
    final main = [for (final p in item.proteins) if (!item.addOnProteins.contains(p)) p];
    return (main.isEmpty ? item.proteins : main).contains(ProteinFamily.pork)
        ? const [ractopamine, menuWords, porkResearch]
        : const [menuWords];
  }
}
