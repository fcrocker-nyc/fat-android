import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches a processor's FSIS public enforcement record from the FAT backend —
/// the SAME per-establishment JSON the iOS app reads
/// (`/wp-content/uploads/fsis/inspection-results/{digits}.json`, v2.0 schema).
///
/// Backend-fetch (not bundled): the file is regenerated monthly by the FAT FSIS
/// pipeline, so the app always shows current data and stays small. Fail-open:
/// any network/parse/404 error returns null and the Results screen simply omits
/// the enforcement card.
class ProcessorService {
  static const _base =
      'https://farmanimaltransparency.com/wp-content/uploads/fsis/inspection-results';

  // Small in-session cache so History re-opens don't refetch.
  static final Map<String, ProcessorRecord?> _cache = {};

  static Future<ProcessorRecord?> fetch(String? est) async {
    if (est == null) return null;
    final digits = est.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (_cache.containsKey(digits)) return _cache[digits];
    try {
      final r = await http
          .get(Uri.parse('$_base/$digits.json'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        _cache[digits] = null;
        return null;
      }
      final d = jsonDecode(r.body);
      if (d is! Map) {
        _cache[digits] = null;
        return null;
      }
      final rec = ProcessorRecord.fromJson(Map<String, dynamic>.from(d));
      _cache[digits] = rec;
      return rec;
    } catch (_) {
      _cache[digits] = null;
      return null;
    }
  }
}

/// One administrative-action / humane-handling / residue / recall line item.
class EnforcementItem {
  final String type; // NR, MOI, recall class, etc.
  final String number;
  final String taskName; // e.g. "Livestock Humane Handling"
  final String regs; // cited regulation, e.g. "313.1"
  final String description;
  final String category; // "LHH" = Livestock Humane Handling, etc.
  final String product; // recalls: product description
  final String classification; // recalls: Class I/II/III

  EnforcementItem({
    this.type = '',
    this.number = '',
    this.taskName = '',
    this.regs = '',
    this.description = '',
    this.category = '',
    this.product = '',
    this.classification = '',
  });

  factory EnforcementItem.fromJson(Map j) => EnforcementItem(
        type: (j['type'] ?? '').toString(),
        number: (j['number'] ?? j['recall_number'] ?? '').toString(),
        taskName: (j['task_name'] ?? '').toString(),
        regs: (j['regs'] ?? '').toString(),
        description: (j['description'] ?? j['summary'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        product: (j['product'] ?? j['product_description'] ?? '').toString(),
        classification: (j['classification'] ?? j['recall_class'] ?? '').toString(),
      );
}

/// Parsed FSIS record for one establishment (v2.0 nested schema).
class ProcessorRecord {
  final String estNumber;
  final String estPrefix;
  final String name;
  final String? dba;
  final String address;
  final String city;
  final String state;
  final String county;
  final String phone;
  final String grantDate;
  final String primarySpecies;
  final double? lat;
  final double? lon;

  final String? salmonellaCategory;

  final bool hasRecalls;
  final int recallCount;
  final List<EnforcementItem> recallItems;

  final bool hasActions;
  final int nrCount;
  final int moiCount;
  final int taskCount;
  final List<EnforcementItem> actionItems;

  final bool hasResidues;
  final int residueCount;
  final List<EnforcementItem> residueItems;

  final String? generatedDate;

  ProcessorRecord({
    required this.estNumber,
    required this.estPrefix,
    required this.name,
    this.dba,
    required this.address,
    required this.city,
    required this.state,
    required this.county,
    required this.phone,
    required this.grantDate,
    required this.primarySpecies,
    this.lat,
    this.lon,
    this.salmonellaCategory,
    required this.hasRecalls,
    required this.recallCount,
    required this.recallItems,
    required this.hasActions,
    required this.nrCount,
    required this.moiCount,
    required this.taskCount,
    required this.actionItems,
    required this.hasResidues,
    required this.residueCount,
    required this.residueItems,
    this.generatedDate,
  });

  factory ProcessorRecord.fromJson(Map<String, dynamic> j) {
    final est = Map<String, dynamic>.from(j['establishment'] ?? {});
    final species = Map<String, dynamic>.from(j['species'] ?? {});
    final pathogen = Map<String, dynamic>.from(j['pathogen_testing'] ?? {});
    final enf = Map<String, dynamic>.from(j['enforcement'] ?? {});
    final meta = Map<String, dynamic>.from(j['meta'] ?? {});

    List<EnforcementItem> items(Map? block) => block == null
        ? const []
        : ((block['items'] as List?) ?? const [])
            .map((e) => EnforcementItem.fromJson(Map.from(e as Map)))
            .toList();

    final recalls = Map<String, dynamic>.from(enf['recalls'] ?? {});
    final actions = Map<String, dynamic>.from(enf['administrative_actions'] ?? {});
    final residues = Map<String, dynamic>.from(enf['residues'] ?? {});

    int asInt(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    String? asStr(v) => (v == null || '$v'.isEmpty) ? null : '$v';
    double? asDbl(v) => v is num ? v.toDouble() : double.tryParse('$v');

    final geo = Map<String, dynamic>.from(est['geolocation'] ?? {});

    return ProcessorRecord(
      estNumber: (est['est_number'] ?? '').toString(),
      estPrefix: (est['est_prefix'] ?? '').toString(),
      name: (est['name'] ?? '').toString(),
      dba: asStr(est['dba']),
      address: (est['address'] ?? '').toString().trim(),
      city: (est['city'] ?? '').toString(),
      state: (est['state'] ?? '').toString(),
      county: (est['county'] ?? '').toString(),
      phone: (est['phone'] ?? '').toString(),
      grantDate: (est['grant_date'] ?? '').toString(),
      primarySpecies: (species['primary_species'] ?? '').toString(),
      lat: asDbl(geo['lat']),
      lon: asDbl(geo['lon']),
      salmonellaCategory: asStr(pathogen['salmonella_category']),
      hasRecalls: recalls['has_recalls'] == true,
      recallCount: asInt(recalls['count']),
      recallItems: items(recalls),
      hasActions: actions['has_actions'] == true,
      nrCount: asInt(actions['nr_count']),
      moiCount: asInt(actions['moi_count']),
      taskCount: asInt(actions['task_count']),
      actionItems: items(actions),
      hasResidues: residues['has_residues'] == true,
      residueCount: asInt(residues['count']),
      residueItems: items(residues),
      generatedDate: asStr(meta['generated_date']),
    );
  }

  /// Humane-handling noncompliance records (LHH task category).
  List<EnforcementItem> get humaneHandling =>
      actionItems.where((i) => i.category.toUpperCase() == 'LHH').toList();

  /// Any FSIS food-safety concern on record (OSHA/EPA are handled separately).
  bool get hasAnyConcern =>
      hasRecalls ||
      humaneHandling.isNotEmpty ||
      hasResidues ||
      (salmonellaCategory != null && salmonellaCategory != 'null');

  String get displayName =>
      name.isNotEmpty ? name : (dba ?? 'Establishment $estNumber');
}
