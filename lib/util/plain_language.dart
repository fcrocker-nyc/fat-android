// Rewrites regulatory acronyms in server- or feed-supplied text before it is
// shown to shoppers (EST lookup notes, brand-feed caveats). App-authored copy
// is already written without them; this covers text the app doesn't author.
// Guideline identifiers such as FSIS-GD-2024-0006 are left intact.
// Mirrors iOS FATAppMVP2/PlainLanguage.swift.

class PlainLanguage {
  PlainLanguage._();

  static final List<MapEntry<RegExp, String>> _rules = [
    MapEntry(RegExp(r'USDA ?/ ?FSIS'), 'USDA'),
    MapEntry(RegExp(r'USDA[- ]FSIS'), 'USDA'),
    MapEntry(RegExp(r'\bFSIS\b(?!-GD-)'), 'USDA'),
    MapEntry(RegExp(r'USDA AMS'), 'USDA'),
    MapEntry(RegExp(r'\bAMS\b'), 'USDA'),
    MapEntry(RegExp(r'USDA NOP'), 'USDA Organic'),
    MapEntry(RegExp(r'\bNOP\b'), 'USDA Organic'),
    MapEntry(RegExp(r'\bHACCP\b'), 'food-safety plan'),
    MapEntry(RegExp(r'\bSIMP\b'), "NOAA's Seafood Import Monitoring Program"),
    MapEntry(RegExp(r'\bCOOL\b'), 'country-of-origin labeling'),
    MapEntry(RegExp(r'USDA USDA'), 'USDA'),
  ];

  static String consumerText(String s) {
    var out = s;
    for (final r in _rules) {
      out = out.replaceAll(r.key, r.value);
    }
    return out;
  }

  static String? consumerTextOrNull(String? s) =>
      s == null ? null : consumerText(s);
}
