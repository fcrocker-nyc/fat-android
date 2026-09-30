// Meat "seasoned / marinated" detail lines.
//
// Secondary lines shown INSIDE the Cat. 14 (Quality / Palatability) row on the
// meat results screen and in the meat share summary. Derived from the saved
// scanned text at display time — nothing is persisted, and none of it changes
// a category status, the disclosure count, or the behind-the-scenes index.
//
// Meat lane only: never for seafood and never when the Prepared /
// Multi-Ingredient lane fired (stew, pizza, soup… — see prepared_food.dart).
//
// Strings, keyword lists and parsing rules are kept identical to iOS
// (FATAppMVP2/MeatSeasoningDetail.swift) for parity.

import '../models/fat_models.dart';
import 'prepared_food.dart';

class MeatSeasoningDetail {
  MeatSeasoningDetail._();

  // ── User-facing strings (kept verbatim for iOS parity) ──
  static const String seasonedPrefix = 'Seasoned: ';
  static const String seasonedNameOnly =
      'Seasoned or marinated — see the ingredient statement on the package.';
  static const String solutionPrefix = 'Contains added solution: ';

  /// Words on the label (usually the product name) that say the meat was
  /// seasoned, marinated, rubbed, glazed or flavored.
  static const List<String> seasoningWords = [
    'seasoned', 'seasoning', 'marinated', 'marinade', 'rub', 'rubbed',
    'spice', 'spices', 'spiced', 'glazed', 'glaze', 'herb', 'herbs', 'herbed',
    'flavored', 'flavoured',
  ];

  /// Phrase form of a seasoning signal ("chicken thighs with oil and …").
  static const List<String> seasoningPhrases = ['with oil and'];

  /// Species words dropped from the ingredient list (the meat itself).
  static const List<String> meatWords = [
    'chicken', 'beef', 'pork', 'turkey', 'lamb', 'veal', 'bison',
  ];

  /// Cut / form / qualifier words that may accompany a species word in the
  /// meat's own ingredient entry ("boneless skinless chicken thighs").
  static const List<String> cutWords = [
    'thigh', 'thighs', 'breast', 'breasts', 'drumstick', 'drumsticks',
    'wing', 'wings', 'leg', 'legs', 'tenderloin', 'tenderloins', 'loin',
    'loins', 'chop', 'chops', 'steak', 'steaks', 'cutlet', 'cutlets',
    'tender', 'tenders', 'rib', 'ribs', 'roast', 'shoulder', 'fillet',
    'fillets', 'filet', 'filets', 'boneless', 'skinless', 'ground', 'meat',
    'organic', 'fresh', 'dark', 'white', 'and',
  ];

  /// Phrases that end an ingredient statement. "contains" ends it unless it
  /// introduces a "contains 2% or less of …" run, which is part of the list.
  static const List<String> stopPhrases = [
    'contains', 'keep refrigerated', 'keep frozen', 'safe handling',
    'distributed by', 'packed by', 'packed for', 'manufactured by',
    'produced by', 'prepared from', 'net wt', 'net weight',
    'inspected and passed', 'u.s. inspected', 'product of', 'sell by',
    'use by', 'best by',
  ];

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static final RegExp _ingredientsHeader = RegExp(r'\bingredients?\s*:');

  static final RegExp _stopRe = RegExp(
    r'\b(?:' +
        stopPhrases
            .map((p) => p == 'contains'
                ? r'contains(?!\s+(?:less than\s+)?\d)'
                : RegExp.escape(p))
            .join('|') +
        r')\b',
  );

  static final RegExp _seasoningRe = RegExp(
    r'\b(?:' +
        [...seasoningWords, ...seasoningPhrases].map(RegExp.escape).join('|') +
        r')\b',
  );

  static final RegExp _solutionUpTo = RegExp(
    r'(?:containing|contains|with)\s+up\s+to\s+\d+(?:\.\d+)?\s*%\s+'
    r'(?:of\s+)?(?:an?\s+)?(?:added\s+)?solution\b',
  );
  static final RegExp _solutionAdded = RegExp(
    r'(?:(?:containing|contains|with)\s+)?(?:up\s+to\s+)?'
    r'(?:\d+(?:\.\d+)?\s*%\s+)?(?:an?\s+)?added\s+solution\b',
  );
  static final RegExp _solutionOfTail = RegExp(r'^\s+of\b');

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  /// Length of the statement at the start of [s]: up to the first top-level
  /// period that ends a sentence, or the first top-level stop phrase.
  static int _statementEnd(String s) {
    final stops = _stopRe.allMatches(s).map((m) => m.start).toSet();
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x28 || c == 0x5B) {
        depth++;
      } else if (c == 0x29 || c == 0x5D) {
        if (depth > 0) depth--;
      } else if (depth == 0) {
        if (stops.contains(i)) return i;
        if (c == 0x2E && (i + 1 == s.length || _isSpace(s.codeUnitAt(i + 1)))) {
          return i;
        }
      }
    }
    return s.length;
  }

  /// Split on commas that are not inside parentheses / brackets, so
  /// "oil (olive oil and canola oil)" stays one item.
  static List<String> _splitTopLevel(String s) {
    final out = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x28 || c == 0x5B) {
        depth++;
      } else if (c == 0x29 || c == 0x5D) {
        if (depth > 0) depth--;
      } else if (c == 0x2C && depth == 0) {
        out.add(s.substring(start, i));
        start = i + 1;
      }
    }
    out.add(s.substring(start));
    return out;
  }

  static String _cleanItem(String s) {
    var t = s.trim();
    t = t.replaceFirst(RegExp(r'^(?:and|or)\s+'), '');
    t = t.replaceFirst(RegExp(r'^[\s:;.]+'), '');
    t = t.replaceFirst(RegExp(r'[\s:;.]+$'), '');
    return t.trim();
  }

  /// True when an ingredient entry is only the meat itself ("chicken",
  /// "boneless skinless chicken thighs").
  static bool _isMeatOnly(String item) {
    final bare = item.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final words =
        bare.split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;
    final hasSpecies = words.any(meatWords.contains);
    final allMeat =
        words.every((w) => meatWords.contains(w) || cutWords.contains(w));
    return hasSpecies && allMeat;
  }

  /// Ingredient entries after "ingredients:", in label order, lowercased, with
  /// the meat itself dropped. Null when the label has no ingredient statement.
  static List<String>? ingredientItems(String scannedText) {
    final t = _norm(scannedText);
    final m = _ingredientsHeader.firstMatch(t);
    if (m == null) return null;
    final rest = t.substring(m.end);
    final body = rest.substring(0, _statementEnd(rest));
    return _splitTopLevel(body)
        .map(_cleanItem)
        .where((i) => i.isNotEmpty && !_isMeatOnly(i))
        .toList();
  }

  static bool hasSeasoningWord(String scannedText) =>
      _seasoningRe.hasMatch(_norm(scannedText));

  /// The "added solution" phrase as printed (lowercased), or null.
  static String? solutionPhrase(String scannedText) {
    final t = _norm(scannedText);
    final m = _solutionUpTo.firstMatch(t) ?? _solutionAdded.firstMatch(t);
    if (m == null) return null;
    var phrase = m.group(0)!;
    final rest = t.substring(m.end);
    if (_solutionOfTail.hasMatch(rest)) {
      phrase += rest.substring(0, _statementEnd(rest));
    }
    return phrase.replaceFirst(RegExp(r'[\s,:;.]+$'), '').trim();
  }

  static String _sentenceCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Detail lines for a label's scanned text (no lane checks).
  static List<String> lines(String scannedText) {
    final out = <String>[];
    final items = ingredientItems(scannedText);
    if (items != null && items.isNotEmpty) {
      out.add('$seasonedPrefix${items.join(', ')}.');
    } else if (hasSeasoningWord(scannedText)) {
      out.add(seasonedNameOnly);
    }
    final solution = solutionPhrase(scannedText);
    if (solution != null) {
      out.add('$solutionPrefix${_sentenceCase(solution)}.');
    }
    return out;
  }

  /// Cat. 14 detail lines for a result. Empty for seafood and for the
  /// Prepared / Multi-Ingredient lane.
  static List<String> forResult(FATResult r) {
    if (r.productType != ProductType.meat || r.isPreparedFood) return const [];
    if (PreparedFoodDetector.detect(r.scannedText).isPrepared) return const [];
    return lines(r.scannedText);
  }
}
