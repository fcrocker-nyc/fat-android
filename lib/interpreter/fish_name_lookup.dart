// Fish-name lookup (Lookup tab → Seafood → "Fish name").
//
// For loose or service-case fish with no brand: the user types a market name
// ("grouper", "mahi mahi", "cod") and gets
//   1. SIMP — NOAA's Seafood Import Monitoring Program coverage (SIMPCoverage),
//      with honest notes for ambiguous names (bare "snapper", bare "crab", cod)
//      and the FDA rockfish-as-"snapper" misbranding note;
//   2. Marine-mammal bycatch — the Paper No. 7 Strong pairs for the species
//      group (mmpa_bycatch_pairs.json), or nothing at all;
//   3. What the counter must tell you — COOL (7 CFR Part 60), with the
//      exemption wording already used by the service-case capture.
//
// A reference lookup only: it never touches a label score or any "X of 16"
// count. Strings and rules are kept identical to iOS
// (FATAppMVP2/FishNameLookup.swift); both apps check their output against the
// shared fish_name_lookup_baseline.json.

import '../models/service_case_schema.dart';
import 'seafood_bycatch.dart';
import 'seafood_detail_lines.dart';

enum FishSimpStatus { covered, notCovered, unclear }

class FishNameSection {
  final String title;
  final List<SeafoodDetailLine> lines;
  const FishNameSection(this.title, this.lines);
}

class FishNameResult {
  final String query;

  /// Matched market name (normalized), null when unrecognized.
  final String? matchedName;

  /// Card title: the fish name, or the not-found title.
  final String title;
  final FishSimpStatus? simpStatus;
  final List<FishNameSection> sections;
  final bool hasBycatch;
  final bool hasMisbrandingNote;

  const FishNameResult({
    required this.query,
    required this.matchedName,
    required this.title,
    required this.simpStatus,
    required this.sections,
    required this.hasBycatch,
    required this.hasMisbrandingNote,
  });

  bool get recognized => matchedName != null;

  /// Result line recorded to Lookup History.
  String get historyTitle {
    if (!recognized || simpStatus == null) {
      return FishNameLookup.historyNotRecognized;
    }
    switch (simpStatus!) {
      case FishSimpStatus.covered:
        return '$title — covered by SIMP';
      case FishSimpStatus.notCovered:
        return '$title — not covered by SIMP';
      case FishSimpStatus.unclear:
        return '$title — SIMP coverage unclear';
    }
  }
}

class FishNameLookup {
  FishNameLookup._();

  // ── User-facing strings (kept verbatim for iOS parity) ──
  static const String searchHeader = 'Look up a fish by name';
  static const String searchPlaceholder = 'e.g. grouper, mahi mahi, cod';
  static const String subtitle = 'Loose or service-case fish (no brand)';
  static const String footer =
      "A reference lookup, not a label score: it doesn't change any disclosure count.";
  static const String historySubtitle = 'Fish name lookup';
  static const String historyNotRecognized = 'Fish name not recognized';

  static const String simpTitle =
      'SIMP (NOAA Seafood Import Monitoring Program)';
  static const String bycatchTitle = 'Marine-mammal bycatch';
  static const String coolTitle = 'What the counter must tell you';
  static const String unknownTitle = 'Fish Name Not Found';
  static const String unknownSectionTitle = 'Try a SIMP species group';

  static const String simpCoveredDetail =
      'Imports of this species group must report harvest records to NOAA, including the vessel, catch area and fishing gear. SIMP does not apply to domestic seafood.';
  static const String snapperUnclear =
      "SIMP covers red snapper only; a placard that just says 'snapper' doesn't say which species.";
  static const String crabUnclear =
      "SIMP covers blue crab (Atlantic) and red king crab only; a placard that just says 'crab' doesn't say which species.";
  static const String codNote =
      "SIMP covers both Atlantic cod and Pacific cod, so a placard that just says 'cod' is covered either way.";
  static const String rockfishMisbranding =
      'FDA said in April 2026 that rockfish sold as "snapper" is misbranded (91 Fed. Reg. 16200, Apr. 1, 2026, as cited in FAT Seafood Paper No. 7).';
  static String bycatchLead(String group, String asOf) =>
      'NOAA has denied U.S. market access to some $group fisheries because of marine-mammal bycatch (as of $asOf):';
  static String bycatchPair(String country, String gearPhrase) =>
      '$country — $gearPhrase';
  static const String bycatchTail =
      "Products sold in the U.S. must come from fisheries that were not denied; a counter placard doesn't name the fishery.";
  static const String coolRequirement =
      "Under USDA country-of-origin labeling rules (7 CFR Part 60), a covered retailer must show the fish's country of origin and whether it is wild-caught or farm-raised.";

  /// Same wording as the service-case schema (service_case_schema_screen).
  static const String coolExemptions =
      'Country-of-origin labeling rules apply to larger grocery retailers (those licensed under the Perishable Agricultural Commodities Act) and exempt fish markets, butcher shops, and food-service establishments. A processed or value-added item (breaded, marinated, crab cakes) is not covered by these rules at all.';
  static const String unknownLine = "FAT doesn't recognize that fish name yet.";
  static String get simpGroupsLine {
    const g = SIMPCoverage.speciesGroups;
    return "NOAA's SIMP covers imports of 13 species groups: "
        '${g.sublist(0, g.length - 1).join(', ')} and ${g.last}.';
  }

  // ── Names ──

  /// Names recognized beyond the service-case placard table.
  static const List<String> _extraNames = [
    'dolphinfish',
    'dolphin fish',
    'mahimahi',
    'pacific snapper',
    'pacific red snapper',
    'abalone',
    'sea cucumber',
    'shark',
    'codfish',
    'red king crab',
    'atlantic blue crab',
    'yellowfin',
    'bigeye',
    'bluefin',
    'sockeye',
    'coho',
    'chinook',
  ];

  /// Alias → canonical name (anything else is its own canonical name).
  static const Map<String, String> _aliases = {
    'mahi': 'mahi mahi',
    'mahimahi': 'mahi mahi',
    'dolphinfish': 'mahi mahi',
    'dolphin fish': 'mahi mahi',
    'codfish': 'cod',
    'ahi': 'ahi tuna',
    'yellowfin': 'yellowfin tuna',
    'bigeye': 'bigeye tuna',
    'bluefin': 'bluefin tuna',
    'calamari': 'squid',
    'sockeye': 'sockeye salmon',
    'coho': 'coho salmon',
    'chinook': 'chinook salmon',
  };

  static const Set<String> _rockfishNames = {
    'rockfish',
    'pacific snapper',
    'pacific red snapper',
  };

  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ').trim();

  /// Every recognized name, normalized, longest first.
  static final List<String> _names = () {
    final all = {
      ...ServiceCaseParser.marketNames.map(normalize),
      ..._extraNames.map(normalize),
    }.toList();
    all.sort(
      (a, b) =>
          a.length != b.length ? b.length.compareTo(a.length) : a.compareTo(b),
    );
    return all;
  }();

  /// Longest recognized name in the query (whole words, optional plural).
  static String? match(String query) {
    final q = normalize(query);
    if (q.isEmpty) return null;
    for (final n in _names) {
      if (RegExp(r'\b' + RegExp.escape(n) + r'(s|es)?\b').hasMatch(q)) return n;
    }
    return null;
  }

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  // ── Resolve ──

  static FishNameResult resolve(String query, {MmpaBycatchData? data}) {
    final d = data ?? MmpaBycatchData.bundled;
    final q = query.trim();
    final matched = match(q);
    if (matched == null) {
      return FishNameResult(
        query: q,
        matchedName: null,
        title: unknownTitle,
        simpStatus: null,
        sections: [
          FishNameSection(unknownSectionTitle, [
            const SeafoodDetailLine(unknownLine, SeafoodDetailKind.flag),
            SeafoodDetailLine(simpGroupsLine),
          ]),
        ],
        hasBycatch: false,
        hasMisbrandingNote: false,
      );
    }
    final canonical = _aliases[matched] ?? matched;
    final title = _titleCase(canonical);
    final isRockfish = _rockfishNames.contains(canonical);
    const researchLink = SeafoodDetailLines.researchLink;

    // 1. SIMP
    final simp = <SeafoodDetailLine>[];
    final FishSimpStatus status;
    if (canonical == 'snapper') {
      status = FishSimpStatus.unclear;
      simp.add(const SeafoodDetailLine(snapperUnclear, SeafoodDetailKind.flag));
    } else if (canonical == 'crab') {
      status = FishSimpStatus.unclear;
      simp.add(const SeafoodDetailLine(crabUnclear, SeafoodDetailKind.flag));
    } else if (SIMPCoverage.isCovered(canonical)) {
      status = FishSimpStatus.covered;
      simp.add(const SeafoodDetailLine(SeafoodDetailLines.simpCovered));
      simp.add(const SeafoodDetailLine(simpCoveredDetail));
      if (canonical == 'cod') simp.add(const SeafoodDetailLine(codNote));
    } else {
      status = FishSimpStatus.notCovered;
      simp.add(
        SeafoodDetailLine(
          SeafoodDetailLines.simpNotCovered(
            SeafoodDetailLines.speciesGroup(title),
          ),
        ),
      );
    }
    if (isRockfish) {
      simp.add(
        const SeafoodDetailLine(
          rockfishMisbranding,
          SeafoodDetailKind.flag,
          researchLink,
        ),
      );
    }
    final sections = <FishNameSection>[FishNameSection(simpTitle, simp)];

    // 2. Bycatch — only when the species group is in a Strong pair.
    var hasBycatch = false;
    final group = isRockfish ? null : SeafoodBycatch.groupOf(canonical);
    if (d != null && group != null) {
      final pairs = d.pairs.where((p) => p.speciesGroup == group).toList();
      if (pairs.isNotEmpty) {
        hasBycatch = true;
        sections.add(
          FishNameSection(bycatchTitle, [
            SeafoodDetailLine(
              bycatchLead(group, d.asOf),
              SeafoodDetailKind.flag,
            ),
            for (final p in pairs)
              SeafoodDetailLine(bycatchPair(p.country, p.gearPhrase)),
            const SeafoodDetailLine(
              bycatchTail,
              SeafoodDetailKind.info,
              researchLink,
            ),
          ]),
        );
      }
    }

    // 3. COOL
    sections.add(
      const FishNameSection(coolTitle, [
        SeafoodDetailLine(coolRequirement),
        SeafoodDetailLine(coolExemptions),
      ]),
    );

    return FishNameResult(
      query: q,
      matchedName: canonical,
      title: title,
      simpStatus: status,
      sections: sections,
      hasBycatch: hasBycatch,
      hasMisbrandingNote: isRockfish,
    );
  }

  /// Plain JSON-able snapshot, compared against the shared parity baseline.
  static Map<String, dynamic> snapshot(FishNameResult r) => {
    'title': r.title,
    'matchedName': r.matchedName,
    'simpStatus': r.simpStatus?.name,
    'historyTitle': r.historyTitle,
    'sections': [
      for (final s in r.sections)
        {
          'title': s.title,
          'lines': [
            for (final l in s.lines)
              {
                'text': l.text,
                'kind': l.kind == SeafoodDetailKind.flag ? 'flag' : 'info',
                'link': l.link?.url,
              },
          ],
        },
    ],
  };
}
