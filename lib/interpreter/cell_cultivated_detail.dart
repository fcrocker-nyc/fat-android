// Cell-cultivated (lab-grown) meat awareness line.
//
// An informational detail line shown when the scanned label text says the
// product is cell-cultivated. Display only: derived from the saved scanned
// text at display time — nothing is persisted, and it never changes a
// category status, the "X of 16" count, or any score.
//
// Where it rides:
//   • Meat / poultry and the Prepared / Multi-Ingredient lane — under
//     Cat. 2 Species (FSIS-approved labels put "cell-cultivated" in front of
//     the species name, e.g. "cell-cultivated chicken").
//   • Seafood — under Cat. 10 Feed / Production Method
//     (see SeafoodDetailLines.forResult).
//
// Strings and matching rules are kept identical to iOS
// (FATAppMVP2/CellCultivatedDetail.swift) for parity.

import '../models/fat_models.dart';

class CellCultivatedDetail {
  CellCultivatedDetail._();

  // ── User-facing string (kept verbatim for iOS parity) ──
  static const String line =
      'This label says the product is cell-cultivated: grown from animal cells rather than from a slaughtered animal. USDA must preapprove the labels of cell-cultivated meat and poultry; FDA oversees cell-cultivated seafood.';

  /// Species / meat words that make a bare "cultivated" or "cultured" count.
  static const List<String> speciesWords = [
    'chicken', 'poultry', 'pork', 'beef', 'meat', 'salmon', 'seafood',
    'fish', 'turkey', 'duck', 'lamb',
  ];

  // Hyphen variants OCR produces: ASCII hyphen, Unicode hyphen, non-breaking
  // hyphen, figure dash, en dash, em dash.
  static const String _dashes = r'\-‐‑‒–—';

  /// A hyphen that ends an OCR line ("cell-⏎cultivated", "culti-⏎vated").
  static final RegExp _lineBreakHyphen =
      RegExp('[$_dashes][ \\t]*[\\r\\n]+\\s*');

  static final RegExp _phraseRe = RegExp(
      '\\b(?:'
      'cell[\\s$_dashes]*(?:cultivated|cultured)'
      '|lab[\\s$_dashes]*grown'
      '|(?:cultivated|cultured)[\\s$_dashes]*(?:${speciesWords.join('|')})s?'
      ')\\b');

  /// "not lab-grown", "never lab-grown", "no cell-cultured …", "non-…",
  /// "without …", "free of …" — the label is saying the opposite.
  static final RegExp _negationRe = RegExp(
      '(?:\\b(?:not|no|never|non|without)|\\bfree\\s+(?:of|from))[\\s$_dashes]*\$');

  /// Lowercased, soft hyphens removed, line-break hyphens joined,
  /// whitespace collapsed.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll('­', '')
      .replaceAll(_lineBreakHyphen, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// True when the label text says the product is cell-cultivated.
  static bool detect(String scannedText) {
    final t = normalize(scannedText);
    for (final m in _phraseRe.allMatches(t)) {
      final before = t.substring(0, m.start);
      if (!_negationRe.hasMatch(before)) return true;
    }
    return false;
  }

  /// Cat. 2 Species detail lines for a meat / poultry or prepared-food
  /// result. Empty for seafood (seafood carries the line under Cat. 10).
  static List<String> meatLines(FATResult r) {
    if (r.productType != ProductType.meat || !detect(r.scannedText)) {
      return const [];
    }
    return const [line];
  }
}
