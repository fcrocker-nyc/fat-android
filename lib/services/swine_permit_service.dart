// State swine (hog) permit records near a pork plant — INFORMATIONAL only.
// Never a score input: no category status, disclosure count, index or penalty
// changes. Outputs, all on pork meat-lane scans whose processing plant
// resolves to one FSIS establishment_id (a shared number only when every
// candidate is within 10 miles — then the first candidate's id):
//   1. a count line on the "Nearby Hog Farm" card, next to the EPA-ECHO result,
//      plus a federal-permit (NPDES) line where the states publish the flag;
//   2. a Cat. 16 (Supply-Chain Intermediaries) detail line when permits within
//      50 miles are held by an entity mapped to the plant's parent company.
//      The line never changes Cat. 16's status: the label didn't disclose it.
//
// Dataset: fat-android/swine-permits/fat_swine_nearby.json (served by
// jsDelivr) — PER-PLANT AGGREGATES only (no farm names, coordinates or permit
// numbers), built from NC DEQ, MPCA, MoDNR, Iowa DNR, NE DWEE, IDEM and EGLE
// public data. See swine-permits/README.md for sources, dates and filters.
// Mirrors iOS FATAppMVP2/SwinePermitService.swift.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'establishments_service.dart';
import 'processor_service.dart';

class SwinePermitStateInfo {
  final String code;
  final String agency;
  final String label; // short agency name, e.g. "NC DEQ"
  final String source;
  final String date; // YYYY-MM-DD, or a year
  final int count;
  final bool lagoonData;
  final bool npdesData; // the state's records carry an NPDES flag
  const SwinePermitStateInfo(this.code, this.agency, this.label, this.source,
      this.date, this.count, this.lagoonData, this.npdesData);

  /// "NC DEQ, April 2026" / "EGLE, 2024".
  String get citation {
    final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(date);
    if (m == null) return '$label, $date';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    return '$label, ${months[int.parse(m.group(2)!) - 1]} ${m.group(1)}';
  }
}

// ── Owner → processor parent (exact entity names only) ─────────────────────

enum SwineParent { smithfield, seaboard }

extension SwineParentName on SwineParent {
  String get displayName => switch (this) {
        SwineParent.smithfield => 'Smithfield Foods',
        SwineParent.seaboard => 'Seaboard Foods',
      };
}

class SwinePermitOwnership {
  SwinePermitOwnership._();

  /// Normalised permit-owner names mapped to a processor parent. Exact match
  /// after normalisation only — never a substring — because look-alikes are
  /// common ("Tyson Five LLC", "Triumph Associates LLC", "Hanor Multiplier",
  /// "Smithfield Ridge Lc", "Smithfield Enterprises LLC" are not the packers).
  static const Map<String, SwineParent> _owners = {
    // Smithfield Foods, Inc. 10-K (filed 2026), Exhibit 21.1 — subsidiaries
    // "Murphy-Brown LLC (d/b/a Smithfield Hog Production)" and "Murphy-Brown
    // of Missouri LLC (d/b/a Smithfield Hog Production)", both Delaware:
    // https://investors.smithfieldfoods.com/sec-filings/sec-filings/content/0000091388-26-000014/a10-kexhibit211.htm
    'murphy brown llc': SwineParent.smithfield,
    'murphy brown of missouri llc': SwineParent.smithfield,
    'smithfield hog production': SwineParent.smithfield,
    // Seaboard Corporation FY2025 10-K, Exhibit 21 — "Seaboard Foods LLC"
    // (Oklahoma):
    // https://www.sec.gov/Archives/edgar/data/88121/000008812126000012/seb-20251231xex21.htm
    'seaboard foods llc': SwineParent.seaboard,
    // Not mapped (corporate link not verified from an official/company
    // source): Seaboard Foods LP, Prestage Farms, JBS Live Pork / JBS Farms,
    // Triumph, Country View Family Farms (Clemens), Maxwell Foods.
  };

  /// Lowercase, hyphens/punctuation folded to spaces, whitespace collapsed,
  /// and a trailing "d/b/a …" dropped (MoDNR truncates owner names, e.g.
  /// "Murphy-Brown of Missouri LLC d/b/a Smith").
  static String normalize(String s) {
    var t = s.toLowerCase();
    final dba = RegExp(r'\s(d/b/a|dba)\b').firstMatch(t);
    if (dba != null) t = t.substring(0, dba.start);
    t = t.replaceAll(RegExp(r'[-.,]'), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static SwineParent? parentForOwner(String? owner) {
    if (owner == null || owner.trim().isEmpty) return null;
    return _owners[normalize(owner)];
  }

  /// The plant's parent as the FAT parent-company database / crosswalk names
  /// it ("Smithfield Foods", "WH Group Limited", "Seaboard Foods").
  static SwineParent? parentForPlant(String? parentName) {
    final n = (parentName ?? '').toLowerCase();
    if (n.contains('smithfield') || n.contains('wh group')) {
      return SwineParent.smithfield;
    }
    if (n.contains('seaboard')) return SwineParent.seaboard;
    return null;
  }
}

// ── Summary + copy ─────────────────────────────────────────────────────────

class SwinePermitSummary {
  final int radiusMiles;
  final int total;
  /// Operations by published state the radius reaches (0 = reached, none).
  final Map<String, int> byState;
  /// States whose records carry lagoon data and contributed to [total].
  final List<String> lagoonStates;
  final int lagoonCount;
  /// States whose records carry an NPDES flag and contributed to [total].
  final List<String> npdesStates;
  /// Operations in [npdesStates] holding an NPDES permit.
  final int npdesCount;
  /// Dataset states the radius reaches (sources cited in the count line).
  final List<SwinePermitStateInfo> sources;
  /// States the radius reaches with no published data (not counted).
  final List<String> unpublished;
  final SwineParent? parent;
  final int parentHoldings;
  final List<String> parentStates;
  /// Iowa DNR compliance counts for the Iowa operations in range, or null.
  final SwineIowaCompliance? iowa;
  final String iowaRetrieved;
  /// NC DEQ document-record counts for the NC operations in range, or null.
  final SwineNcCompliance? nc;
  final String ncRetrieved;
  /// IDEM enforcement counts for the Indiana operations in range, or null.
  final SwineInCompliance? indiana;
  final String inRetrieved;
  /// MoDNR warning/violation counts for the Missouri operations in range, or null.
  final SwineMoCompliance? missouri;
  final String moRetrieved;

  const SwinePermitSummary({
    required this.radiusMiles,
    required this.total,
    required this.byState,
    required this.lagoonStates,
    required this.lagoonCount,
    required this.npdesStates,
    required this.npdesCount,
    required this.sources,
    required this.unpublished,
    required this.parent,
    required this.parentHoldings,
    required this.parentStates,
    this.iowa,
    this.iowaRetrieved = '',
    this.nc,
    this.ncRetrieved = '',
    this.indiana,
    this.inRetrieved = '',
    this.missouri,
    this.moRetrieved = '',
  });

  bool get isEmpty => sources.isEmpty && unpublished.isEmpty;

  Set<String> get _contributing =>
      byState.entries.where((e) => e.value > 0).map((e) => e.key).toSet();

  /// "State permit records list N hog operations within 50 miles of this
  /// plant (sources: …)" + the lagoon clause when lagoon data exists.
  String? get countLine {
    if (sources.isEmpty) return null;
    final n = SwinePermitText.number(total);
    final ops = total == 1 ? 'hog operation' : 'hog operations';
    final src = sources.map((s) => s.citation).join('; ');
    final base =
        'State permit records list $n $ops within $radiusMiles miles of this plant (sources: $src)';
    if (lagoonStates.isEmpty || total == 0) return '$base.';
    final m = SwinePermitText.number(lagoonCount);
    if (_contributing.every(lagoonStates.contains)) {
      return '$base, $m of them with at least one waste lagoon.';
    }
    return '$base. In the ${SwinePermitText.stateList(lagoonStates)} records, $m list at least one waste lagoon.';
  }

  /// "Of these, K hold a federal Clean Water Act (NPDES) permit; the other
  /// N−K don't appear in EPA's database." K and N cover only states whose
  /// records carry an NPDES flag; when other states also contribute, the
  /// sentence names the flagged states.
  String? get npdesLine {
    if (npdesStates.isEmpty || total == 0) return null;
    final n = npdesStates.fold<int>(0, (a, c) => a + (byState[c] ?? 0));
    if (n == 0) return null;
    final k = npdesCount;
    final rest = n - k;
    final permit = 'a federal Clean Water Act (NPDES) permit';
    if (_contributing.every(npdesStates.contains)) {
      if (rest == 0) {
        return n == 1
            ? 'It holds $permit.'
            : 'All ${SwinePermitText.number(n)} hold $permit.';
      }
      final hold = k == 1 ? 'holds' : 'hold';
      final other = rest == 1
          ? "the other one doesn't appear in EPA's database"
          : "the other ${SwinePermitText.number(rest)} don't appear in EPA's database";
      return 'Of these, ${SwinePermitText.number(k)} $hold $permit; $other.';
    }
    final where = 'In the ${SwinePermitText.stateList(npdesStates)} records';
    if (rest == 0) {
      return '$where, all ${SwinePermitText.number(n)} hold $permit.';
    }
    final hold = k == 1 ? 'holds' : 'hold';
    final restText = rest == 1
        ? "the other one doesn't appear in EPA's database"
        : "the rest don't appear in EPA's database";
    return '$where, ${SwinePermitText.number(k)} of ${SwinePermitText.number(n)} $hold $permit; $restText.';
  }

  /// "Data not published by South Carolina — not counted."
  String? get unpublishedLine => unpublished.isEmpty
      ? null
      : 'Data not published by ${SwinePermitText.stateList(unpublished, conj: 'or')} — not counted.';

  /// Cat. 16 detail line, or null (never a claim of independence).
  String? get parentLine {
    final p = parent;
    if (p == null || parentHoldings < 1) return null;
    final farms = parentHoldings == 1 ? 'hog farm' : 'hog farms';
    return "The plant's parent company (${p.displayName}) holds state permits for at least ${SwinePermitText.number(parentHoldings)} $farms within $radiusMiles miles (${SwinePermitText.stateList(parentStates)} permit records). Contract farms are listed under growers' own names, so this is a minimum.";
  }

  /// Iowa DNR field-office compliance lines (operations, not violations):
  /// who was cited, how many of those citations came from field work rather
  /// than plan paperwork, manure spills, and the source. Never a score input.
  List<String> get iowaLines {
    final c = iowa;
    if (c == null) return const [];
    final fmt = SwinePermitText.number;
    final j = c.records;
    final iowaOnly = _contributing.every((s) => s == 'IA') && j == (byState['IA'] ?? 0);
    const agency = 'Iowa Department of Natural Resources';
    const notices = 'notice of violation or letter of non-compliance';
    final ops = j == 1 ? 'hog operation' : 'hog operations';
    final lines = <String>[];
    if (c.cited == 0) {
      lines.add(iowaOnly
          ? '$agency field-office records show no $notices for ${j == 1 ? 'this Iowa hog operation' : 'these ${fmt(j)} Iowa hog operations'}.'
          : 'In the Iowa records, $agency field offices show no $notices for the ${fmt(j)} Iowa $ops.');
    } else {
      final recent = c.citedFiveYears == 0
          ? 'none of them in the last five years'
          : '${fmt(c.citedFiveYears)} of them in the last five years';
      if (j == 1) {
        final when = c.citedFiveYears > 0 ? ', most recently within the last five years' : ', none in the last five years';
        lines.add(iowaOnly
            ? '$agency field-office records show this Iowa hog operation received at least one $notices$when.'
            : 'In the Iowa records, the one hog operation received at least one $notices from the $agency$when.');
      } else {
        lines.add(iowaOnly
            ? '$agency field-office records show ${fmt(c.cited)} of these ${fmt(j)} Iowa hog operations received at least one $notices, $recent.'
            : 'In the Iowa records, ${fmt(c.cited)} of ${fmt(j)} hog operations received at least one $notices from the $agency, $recent.');
      }
      final rest = c.cited - c.fieldCited;
      if (c.fieldCited == 0) {
        lines.add('All of these notices were issued after paperwork reviews, such as manure management plans.');
      } else if (rest == 0) {
        lines.add(c.cited == 1
            ? 'It was issued after an inspection, complaint or spill, not a paperwork review.'
            : 'Each of these operations had one from an inspection, complaint or spill, not just a paperwork review.');
      } else {
        lines.add('${fmt(c.fieldCited)} of these ${fmt(c.cited)} had one from an inspection, complaint or spill; for the other ${fmt(rest)}, the notices were issued only after paperwork reviews, such as manure management plans.');
      }
    }
    if (c.manureSpills > 0) {
      lines.add('Manure spills are on record for ${fmt(c.manureSpills)} of the ${fmt(j)} Iowa $ops.');
    }
    lines.add('Source: Iowa DNR Field Office Compliance database${_retrievedText(iowaRetrieved)}. It tracks field-office actions since about 2009 and does not include enforcement by DNR\'s central office.');
    return lines;
  }

  /// North Carolina DEQ lines (operations, not violations): notices of
  /// violation, civil penalties, deficiency-only notices, and the source.
  /// Never a score input.
  List<String> get ncLines {
    final c = nc;
    if (c == null) return const [];
    final fmt = SwinePermitText.number;
    final j = c.records;
    final ncOnly = _contributing.every((s) => s == 'NC') && j == (byState['NC'] ?? 0);
    const agency = 'North Carolina Department of Environmental Quality';
    final lines = <String>[];
    if (c.noticed == 0) {
      lines.add(ncOnly
          ? '$agency records show no notice of violation for ${j == 1 ? 'this North Carolina hog operation' : 'these ${fmt(j)} North Carolina hog operations'}.'
          : 'In the North Carolina records, $agency files show no notice of violation for the ${fmt(j)} North Carolina ${j == 1 ? 'hog operation' : 'hog operations'}.');
    } else if (j == 1) {
      final when = c.noticedFiveYears > 0 ? ', most recently within the last five years' : ', none in the last five years';
      lines.add(ncOnly
          ? '$agency records show this North Carolina hog operation received at least one notice of violation$when.'
          : 'In the North Carolina records, the one hog operation received at least one notice of violation from the $agency$when.');
    } else {
      final recent = c.noticedFiveYears == 0
          ? 'none of them in the last five years'
          : '${fmt(c.noticedFiveYears)} of them in the last five years';
      lines.add(ncOnly
          ? '$agency records show ${fmt(c.noticed)} of these ${fmt(j)} North Carolina hog operations received at least one notice of violation, $recent.'
          : 'In the North Carolina records, ${fmt(c.noticed)} of ${fmt(j)} hog operations received at least one notice of violation from the $agency, $recent.');
    }
    final extra = <String>[];
    if (c.penalized > 0) {
      extra.add(c.penalized == 1
          ? '1 operation was assessed a civil penalty.'
          : '${fmt(c.penalized)} operations were assessed a civil penalty.');
    }
    if (c.deficiencyOnly > 0) {
      extra.add(c.deficiencyOnly == 1
          ? '1 operation received a notice of deficiency, a lesser finding, but no notice of violation.'
          : '${fmt(c.deficiencyOnly)} operations received a notice of deficiency, a lesser finding, but no notice of violation.');
    }
    if (extra.isNotEmpty) lines.add(extra.join(' '));
    lines.add('Source: NC DEQ Division of Water Resources document records${_retrievedText(ncRetrieved)}. Itemized records begin around 2018; older files are scanned in bulk and not counted.');
    return lines;
  }

  /// Indiana IDEM lines (operations, not violations): formal enforcement
  /// documents, agreed or commissioner's orders, and the source. Never a
  /// score input.
  List<String> get indianaLines {
    final c = indiana;
    if (c == null) return const [];
    final fmt = SwinePermitText.number;
    final j = c.records;
    final inOnly = _contributing.every((s) => s == 'IN') && j == (byState['IN'] ?? 0);
    const agency = 'Indiana Department of Environmental Management';
    const action = 'notice of violation or other formal enforcement action';
    final lines = <String>[];
    if (c.cited == 0) {
      lines.add(inOnly
          ? '$agency records show no $action for ${j == 1 ? 'this Indiana hog operation' : 'these ${fmt(j)} Indiana hog operations'}.'
          : 'In the Indiana records, $agency files show no $action for the ${fmt(j)} Indiana ${j == 1 ? 'hog operation' : 'hog operations'}.');
    } else if (j == 1) {
      final when = c.citedFiveYears > 0 ? ', most recently within the last five years' : ', none in the last five years';
      lines.add(inOnly
          ? '$agency records show this Indiana hog operation received a $action$when.'
          : 'In the Indiana records, the one hog operation received a $action from the $agency$when.');
    } else {
      final recent = c.citedFiveYears == 0
          ? 'none of them in the last five years'
          : '${fmt(c.citedFiveYears)} of them in the last five years';
      lines.add(inOnly
          ? '$agency records show ${fmt(c.cited)} of these ${fmt(j)} Indiana hog operations received a $action, $recent.'
          : 'In the Indiana records, ${fmt(c.cited)} of ${fmt(j)} hog operations received a $action from the $agency, $recent.');
    }
    if (c.ordered > 0) {
      lines.add(c.ordered == 1
          ? "1 operation settled a case through an agreed order or was issued a commissioner's order."
          : "${fmt(c.ordered)} operations settled a case through an agreed order or were issued a commissioner's order.");
    }
    lines.add('Source: IDEM Virtual File Cabinet, Confined Feeding enforcement documents${_retrievedText(inRetrieved)}. Scanned records are sparse before 2009.');
    return lines;
  }

  /// Missouri DNR lines (operations, not violations; floors, because the
  /// source is matched by farm name and county). Never a score input.
  List<String> get missouriLines {
    final c = missouri;
    if (c == null) return const [];
    final fmt = SwinePermitText.number;
    final j = c.records;
    final moOnly = _contributing.every((s) => s == 'MO') && j == (byState['MO'] ?? 0);
    const agency = 'Missouri Department of Natural Resources';
    const notice = 'letter of warning or notice of violation';
    final lines = <String>[];
    if (c.warned == 0) {
      lines.add('No $notice was found in $agency records for ${j == 1 ? 'this Missouri hog operation' : 'these ${fmt(j)} Missouri hog operations'}.');
    } else if (j == 1) {
      final when = c.warnedFiveYears > 0 ? ', most recently within the last five years' : ', none in the last five years';
      lines.add('$agency records show ${moOnly ? 'this' : 'the one'} Missouri hog operation received at least one $notice$when.');
    } else {
      final recent = c.warnedFiveYears == 0
          ? 'none of them in the last five years'
          : '${fmt(c.warnedFiveYears)} of them in the last five years';
      lines.add(moOnly
          ? '$agency records show at least ${fmt(c.warned)} of these ${fmt(j)} Missouri hog operations received a $notice, $recent.'
          : 'In the Missouri records, at least ${fmt(c.warned)} of ${fmt(j)} hog operations received a $notice from the $agency, $recent.');
    }
    if (c.violations > 0) {
      lines.add(c.violations == 1
          ? '1 operation received a notice of violation, the more serious of the two.'
          : '${fmt(c.violations)} operations received a notice of violation, the more serious of the two.');
    }
    lines.add("Source: Missouri DNR Letters of Warning and Notices of Violation search${_retrievedText(moRetrieved)}, matched by farm name and county. Records start in 2009, and DNR says the search holds most but not all of these letters.");
    return lines;
  }

  static String _retrievedText(String date) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(date);
    if (m == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    return ', retrieved ${months[int.parse(m.group(2)!) - 1]} ${int.parse(m.group(3)!)}, ${m.group(1)}';
  }

  List<String> get cardLines => [
        countLine,
        npdesLine,
        ...iowaLines,
        ...ncLines,
        ...indianaLines,
        ...missouriLines,
        unpublishedLine
      ].whereType<String>().toList();
}

class SwinePermitText {
  SwinePermitText._();

  static String number(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String stateList(List<String> codes, {String conj = 'and'}) {
    final names = codes.map((c) => stateNames[c] ?? c).toList();
    if (names.length <= 1) return names.join();
    if (names.length == 2) return '${names[0]} $conj ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')}, $conj ${names.last}';
  }

  static const stateNames = <String, String>{
    'AL': 'Alabama', 'AZ': 'Arizona', 'AR': 'Arkansas', 'CA': 'California',
    'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
    'DC': 'the District of Columbia', 'FL': 'Florida', 'GA': 'Georgia',
    'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
    'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine',
    'MD': 'Maryland', 'MA': 'Massachusetts', 'MI': 'Michigan',
    'MN': 'Minnesota', 'MS': 'Mississippi', 'MO': 'Missouri',
    'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
    'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico',
    'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota',
    'OH': 'Ohio', 'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania',
    'RI': 'Rhode Island', 'SC': 'South Carolina', 'SD': 'South Dakota',
    'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah', 'VT': 'Vermont',
    'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
    'WI': 'Wisconsin', 'WY': 'Wyoming',
  };
}

// ── Dataset ────────────────────────────────────────────────────────────────

/// One plant's aggregate (counts only).
class SwinePlantAggregate {
  final int total;
  final Map<String, int> byState;
  final int? lagoon;
  final int? npdes;
  final Map<String, Map<String, int>> parentHeld; // parent key → state → n
  final List<String> unpublished;
  final SwineIowaCompliance? iowa;
  final SwineNcCompliance? nc;
  final SwineInCompliance? indiana;
  final SwineMoCompliance? missouri;
  const SwinePlantAggregate(this.total, this.byState, this.lagoon, this.npdes,
      this.parentHeld, this.unpublished, [this.iowa, this.nc, this.indiana, this.missouri]);
}

/// Missouri DNR warning/violation counts for the Missouri operations within
/// the radius (operations, not violations). Matched by farm name and county,
/// so the counts are floors. See swine-permits/README.md.
class SwineMoCompliance {
  final int records; // j: Missouri operations
  final int warned; // v: with ≥1 letter of warning or notice of violation
  final int warnedFiveYears; // v5: …dated in the last five years
  final int violations; // nov: with a notice of violation
  const SwineMoCompliance(this.records, this.warned, this.warnedFiveYears, this.violations);

  static SwineMoCompliance? fromJson(Object? m) {
    if (m is! Map) return null;
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    final j = n('j');
    return j > 0 ? SwineMoCompliance(j, n('v'), n('v5'), n('nov')) : null;
  }
}

/// Indiana IDEM enforcement-document counts for the Indiana operations within
/// the radius (operations, not violations). See swine-permits/README.md.
class SwineInCompliance {
  final int records; // j: Indiana operations
  final int cited; // v: with ≥1 formal enforcement document (NOV, order, referral…)
  final int citedFiveYears; // v5: …dated in the last five years
  final int ordered; // ao: with an agreed order or commissioner's order
  const SwineInCompliance(this.records, this.cited, this.citedFiveYears, this.ordered);

  static SwineInCompliance? fromJson(Object? m) {
    if (m is! Map) return null;
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    final j = n('j');
    return j > 0 ? SwineInCompliance(j, n('v'), n('v5'), n('ao')) : null;
  }
}

/// North Carolina DEQ document-record counts for the NC operations within the
/// radius (operations, not violations). See swine-permits/README.md.
class SwineNcCompliance {
  final int records; // j: NC operations with a DEQ document record
  final int noticed; // v: with ≥1 notice of violation
  final int noticedFiveYears; // v5: …dated in the last five years
  final int penalized; // cp: with ≥1 civil penalty assessment
  final int deficiencyOnly; // nd: notice of deficiency but no notice of violation
  const SwineNcCompliance(this.records, this.noticed, this.noticedFiveYears,
      this.penalized, this.deficiencyOnly);

  static SwineNcCompliance? fromJson(Object? m) {
    if (m is! Map) return null;
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    final j = n('j');
    return j > 0 ? SwineNcCompliance(j, n('v'), n('v5'), n('cp'), n('nd')) : null;
  }
}

/// Iowa DNR field-office compliance counts for the Iowa operations within the
/// radius (operations, not violations). See swine-permits/README.md.
class SwineIowaCompliance {
  final int records; // j: Iowa operations with a DNR compliance record page
  final int cited; // v: with ≥1 notice of violation / letter of non-compliance
  final int citedFiveYears; // v5: …dated in the last five years
  final int fieldCited; // vf: …from an inspection, complaint or spill (not plan paperwork)
  final int manureSpills; // ms: with a manure spill linked to the operation
  const SwineIowaCompliance(this.records, this.cited, this.citedFiveYears,
      this.fieldCited, this.manureSpills);

  static SwineIowaCompliance? fromJson(Object? m) {
    if (m is! Map) return null;
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    final j = n('j');
    return j > 0 ? SwineIowaCompliance(j, n('v'), n('v5'), n('vf'), n('ms')) : null;
  }
}

class SwinePermitData {
  final String generated;
  final int radiusMiles;
  final Map<String, SwinePermitStateInfo> states;
  final Map<String, SwinePlantAggregate> plants;
  /// Retrieval date (YYYY-MM-DD) of the Iowa DNR compliance records, or ''.
  final String iowaComplianceRetrieved;
  /// Retrieval date (YYYY-MM-DD) of the NC DEQ document records, or ''.
  final String ncComplianceRetrieved;
  /// Retrieval date (YYYY-MM-DD) of the IDEM enforcement documents, or ''.
  final String inComplianceRetrieved;
  /// Retrieval date (YYYY-MM-DD) of the MoDNR warning/violation search, or ''.
  final String moComplianceRetrieved;

  SwinePermitData._(this.generated, this.radiusMiles, this.states, this.plants,
      [this.iowaComplianceRetrieved = '', this.ncComplianceRetrieved = '',
      this.inComplianceRetrieved = '', this.moComplianceRetrieved = '']);

  static Map<String, int> _counts(Object? m) => m is Map
      ? m.map((k, v) => MapEntry('$k', (v as num).toInt()))
      : <String, int>{};

  static SwinePermitData? parse(String body) {
    try {
      final d = jsonDecode(body);
      if (d is! Map) return null;
      final states = <String, SwinePermitStateInfo>{};
      (d['states'] as Map).forEach((k, v) {
        final m = v as Map;
        states['$k'] = SwinePermitStateInfo(
          '$k',
          '${m['agency'] ?? ''}',
          '${m['label'] ?? k}',
          '${m['source'] ?? ''}',
          '${m['date'] ?? ''}',
          (m['count'] as num?)?.toInt() ?? 0,
          m['lagoon'] == true,
          m['npdes'] == true,
        );
      });
      final plants = <String, SwinePlantAggregate>{};
      (d['plants'] as Map).forEach((k, v) {
        final m = v as Map;
        final ph = <String, Map<String, int>>{};
        if (m['ph'] is Map) {
          (m['ph'] as Map).forEach((pk, pv) => ph['$pk'] = _counts(pv));
        }
        plants['$k'] = SwinePlantAggregate(
          (m['n'] as num?)?.toInt() ?? 0,
          _counts(m['s']),
          (m['l'] as num?)?.toInt(),
          (m['np'] as num?)?.toInt(),
          ph,
          ((m['u'] as List?) ?? const []).map((e) => '$e').toList(),
          SwineIowaCompliance.fromJson(m['ia']),
          SwineNcCompliance.fromJson(m['nc']),
          SwineInCompliance.fromJson(m['in']),
          SwineMoCompliance.fromJson(m['mo']),
        );
      });
      String retrieved(String st) {
        final c = ((d['states'] as Map)[st] as Map?)?['compliance'];
        return c is Map ? '${c['retrieved'] ?? ''}' : '';
      }
      return SwinePermitData._('${d['generated'] ?? ''}',
          (d['radiusMiles'] as num?)?.toInt() ?? 50, states, plants,
          retrieved('IA'), retrieved('NC'), retrieved('IN'), retrieved('MO'));
    } catch (_) {
      return null;
    }
  }

  /// The FSIS establishment_id to look up: the resolved plant, or — for a
  /// shared number — the first candidate, only when every candidate is within
  /// 10 miles (same rule as the EPA proximity point). Null otherwise.
  static String? plantKey(ProcessorRecord? record, List<FatEstablishment> shared) {
    if (EstablishmentsService.proximityPoint(record, shared) == null) return null;
    final id = shared.isNotEmpty
        ? shared.first.establishmentId
        : record?.resolvedPlant?.establishmentId;
    return (id == null || id.trim().isEmpty) ? null : id.trim();
  }

  /// Summary for one plant, or null when the plant isn't in the dataset (no
  /// operation within the radius and no not-published state in range).
  SwinePermitSummary? summaryFor(String? establishmentId,
      {String? plantParentName}) {
    final a = establishmentId == null ? null : plants[establishmentId];
    if (a == null) return null;
    final contributing =
        a.byState.entries.where((e) => e.value > 0).map((e) => e.key);
    final sources = a.byState.keys
        .where(states.containsKey)
        .map((c) => states[c]!)
        .toList()
      ..sort((x, y) => x.code.compareTo(y.code));
    final lagoonStates = contributing
        .where((c) => states[c]?.lagoonData ?? false)
        .toList()
      ..sort();
    final npdesStates = contributing
        .where((c) => states[c]?.npdesData ?? false)
        .toList()
      ..sort();
    final parent = SwinePermitOwnership.parentForPlant(plantParentName);
    final held = parent == null
        ? const <String, int>{}
        : (a.parentHeld[parent.name] ?? const <String, int>{});
    return SwinePermitSummary(
      radiusMiles: radiusMiles,
      total: a.total,
      byState: a.byState,
      lagoonStates: lagoonStates,
      lagoonCount: a.lagoon ?? 0,
      npdesStates: npdesStates,
      npdesCount: a.npdes ?? 0,
      sources: sources,
      unpublished: List.of(a.unpublished)..sort(),
      parent: parent,
      parentHoldings: held.values.fold<int>(0, (x, y) => x + y),
      parentStates: (held.entries.where((e) => e.value > 0).map((e) => e.key).toList()
        ..sort()),
      iowa: (a.byState['IA'] ?? 0) > 0 ? a.iowa : null,
      iowaRetrieved: iowaComplianceRetrieved,
      nc: (a.byState['NC'] ?? 0) > 0 ? a.nc : null,
      ncRetrieved: ncComplianceRetrieved,
      indiana: (a.byState['IN'] ?? 0) > 0 ? a.indiana : null,
      inRetrieved: inComplianceRetrieved,
      missouri: (a.byState['MO'] ?? 0) > 0 ? a.missouri : null,
      moRetrieved: moComplianceRetrieved,
    );
  }
}

// ── Download + weekly cache ────────────────────────────────────────────────

class SwinePermitService {
  SwinePermitService._();

  static const url =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/swine-permits/fat_swine_nearby.json';
  static const _maxAge = Duration(days: 7);
  static SwinePermitData? _memory;

  /// Cached copy when under a week old; otherwise downloads, falling back to a
  /// stale cached copy. Fail-open: null when nothing is available.
  static Future<SwinePermitData?> load() async {
    if (_memory != null) return _memory;
    File? file;
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}/fat_swine_nearby.json');
    } catch (_) {}
    String? cached;
    var fresh = false;
    try {
      if (file != null && await file.exists()) {
        cached = await file.readAsString();
        fresh = DateTime.now().difference(await file.lastModified()) < _maxAge;
      }
    } catch (_) {}
    if (!fresh) {
      try {
        final r = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          final body = utf8.decode(r.bodyBytes);
          final parsed = await compute(SwinePermitData.parse, body);
          if (parsed != null) {
            try {
              await file?.writeAsString(body);
            } catch (_) {}
            return _memory = parsed;
          }
        }
      } catch (_) {}
    }
    if (cached == null) return null;
    return _memory = await compute(SwinePermitData.parse, cached);
  }
}
