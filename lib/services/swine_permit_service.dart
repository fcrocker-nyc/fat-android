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

  List<String> get cardLines =>
      [countLine, npdesLine, unpublishedLine].whereType<String>().toList();
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
  const SwinePlantAggregate(this.total, this.byState, this.lagoon, this.npdes,
      this.parentHeld, this.unpublished);
}

class SwinePermitData {
  final String generated;
  final int radiusMiles;
  final Map<String, SwinePermitStateInfo> states;
  final Map<String, SwinePlantAggregate> plants;

  SwinePermitData._(this.generated, this.radiusMiles, this.states, this.plants);

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
        );
      });
      return SwinePermitData._('${d['generated'] ?? ''}',
          (d['radiusMiles'] as num?)?.toInt() ?? 50, states, plants);
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
