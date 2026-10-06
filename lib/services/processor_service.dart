import 'dart:convert';
import 'package:http/http.dart' as http;

import 'establishments_service.dart';
import 'fsis_plant_names.dart';

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
      // Bundled FSIS directory fills blank names/city/state during parse.
      await FsisPlantNames.ensureLoaded();
      if (d is! Map) {
        _cache[digits] = null;
        return null;
      }
      final rec = ProcessorRecord.fromJson(Map<String, dynamic>.from(d),
          digits: digits);
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
  final String zip;
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

  /// Full FSIS number from fat/v1/establishments (e.g. "M245C+V245C").
  final String? fullEstNumber;
  /// fat/v1/establishments record_url ("Full FSIS record").
  final String? recordUrl;
  /// Set when the record shown comes from the endpoint's counts (the
  /// digits-keyed website JSON could not be confirmed as this plant).
  final FatEstablishment? endpointPlant;

  ProcessorRecord({
    required this.estNumber,
    required this.estPrefix,
    required this.name,
    this.dba,
    required this.address,
    required this.city,
    required this.state,
    this.zip = '',
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
    this.fullEstNumber,
    this.recordUrl,
    this.endpointPlant,
  });

  /// Number to show on the EST pill: full FSIS number when known.
  String get displayEstNumber => fullEstNumber ?? estNumber;

  /// Same enforcement detail, with the endpoint plant's identity.
  ProcessorRecord withIdentity(FatEstablishment p) => ProcessorRecord(
        estNumber: estNumber,
        estPrefix: estPrefix,
        name: p.name.isNotEmpty ? p.name : name,
        dba: p.dba ?? dba,
        address: p.address ?? address,
        city: p.city ?? city,
        state: p.state ?? state,
        zip: p.zip ?? zip,
        county: county,
        phone: phone,
        grantDate: grantDate,
        primarySpecies: primarySpecies,
        lat: lat,
        lon: lon,
        salmonellaCategory: salmonellaCategory,
        hasRecalls: hasRecalls,
        recallCount: recallCount,
        recallItems: recallItems,
        hasActions: hasActions,
        nrCount: nrCount,
        moiCount: moiCount,
        taskCount: taskCount,
        actionItems: actionItems,
        hasResidues: hasResidues,
        residueCount: residueCount,
        residueItems: residueItems,
        generatedDate: generatedDate,
        fullEstNumber: p.establishmentNumber,
        recordUrl: p.recordUrl,
      );

  /// Identity + endpoint counts for a plant (no digits-keyed detail).
  factory ProcessorRecord.fromEstablishment(FatEstablishment p,
      {String primarySpecies = ''}) {
    final tok = p.numberTokens.isEmpty ? '' : p.numberTokens.first;
    final pre = RegExp(r'^[A-Z]+').firstMatch(tok)?.group(0) ?? '';
    return ProcessorRecord(
      estNumber: p.digits,
      estPrefix: pre,
      name: p.name,
      dba: p.dba,
      address: p.address ?? '',
      city: p.city ?? '',
      state: p.state ?? '',
      zip: p.zip ?? '',
      county: '',
      phone: '',
      grantDate: p.grantDate ?? '',
      primarySpecies: primarySpecies,
      hasRecalls: p.recalls > 0,
      recallCount: p.recalls,
      recallItems: const [],
      hasActions: p.noncomplianceRecords + p.memorandaOfInterview > 0,
      nrCount: p.noncomplianceRecords,
      moiCount: p.memorandaOfInterview,
      taskCount: p.inspectionTasks,
      actionItems: const [],
      hasResidues: p.residueViolations > 0,
      residueCount: p.residueViolations,
      residueItems: const [],
      fullEstNumber: p.establishmentNumber,
      recordUrl: p.recordUrl,
      endpointPlant: p,
    );
  }

  factory ProcessorRecord.fromJson(Map<String, dynamic> j,
      {String? digits}) {
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

    String trimmed(v) => (v ?? '').toString().trim();
    final rawEst = trimmed(est['est_number']);
    final estNumber = rawEst.isNotEmpty ? rawEst : (digits ?? '');
    final estPrefix = trimmed(est['est_prefix']);
    var name = trimmed(est['name']);
    var city = trimmed(est['city']);
    var state = trimmed(est['state']);
    var dba = asStr(trimmed(est['dba']));
    // The website's monthly FSIS update has blanked name/city/state on many
    // records. Fill ONLY the blanks from the bundled FSIS MPI Directory
    // snapshot — never overwrite a non-empty website value.
    if (FsisPlantNames.isBlankName(name) || city.isEmpty || state.isEmpty) {
      final info = FsisPlantNames.lookup(
          prefix: estPrefix.isNotEmpty ? estPrefix : trimmed(j['est_prefix']),
          digits: estNumber);
      if (info != null) {
        if (FsisPlantNames.isBlankName(name) && info.name.isNotEmpty) {
          name = info.name;
        }
        if (city.isEmpty) city = info.city;
        if (state.isEmpty) state = info.state;
        dba ??= info.dba;
      }
    }

    return ProcessorRecord(
      estNumber: estNumber,
      estPrefix: estPrefix,
      name: name,
      dba: dba,
      address: (est['address'] ?? '').toString().trim(),
      city: city,
      state: state,
      zip: trimmed(est['zip']),
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
      (endpointPlant?.hasRecords ?? false) ||
      (salmonellaCategory != null && salmonellaCategory != 'null');

  /// Street, city, state, zip — non-empty parts only.
  String get fullAddress => [address, city, state, zip]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  /// The legal plant name only (website → bundled FSIS directory), without
  /// the DBA fallback — for ownership matching that treats DBAs separately.
  String? get directoryName {
    if (!FsisPlantNames.isBlankName(name)) return name.trim();
    final info = FsisPlantNames.lookup(prefix: estPrefix, digits: estNumber);
    if (info != null && info.name.isNotEmpty) return info.name;
    return null;
  }

  /// The plant name to show: website name → bundled FSIS directory name →
  /// DBA → null. Mirrors iOS ProcessorData.resolvedName.
  String? get resolvedName {
    final n = directoryName;
    if (n != null) return n;
    final d = dba?.trim();
    return (d == null || d.isEmpty) ? null : d;
  }

  /// [resolvedName], or the neutral "Plant name not on file" placeholder.
  String get displayName => resolvedName ?? FsisPlantNames.notOnFileText;
}
