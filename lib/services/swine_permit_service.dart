// State swine (hog) permit records near a pork plant — INFORMATIONAL only.
// Never a score input: no category status, disclosure count, index or penalty
// changes. Two outputs, both on pork meat-lane scans whose processing plant
// has coordinates (EstablishmentsService.proximityPoint — a shared number only
// when every candidate is within 10 miles):
//   1. a count line on the "Nearby Hog Farm" card, next to the EPA-ECHO result;
//   2. a Cat. 16 (Supply-Chain Intermediaries) detail line when permits within
//      75 miles are held by an entity mapped to the plant's parent company.
//      The line never changes Cat. 16's status: the label didn't disclose it.
//
// Dataset: fat-android/swine-permits/fat_swine_permits.json (served by
// jsDelivr), built from NC DEQ, MPCA, MoDNR, Iowa DNR, NE DWEE, IDEM and EGLE
// public data. See swine-permits/README.md for sources, dates and filters.
// Mirrors iOS FATAppMVP2/SwinePermitService.swift.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'establishments_service.dart';

class SwinePermitRecord {
  final String state;
  final String id;
  final String? name;
  final String? owner;
  final double lat;
  final double lon;
  final int? animals;
  final bool? lagoon; // null when the state publishes no lagoon data
  const SwinePermitRecord(this.state, this.id, this.name, this.owner, this.lat,
      this.lon, this.animals, this.lagoon);
}

class SwinePermitStateInfo {
  final String code;
  final String agency;
  final String label; // short agency name, e.g. "NC DEQ"
  final String source;
  final String date; // YYYY-MM-DD, or a year
  final int count;
  final bool lagoonData;
  final bool ownerData;
  const SwinePermitStateInfo(this.code, this.agency, this.label, this.source,
      this.date, this.count, this.lagoonData, this.ownerData);

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
  final Map<String, int> byState;
  /// States whose records carry lagoon data and contributed to [total].
  final List<String> lagoonStates;
  final int lagoonCount;
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
    required this.sources,
    required this.unpublished,
    required this.parent,
    required this.parentHoldings,
    required this.parentStates,
  });

  bool get isEmpty => sources.isEmpty && unpublished.isEmpty;

  /// "State permit records list N hog operations within 75 miles of this
  /// plant (sources: …)" + the lagoon clause when lagoon data exists.
  String? get countLine {
    if (sources.isEmpty) return null;
    final n = SwinePermitText.number(total);
    final ops = total == 1 ? 'hog operation' : 'hog operations';
    final src = sources.map((s) => s.citation).join('; ');
    final base =
        'State permit records list $n $ops within $radiusMiles miles of this plant (sources: $src)';
    if (lagoonStates.isEmpty || total == 0) return '$base.';
    final contributing =
        byState.entries.where((e) => e.value > 0).map((e) => e.key).toSet();
    final m = SwinePermitText.number(lagoonCount);
    if (contributing.every(lagoonStates.contains)) {
      return '$base, $m of them with at least one waste lagoon.';
    }
    return '$base. In the ${SwinePermitText.stateList(lagoonStates)} records, $m list at least one waste lagoon.';
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
      [countLine, unpublishedLine].whereType<String>().toList();
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

class SwinePermitData {
  final String generated;
  final Map<String, SwinePermitStateInfo> states;
  final List<SwinePermitRecord> records;
  final List<String> _gridCodes;
  final double _lat0, _lon0, _step;
  final List<List<int>> _rows; // per row: [code, runLength, ...]

  SwinePermitData._(this.generated, this.states, this.records, this._gridCodes,
      this._lat0, this._lon0, this._step, this._rows);

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
          m['owner'] == true,
        );
      });
      final recs = <SwinePermitRecord>[];
      for (final r in (d['r'] as List)) {
        final a = r as List;
        recs.add(SwinePermitRecord(
          '${a[0]}',
          '${a[1]}',
          a[2] as String?,
          a[3] as String?,
          (a[4] as num).toDouble(),
          (a[5] as num).toDouble(),
          (a[6] as num?)?.toInt(),
          a[7] == null ? null : a[7] == 1,
        ));
      }
      final g = d['grid'] as Map;
      return SwinePermitData._(
        '${d['generated'] ?? ''}',
        states,
        recs,
        (g['codes'] as List).map((e) => '$e').toList(),
        (g['lat0'] as num).toDouble(),
        (g['lon0'] as num).toDouble(),
        (g['step'] as num).toDouble(),
        (g['rows'] as List)
            .map((row) => (row as List).map((e) => (e as num).toInt()).toList())
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  /// State whose 0.1° grid cell contains the point, or null outside the US.
  String? stateAt(double lat, double lon) {
    final r = ((lat - _lat0) / _step).floor();
    final c = ((lon - _lon0) / _step).floor();
    if (r < 0 || r >= _rows.length || c < 0) return null;
    final row = _rows[r];
    var end = 0;
    for (var k = 0; k + 1 < row.length; k += 2) {
      end += row[k + 1];
      if (c < end) return row[k] < 0 ? null : _gridCodes[row[k]];
    }
    return null;
  }

  /// States a [miles] radius reaches, sampled every 5 miles.
  Set<String> statesWithin(double lat, double lon, int miles) {
    final out = <String>{};
    for (var rad = 0; rad <= miles; rad += 5) {
      final n = math.max(1, (2 * math.pi * rad / 5).floor());
      for (var k = 0; k < n; k++) {
        final b = 2 * math.pi * k / n;
        final dLat = rad * math.cos(b) / 69.0;
        final dLon = rad * math.sin(b) / (69.0 * math.cos(lat * math.pi / 180));
        final s = stateAt(lat + dLat, lon + dLon);
        if (s != null) out.add(s);
      }
    }
    return out;
  }

  List<SwinePermitRecord> near(double lat, double lon, int miles) {
    final dLat = miles / 69.0 + 0.01;
    return records
        .where((r) =>
            (r.lat - lat).abs() <= dLat &&
            EstablishmentsService.miles(lat, lon, r.lat, r.lon) <= miles)
        .toList();
  }

  SwinePermitSummary summarize(double lat, double lon,
      {String? plantParentName, int miles = 75}) {
    final near = this.near(lat, lon, miles);
    final byState = <String, int>{};
    for (final r in near) {
      byState[r.state] = (byState[r.state] ?? 0) + 1;
    }
    final reached = statesWithin(lat, lon, miles)..addAll(byState.keys);
    final sources = reached
        .where(states.containsKey)
        .map((c) => states[c]!)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final unpublished =
        reached.where((c) => !states.containsKey(c)).toList()..sort();
    final lagoonStates = byState.keys
        .where((c) => byState[c]! > 0 && (states[c]?.lagoonData ?? false))
        .toList()
      ..sort();
    final lagoonCount = near.where((r) => r.lagoon == true).length;
    final parent = SwinePermitOwnership.parentForPlant(plantParentName);
    final held = parent == null
        ? const <SwinePermitRecord>[]
        : near
            .where((r) => SwinePermitOwnership.parentForOwner(r.owner) == parent)
            .toList();
    return SwinePermitSummary(
      radiusMiles: miles,
      total: near.length,
      byState: byState,
      lagoonStates: lagoonStates,
      lagoonCount: lagoonCount,
      sources: sources,
      unpublished: unpublished,
      parent: parent,
      parentHoldings: held.length,
      parentStates: held.map((r) => r.state).toSet().toList()..sort(),
    );
  }
}

// ── Download + weekly cache ────────────────────────────────────────────────

class SwinePermitService {
  SwinePermitService._();

  static const url =
      'https://cdn.jsdelivr.net/gh/fcrocker-nyc/fat-android@main/swine-permits/fat_swine_permits.json';
  static const _maxAge = Duration(days: 7);
  static SwinePermitData? _memory;

  /// Cached copy when under a week old; otherwise downloads, falling back to a
  /// stale cached copy. Fail-open: null when nothing is available.
  static Future<SwinePermitData?> load() async {
    if (_memory != null) return _memory;
    File? file;
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}/fat_swine_permits.json');
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
