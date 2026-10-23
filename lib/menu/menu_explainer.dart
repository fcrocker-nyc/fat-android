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
  const MenuClaimTag(this.text, this.inheritedFromHeader);
}

class MenuClaimExplainer {
  static const assetPath = 'assets/data/menu_claim_glossary.json';

  static MenuGlossary? _cached;

  static Future<MenuGlossary> loadGlossary() async {
    return _cached ??= MenuGlossary.fromJson(
      jsonDecode(await rootBundle.loadString(assetPath)) as Map<String, dynamic>,
    );
  }

  static List<MenuClaimCard> cards(MenuItem item, MenuGlossary glossary, String? diningState) {
    final entries = _ordered(item, glossary);
    if (entries.isEmpty) {
      return [
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
    }
    return [
      for (final (claim, entry) in entries)
        () {
          final text = resolvedText(claim, entry);
          return MenuClaimCard(
            id: '${entry.key}:${claim.matchedText}',
            entry: entry,
            matchedText: claim.matchedText,
            inheritedFromHeader: claim.inheritedFromHeader,
            title: _title(claim),
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
      out.add(MenuClaimTag(text, c.inheritedFromHeader));
    }
    return out;
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
