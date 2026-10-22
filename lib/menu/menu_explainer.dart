import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
  });
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
        MenuClaimCard(
          id: '${entry.key}:${claim.matchedText}',
          entry: entry,
          matchedText: claim.matchedText,
          inheritedFromHeader: claim.inheritedFromHeader,
          title: '“${claim.matchedText}”',
          meaning: entry.textFor(claim.appliesTo).meaning,
          authority: entry.textFor(claim.appliesTo).authority,
          gap: entry.textFor(claim.appliesTo).gap,
          questions: entry.textFor(claim.appliesTo).questions,
          stateNote: diningState == null ? null : entry.stateNote?[diningState],
        ),
    ];
  }

  /// Top three questions for one dish: one question per claim in family
  /// priority order (species and origin first), then second questions, then
  /// the general questions to fill. De-duplicated.
  static List<String> topQuestions(MenuItem item, MenuGlossary glossary, {int limit = 3}) {
    final entries = _ordered(item, glossary).map((e) => e.$2.textFor(e.$1.appliesTo)).toList();
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
