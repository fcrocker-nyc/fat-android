// Shared false-positive guards for FSIS establishment-number extraction.
// Mirrors iOS EstablishmentNumberGuard.swift.
//
// Why: the "est" prefix used to match with no left word boundary, so the
// Nutrition Facts line "Cholest. 80mg" read as "EST. 80" and sent the lookup to
// an unrelated plant (I80). Every EST pattern now requires a non-letter (or
// start of text) before "est"/"e s t"/"establishment"/"p", and every candidate
// match is screened here before it is accepted.

class EstNumberGuard {
  EstNumberGuard._();

  /// The word immediately before the match is a cholesterol label
  /// ("Cholest. 80mg", "Chol est 80mg", "Cholesterol 80mg").
  static final RegExp _cholesterolBefore = RegExp(
    r'chol(?:est(?:erol)?)?\.?\s{0,2}$',
    caseSensitive: false,
  );

  /// A nutrition / weight unit immediately after the number ("80mg", "80 %",
  /// "12 oz"). A bare attached "g" is NOT rejected — FSIS letter suffixes such
  /// as 969G are real — but a space-separated " g" is.
  static final RegExp _unitAfter = RegExp(
    r'^(?:\s{0,2}(?:mg|mcg|kcal|cal|oz|lbs?|kg|ml|%)|\s{1,2}g)(?![a-z])',
    caseSensitive: false,
  );

  /// Letter suffixes that are really units glued to the number ("80mg").
  static const Set<String> _unitSuffixes = {'mg', 'oz', 'lb', 'kg', 'ml'};

  /// True when the match at [start]..[end] in [text] (with the captured number
  /// [captured], which may carry a letter suffix) must be rejected.
  static bool reject(String text, int start, int end, String captured) {
    final before = text.substring(start >= 16 ? start - 16 : 0, start);
    if (_cholesterolBefore.hasMatch(before)) return true;
    final suffix =
        captured.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    if (_unitSuffixes.contains(suffix)) return true;
    if (_unitAfter.hasMatch(text.substring(end))) return true;
    return false;
  }
}
