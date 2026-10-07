import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../models/fat_models.dart';

import 'processor_service.dart';

// Collision-safe FSIS establishment lookup — fat/v1/establishments/<q>.
//
// The per-plant JSON files under /wp-content/uploads/fsis/inspection-results/
// are keyed by bare digits, but FSIS has 465 establishment numbers shared by
// more than one plant (e.g. 245 = M245J Hillsdale IL, M245C+V245C Dakota City
// NE, M245E Amarillo TX). This endpoint returns EVERY plant behind a number
// (or a plant-name search) so the app never presents one plant's identity or
// enforcement record for another's package.
// Mirrors iOS FATAppMVP2/EstablishmentsService.swift.

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _dbl(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

class FatEstablishmentRecall {
  final String? recallNumber;
  final String? title;
  final String? date;
  final String? recallClass;
  final String? type;
  final String? reason;
  const FatEstablishmentRecall(
      {this.recallNumber,
      this.title,
      this.date,
      this.recallClass,
      this.type,
      this.reason});
}

class FatSalmonellaProduct {
  final String product;
  final String? category; // "1"–"3"; "0" = not categorized (FSIS lists NA)
  const FatSalmonellaProduct(this.product, this.category);
}

class FatEstablishment {
  final String establishmentId;
  final String establishmentNumber; // full FSIS number, e.g. "M245C+V245C"
  final String name;
  final String? dba;
  final String? address;
  final String? city;
  final String? state;
  final String? zip;
  final String? size;
  final String? grantDate;
  final String? county;
  final double? latitude;
  final double? longitude;
  final String? activities;
  final String? parentCompany;
  final int recalls;
  final int publicHealthAlerts;
  final FatEstablishmentRecall? latestRecall;
  final int inspectionTasks;
  final int noncomplianceRecords;
  final int memorandaOfInterview;
  final int residueViolations;
  final List<FatSalmonellaProduct>? salmonella;
  final String? recordUrl;

  const FatEstablishment({
    this.establishmentId = '',
    required this.establishmentNumber,
    this.name = '',
    this.dba,
    this.address,
    this.city,
    this.state,
    this.zip,
    this.size,
    this.grantDate,
    this.county,
    this.latitude,
    this.longitude,
    this.activities,
    this.parentCompany,
    this.recalls = 0,
    this.publicHealthAlerts = 0,
    this.latestRecall,
    this.inspectionTasks = 0,
    this.noncomplianceRecords = 0,
    this.memorandaOfInterview = 0,
    this.residueViolations = 0,
    this.salmonella,
    this.recordUrl,
  });

  /// Null when the record has no establishment number.
  static FatEstablishment? fromJson(Map e) {
    final number = _str(e['establishment_number']);
    if (number == null) return null;
    FatEstablishmentRecall? recall;
    final r = e['latest_recall'];
    if (r is Map) {
      recall = FatEstablishmentRecall(
        recallNumber: _str(r['recall_number']),
        title: _str(r['title']),
        date: _str(r['date']),
        recallClass: _str(r['class']),
        type: _str(r['type']),
        reason: _str(r['reason']),
      );
    }
    List<FatSalmonellaProduct>? sal;
    final s = e['salmonella'];
    if (s is Map && s['products'] is List) {
      sal = [
        for (final p in s['products'] as List)
          if (p is Map && p['product'] != null)
            FatSalmonellaProduct('${p['product']}', _str(p['category'])),
      ];
    }
    return FatEstablishment(
      establishmentId: _str(e['establishment_id']) ?? '',
      establishmentNumber: number,
      name: _str(e['name']) ?? '',
      dba: _str(e['dba']),
      address: _str(e['address']),
      city: _str(e['city']),
      state: _str(e['state']),
      zip: _str(e['zip']),
      size: _str(e['size']),
      grantDate: _str(e['grant_date']),
      county: _str(e['county']),
      latitude: _dbl(e['latitude']),
      longitude: _dbl(e['longitude']),
      activities: _str(e['activities']),
      parentCompany: _str(e['parent_company']),
      recalls: _int(e['recalls']),
      publicHealthAlerts: _int(e['public_health_alerts']),
      latestRecall: recall,
      inspectionTasks: _int(e['inspection_tasks']),
      noncomplianceRecords: _int(e['noncompliance_records']),
      memorandaOfInterview: _int(e['memoranda_of_interview']),
      residueViolations: _int(e['residue_violations']),
      salmonella: sal,
      recordUrl: _str(e['record_url']),
    );
  }

  /// "Hillsdale, IL"
  String get cityState =>
      [city, state].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  String get fullAddress => [address, city, state, zip]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(', ');

  List<String> get activityList => (activities ?? '')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Number tokens on the mark, e.g. "M245C+V245C" → ["M245C", "V245C"].
  List<String> get numberTokens => establishmentNumber
      .toUpperCase()
      .split(RegExp(r'[+,/ ]'))
      .map((t) => t.replaceAll('-', ''))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Digits of the first number token ("M245C+V245C" → "245").
  String get digits => EstablishmentsService.core(
          numberTokens.isEmpty ? establishmentNumber : numberTokens.first)
      .replaceAll(RegExp(r'[^0-9]'), '');

  /// True when any FSIS record count is non-zero (inspection tasks alone are
  /// routine, not a record).
  bool get hasRecords =>
      recalls > 0 ||
      publicHealthAlerts > 0 ||
      noncomplianceRecords > 0 ||
      memorandaOfInterview > 0 ||
      residueViolations > 0;

  /// Human-readable salmonella category line; null when FSIS has no data.
  String? get salmonellaLine {
    final p = salmonella;
    if (p == null || p.isEmpty) return null;
    return p.map((x) {
      final c = (x.category ?? '').trim();
      if (c.isEmpty || c == '0') {
        return '${x.product}: not categorized (FSIS lists NA)';
      }
      return '${x.product}: Category $c';
    }).join('; ');
  }

  /// "2015-06-03 · Class I · Tyson Fresh Meats Recalls Beef Products …"
  String? get latestRecallLine {
    final r = latestRecall;
    if (r == null) return null;
    final parts = [r.date, r.recallClass, r.title ?? r.reason]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class EstablishmentsResponse {
  final String query;
  final String mode; // "number" | "name"
  final List<FatEstablishment> establishments;
  final String? note; // non-null (non-empty) when the number is shared
  const EstablishmentsResponse(
      {required this.query,
      required this.mode,
      required this.establishments,
      this.note});
  int get count => establishments.length;
}

enum ResolutionKind { single, ambiguous, notFound }

/// How a scanned label's EST resolves against the endpoint.
class EstablishmentResolution {
  final ResolutionKind kind;
  final List<FatEstablishment> plants; // 1 for single, all for ambiguous
  const EstablishmentResolution(this.kind, this.plants);
  FatEstablishment? get plant =>
      kind == ResolutionKind.single ? plants.first : null;
}

/// Scan-results outcome: the processor record to show (or null) and the
/// plants that share the number when the label didn't say which.
class ScanOutcome {
  final ProcessorRecord? record;
  final List<FatEstablishment> shared;
  const ScanOutcome(this.record, this.shared);
}

class EstablishmentsService {
  static const base =
      'https://farmanimaltransparency.com/wp-json/fat/v1/establishments';

  static final Map<String, EstablishmentsResponse> _cache = {};

  /// Test hook: replace the HTTP client (e.g. a failing one for offline tests).
  static http.Client? clientOverride;

  /// Look up a number (245, 245C, M245C, P-39928) or part of a plant name.
  /// Returns null on any network / HTTP / parse failure so callers fall back.
  static Future<EstablishmentsResponse?> lookup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final key = q.toUpperCase();
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final uri = Uri.parse('$base/${Uri.encodeComponent(q)}');
      final client = clientOverride;
      final r = await (client != null ? client.get(uri) : http.get(uri))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode < 200 || r.statusCode > 299) return null;
      final parsed = decode(r.body);
      if (parsed != null) _cache[key] = parsed;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static void clearCache() => _cache.clear();

  // ── Pure helpers (unit-tested) ───────────────────────────────────────

  static EstablishmentsResponse? decode(String body) {
    try {
      final obj = jsonDecode(body);
      if (obj is! Map || obj['establishments'] is! List) return null;
      final note = _str(obj['note']);
      return EstablishmentsResponse(
        query: _str(obj['query']) ?? '',
        mode: _str(obj['mode']) ?? 'number',
        establishments: [
          for (final e in obj['establishments'] as List)
            if (e is Map) FatEstablishment.fromJson(e),
        ].whereType<FatEstablishment>().toList(),
        note: note,
      );
    } catch (_) {
      return null;
    }
  }

  /// Normalise a label mark: "EST. 245C" → "245C", "P-39928" → "P39928".
  static String normalize(String raw) {
    var s = raw.toUpperCase();
    for (final junk in ['USDA', 'EST.', 'EST', '#']) {
      s = s.replaceAll(junk, '');
    }
    return s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Strip leading FSIS type letters (M/P/V/I…): "M245C" → "245C".
  static String core(String token) => token.replaceFirst(RegExp(r'^[A-Za-z]+'), '');

  /// Resolve a scanned EST against an endpoint response.
  /// - exactly one plant returned → that plant;
  /// - else exactly one plant whose full number matches the scanned mark
  ///   including its letters ("245C" → M245C+V245C, "P39928" → M40310+P39928,
  ///   bare "4033" → M4033) → that plant;
  /// - else several plants share the number → ambiguous.
  static EstablishmentResolution resolve(
      String scanned, EstablishmentsResponse response) {
    final plants = response.establishments;
    if (response.mode != 'number' || plants.isEmpty) {
      return const EstablishmentResolution(ResolutionKind.notFound, []);
    }
    if (plants.length == 1) {
      return EstablishmentResolution(ResolutionKind.single, plants);
    }
    final mark = normalize(scanned);
    if (mark.isEmpty) {
      return EstablishmentResolution(ResolutionKind.ambiguous, plants);
    }
    final markHasPrefix = RegExp(r'^[A-Z]').hasMatch(mark);
    final exact = plants
        .where((p) => p.numberTokens
            .any((t) => t == mark || (!markHasPrefix && core(t) == mark)))
        .toList();
    if (exact.length == 1) {
      return EstablishmentResolution(ResolutionKind.single, exact);
    }
    return EstablishmentResolution(ResolutionKind.ambiguous, plants);
  }

  /// The fuller mark printed on the label for a detected EST — keeps a poultry
  /// "P-" prefix or one-letter suffix ("EST. 245C" → "245C", "P-39928" →
  /// "P39928"). Falls back to the detected EST.
  static String labelMark(String est, String text) {
    final d = est.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return est;
    final re = RegExp(
        r'(?<![A-Z0-9])(EST\.?\s{0,2}|P\s{0,2}-?\s{0,2})?' + d + r'([A-Z])?(?![A-Z0-9])');
    for (final m in re.allMatches(text.toUpperCase())) {
      final prefix = m.group(1) ?? '';
      final suffix = m.group(2) ?? '';
      if (prefix.startsWith('P')) return 'P$d$suffix';
      if (prefix.startsWith('EST')) return '$d$suffix';
    }
    // The detected EST may already carry the suffix (Android keeps it).
    return normalize(est);
  }

  /// Does the digits-keyed website JSON describe the same plant as [plant]?
  /// Type letter (est_prefix) must not conflict; then the street number must
  /// match when both are known, else city + state must match.
  static bool agrees(ProcessorRecord pd, FatEstablishment plant) {
    final digits = pd.estNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final preMatch = RegExp(r'[A-Za-z]').firstMatch(pd.estPrefix);
    if (preMatch != null) {
      final pre = preMatch.group(0)!.toUpperCase();
      // Conflict only when tokens carry these digits and none has this letter
      // (M4033+P4033 agrees with either "M" or "P").
      final same = plant.numberTokens
          .where((t) => core(t).replaceAll(RegExp(r'[^0-9]'), '') == digits)
          .toList();
      if (same.isNotEmpty && !same.any((t) => t.startsWith(pre))) return false;
    }
    String? streetNo(String? s) {
      final m = RegExp(r'^\d+').firstMatch((s ?? '').trim());
      return m?.group(0);
    }

    bool? same(String? a, String? b) {
      final x = (a ?? '').trim().toLowerCase();
      final y = (b ?? '').trim().toLowerCase();
      if (x.isEmpty || y.isEmpty) return null;
      return x == y;
    }

    final a = streetNo(pd.address), b = streetNo(plant.address);
    if (a != null && b != null) {
      return a == b && (same(pd.city, plant.city) ?? true);
    }
    final c = same(pd.city, plant.city);
    if (c != null) return c && (same(pd.state, plant.state) ?? true);
    return false;
  }

  /// Final record for a single resolved plant: the endpoint's identity; the
  /// website JSON's per-plant enforcement detail only when it agrees with that
  /// plant, otherwise the endpoint's counts.
  static ProcessorRecord merge(ProcessorRecord? website, FatEstablishment plant) {
    if (website != null && agrees(website, plant)) {
      return website.withIdentity(plant);
    }
    return ProcessorRecord.fromEstablishment(plant,
        primarySpecies: website?.primarySpecies ?? '');
  }

  /// Scan-results outcome. `response == null` (offline / endpoint error) or a
  /// number the endpoint doesn't know → the digits-keyed website record.
  static ScanOutcome scanOutcome(
      ProcessorRecord? website, String mark, EstablishmentsResponse? response) {
    if (response == null) return ScanOutcome(website, const []);
    final r = resolve(mark, response);
    switch (r.kind) {
      case ResolutionKind.single:
        return ScanOutcome(merge(website, r.plant!), const []);
      case ResolutionKind.ambiguous:
        return ScanOutcome(null, r.plants);
      case ResolutionKind.notFound:
        return ScanOutcome(website, const []);
    }
  }

  // ── Shared number — owner + location helpers (unit-tested) ──────────

  static const noParentMappingText = 'no parent mapping on file';

  static String sharedOwnerNote(int n) =>
      'This number belongs to $n FSIS plants with different owners — match the city on the package\'s USDA mark to know which.';

  /// Who/Owner for a shared number the label didn't resolve, when the
  /// candidate plants map to different parent companies: Partial, value
  /// "One of: Tyson Foods; JBS" (+ "no parent mapping on file" when any
  /// candidate lacks one). Null when every candidate shares one parent (the
  /// single-parent path applies) or none has a mapping.
  static FATCategoryResult? sharedOwnerResult(List<FatEstablishment> plants) {
    if (plants.length < 2) return null;
    final names = <String>[];
    final seen = <String>{};
    var unmapped = false;
    for (final p in plants) {
      final parent = (p.parentCompany ?? '').trim();
      if (parent.isEmpty) {
        unmapped = true;
        continue;
      }
      if (seen.add(parent.toLowerCase())) names.add(parent);
    }
    if (names.isEmpty || names.length + (unmapped ? 1 : 0) < 2) return null;
    if (unmapped) names.add(noParentMappingText);
    return FATCategoryResult(
      status: DisclosureStatus.partial,
      value: 'One of: ${names.join('; ')}',
      credibility: ClaimCredibility.usdaApproved,
      credibilityNote: sharedOwnerNote(plants.length),
    );
  }

  /// Apply [sharedOwnerResult] to Who/Owner only when the label left it
  /// Missing. Partial doesn't count toward the known count.
  static bool applySharedOwner(
      Map<FATCategory, FATCategoryResult> categories,
      List<FatEstablishment> plants) {
    final status = categories[FATCategory.who]?.status ?? DisclosureStatus.missing;
    if (status != DisclosureStatus.missing) return false;
    final r = sharedOwnerResult(plants);
    if (r == null) return false;
    categories[FATCategory.who] = r;
    return true;
  }

  /// Great-circle distance in miles.
  static double miles(double lat1, double lon1, double lat2, double lon2) {
    const r = 3958.8;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Where to centre the nearby-CAFO lookup. A resolved plant → its
  /// coordinates (endpoint first, website geolocation when that record is
  /// confirmed as this plant). A shared number → no location is guessed,
  /// unless every candidate has coordinates within 10 miles of each other,
  /// then the first candidate's.
  static (double, double)? proximityPoint(
      ProcessorRecord? record, List<FatEstablishment> shared) {
    if (shared.isNotEmpty) {
      final pts = <(double, double)>[];
      for (final p in shared) {
        final la = p.latitude, lo = p.longitude;
        if (la == null || lo == null) return null;
        pts.add((la, lo));
      }
      for (var i = 0; i < pts.length; i++) {
        for (var j = i + 1; j < pts.length; j++) {
          if (miles(pts[i].$1, pts[i].$2, pts[j].$1, pts[j].$2) > 10) {
            return null;
          }
        }
      }
      return pts.first;
    }
    final la = record?.lat, lo = record?.lon;
    if (la == null || lo == null) return null;
    return (la, lo);
  }

  /// Scan-results headline when several plants share the number.
  static String sharedHeadline(int n) =>
      'This number belongs to $n FSIS plants — match the city on the package\'s USDA mark';
}
