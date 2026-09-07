import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/pork_owner_database.dart';

// Dart port of BigFourOwnership.swift + ParentCompanyService.swift.
//
// WHY THIS EXISTS
// ---------------
// A scan that detected an EST number stopped at the operating company, so the
// evaluation reported the owner of EST 245 as "IBP, inc." — retired in 2001 —
// and the owner of EST 969 as "Swift Beef Company" with no mention of JBS.
//
// Resolution order:
//   1. farmanimaltransparency.com's parent-company database (16 parents over
//      330 establishments; authoritative, correctable without an app release,
//      and it returns every sibling plant under the same parent).
//   2. An on-device corporate-name crosswalk over the FSIS record's own name
//      and DBA fields, for when that database has no record or there is no
//      network. Parent patterns outrank subsidiary patterns, so the answer is
//      the top of the tree with the subsidiary shown as the path to it.
//   3. Nothing. The card is omitted rather than guessing.

// ── Parent groups ───────────────────────────────────────────────────────────

enum ParentGroup { jbs, tyson, cargill, nationalBeef, smithfield }

extension ParentGroupInfo on ParentGroup {
  String get ultimateParent {
    switch (this) {
      case ParentGroup.jbs:
        return 'JBS S.A.';
      case ParentGroup.tyson:
        return 'Tyson Foods, Inc.';
      case ParentGroup.cargill:
        return 'Cargill, Incorporated';
      case ParentGroup.nationalBeef:
        return 'Marfrig Global Foods S.A.';
      case ParentGroup.smithfield:
        return 'WH Group Limited';
    }
  }

  String get country {
    switch (this) {
      case ParentGroup.jbs:
      case ParentGroup.nationalBeef:
        return 'Brazil';
      case ParentGroup.tyson:
      case ParentGroup.cargill:
        return 'United States';
      case ParentGroup.smithfield:
        return 'China';
    }
  }

  String get headquarters {
    switch (this) {
      case ParentGroup.jbs:
        return 'São Paulo, Brazil';
      case ParentGroup.tyson:
        return 'Springdale, Arkansas';
      case ParentGroup.cargill:
        return 'Wayzata, Minnesota';
      case ParentGroup.nationalBeef:
        return 'São Paulo, Brazil';
      case ParentGroup.smithfield:
        return 'Hong Kong, China';
    }
  }

  String get controlNote {
    switch (this) {
      case ParentGroup.jbs:
        return "JBS S.A. is the world's largest meat processor, controlled by the Batista family through J&F Investimentos. Its US beef business traces to the 2007 acquisition of Swift & Company and the 2009 acquisition of Smithfield Beef Group, which included Packerland.";
      case ParentGroup.tyson:
        return 'Tyson Foods, Inc. (NYSE: TSN) is publicly traded but family-controlled through a dual-class share structure that gives the Tyson family the large majority of voting power. Tyson Fresh Meats is the former IBP, inc., acquired in 2001.';
      case ParentGroup.cargill:
        return 'Cargill, Incorporated is one of the largest privately held companies in the United States, owned by the Cargill and MacMillan families. Its beef business operates as Cargill Meat Solutions, the former Excel Corporation.';
      case ParentGroup.nationalBeef:
        return 'National Beef Packing Company is majority-owned by Marfrig Global Foods S.A. of Brazil, which took control in 2018 and raised its stake to 81.7%. National Beef acquired Iowa Premium (Tama, Iowa) in 2019.';
      case ParentGroup.smithfield:
        return 'Smithfield Foods has been owned by WH Group Limited of Hong Kong since 2013 — the largest Chinese acquisition of a US company at the time. Smithfield operates John Morrell, Farmland, Gwaltney, Armour-Eckrich and other brands.';
    }
  }

  String? get profileURL {
    switch (this) {
      case ParentGroup.jbs:
        return 'https://jbs.com.br';
      case ParentGroup.tyson:
        return 'https://www.tysonfoods.com';
      case ParentGroup.cargill:
        return 'https://www.cargill.com';
      case ParentGroup.nationalBeef:
        return 'https://www.marfrig.com.br';
      case ParentGroup.smithfield:
        return 'https://www.wh-group.com';
    }
  }

  bool get isForeignOwned => country != 'United States';

  String? ownerId(MeatSpecies species) {
    switch (this) {
      case ParentGroup.jbs:
        if (species == MeatSpecies.beef) return 'jbs_beef';
        if (species == MeatSpecies.pork) return 'jbs';
        if (species == MeatSpecies.chicken) return 'pilgrims';
        return null;
      case ParentGroup.tyson:
        if (species == MeatSpecies.beef) return 'tyson_beef';
        if (species == MeatSpecies.pork) return 'tyson';
        if (species == MeatSpecies.chicken) return 'tyson_chicken';
        return null;
      case ParentGroup.cargill:
        if (species == MeatSpecies.beef) return 'cargill_beef';
        if (species == MeatSpecies.turkey) return 'cargill_turkey';
        return null;
      case ParentGroup.nationalBeef:
        return species == MeatSpecies.beef ? 'national_beef' : null;
      case ParentGroup.smithfield:
        return species == MeatSpecies.pork ? 'whgroup' : null;
    }
  }

  PorkCorporateOwner? owner(MeatSpecies species) {
    final id = ownerId(species);
    if (id == null) return null;
    for (final o in PorkOwnerDatabase.allOwners) {
      if (o.id == id) return o;
    }
    return null;
  }
}

// ── Crosswalk ───────────────────────────────────────────────────────────────

enum PatternTier { subsidiary, parent }

class ParentNamePattern {
  final String needle; // lowercased, matched as a substring
  final ParentGroup group;
  final PatternTier tier;
  const ParentNamePattern(this.needle, this.group, this.tier);
}

// ── Related establishment (from the site database) ──────────────────────────

class RelatedEstablishment {
  final String estNumber;
  final String name;
  final String city;
  final String state;
  const RelatedEstablishment(this.estNumber, this.name, this.city, this.state);

  String get location => [city, state].where((s) => s.isNotEmpty).join(', ');

  factory RelatedEstablishment.fromJson(Map<String, dynamic> j) =>
      RelatedEstablishment(
        (j['est_number'] ?? '').toString(),
        (j['name'] ?? '').toString(),
        (j['city'] ?? '').toString(),
        (j['state'] ?? '').toString(),
      );
}

// ── Display model ───────────────────────────────────────────────────────────

enum OwnershipSource { siteDatabase, localCrosswalk }

extension OwnershipSourceLabel on OwnershipSource {
  String get label => this == OwnershipSource.siteDatabase
      ? 'FAT parent-company database'
      : 'on-device corporate-name crosswalk';
}

class OwnershipDisclosure {
  final String parentName;
  final ParentGroup? group;
  final String? operatingCompany;
  final String establishmentNumber;
  final List<String> disclosedEntities;
  final String basis;
  final OwnershipSource source;
  final List<RelatedEstablishment> siblings;
  final int? totalRelated;
  final PorkCorporateOwner? owner;
  final MeatSpecies species;

  const OwnershipDisclosure({
    required this.parentName,
    required this.group,
    required this.operatingCompany,
    required this.establishmentNumber,
    required this.disclosedEntities,
    required this.basis,
    required this.source,
    required this.siblings,
    required this.totalRelated,
    required this.owner,
    required this.species,
  });

  String? get country => group?.country;
  String? get headquarters => group?.headquarters;
  String? get controlNote => group?.controlNote;
  String? get profileURL => group?.profileURL;
  bool get isForeignOwned => group?.isForeignOwned ?? false;

  List<String> get ownershipChain {
    final chain = <String>['USDA EST. $establishmentNumber'];
    final op = operatingCompany;
    if (op != null &&
        op.isNotEmpty &&
        op.toLowerCase() != parentName.toLowerCase()) {
      chain.add(op);
    }
    final hq = headquarters;
    chain.add(hq == null ? parentName : '$parentName — $hq');
    return chain;
  }

  String get shareableText {
    final b = StringBuffer('CORPORATE OWNERSHIP:\n');
    b.write('Ultimate parent: $parentName');
    if (headquarters != null) b.write(' (${headquarters!})');
    b.write('\n');
    if (operatingCompany != null && operatingCompany!.isNotEmpty) {
      b.write('Operating company: ${operatingCompany!}\n');
    }
    if (isForeignOwned && country != null) {
      b.write('Foreign-owned: ultimately controlled from ${country!}.\n');
    }
    if (totalRelated != null && totalRelated! > 1) {
      b.write(
          'This parent operates ${totalRelated!} USDA-inspected establishments.\n');
    }
    if (controlNote != null) b.write('${controlNote!}\n');
    b.write('Source: ${source.label}. $basis\n');
    return b.toString();
  }
}

// ── Resolver ────────────────────────────────────────────────────────────────

class BigFourOwnership {
  BigFourOwnership._();

  /// Needles are deliberately specific. Bare "swift" would match "Swift County
  /// Locker"; bare "ibp" would match inside unrelated words.
  static const List<ParentNamePattern> patterns = [
    // JBS
    ParentNamePattern('jbs usa food company', ParentGroup.jbs, PatternTier.parent),
    ParentNamePattern('jbs usa holdings', ParentGroup.jbs, PatternTier.parent),
    ParentNamePattern('jbs usa', ParentGroup.jbs, PatternTier.parent),
    ParentNamePattern('jbs s.a', ParentGroup.jbs, PatternTier.parent),
    ParentNamePattern('jbs ', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('swift beef', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('swift pork', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('swift prepared', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('swift & company', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('swift and company', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('packerland', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern("pilgrim's pride", ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('pilgrims pride', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('plumrose', ParentGroup.jbs, PatternTier.subsidiary),
    ParentNamePattern('empire kosher', ParentGroup.jbs, PatternTier.subsidiary),
    // Tyson
    ParentNamePattern('tyson foods', ParentGroup.tyson, PatternTier.parent),
    ParentNamePattern('tyson fresh meats', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('tyson prepared', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('tyson ', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('ibp, inc', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('ibp inc', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('iowa beef processors', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('hillshire', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('advancepierre', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('advance pierre', ParentGroup.tyson, PatternTier.subsidiary),
    ParentNamePattern('keystone foods', ParentGroup.tyson, PatternTier.subsidiary),
    // Cargill
    ParentNamePattern('cargill, incorporated', ParentGroup.cargill, PatternTier.parent),
    ParentNamePattern('cargill inc', ParentGroup.cargill, PatternTier.parent),
    ParentNamePattern('cargill meat solutions', ParentGroup.cargill, PatternTier.subsidiary),
    ParentNamePattern('cargill regional beef', ParentGroup.cargill, PatternTier.subsidiary),
    ParentNamePattern('cargill protein', ParentGroup.cargill, PatternTier.subsidiary),
    ParentNamePattern('cargill', ParentGroup.cargill, PatternTier.subsidiary),
    ParentNamePattern('excel corporation', ParentGroup.cargill, PatternTier.subsidiary),
    // National Beef / Marfrig
    ParentNamePattern('marfrig', ParentGroup.nationalBeef, PatternTier.parent),
    ParentNamePattern('national beef', ParentGroup.nationalBeef, PatternTier.subsidiary),
    ParentNamePattern('iowa premium', ParentGroup.nationalBeef, PatternTier.subsidiary),
    ParentNamePattern('kansas city steak', ParentGroup.nationalBeef, PatternTier.subsidiary),
    // Smithfield / WH Group
    ParentNamePattern('wh group', ParentGroup.smithfield, PatternTier.parent),
    ParentNamePattern('smithfield', ParentGroup.smithfield, PatternTier.subsidiary),
    ParentNamePattern('john morrell', ParentGroup.smithfield, PatternTier.subsidiary),
    ParentNamePattern('farmland foods', ParentGroup.smithfield, PatternTier.subsidiary),
    ParentNamePattern('gwaltney', ParentGroup.smithfield, PatternTier.subsidiary),
    ParentNamePattern('armour-eckrich', ParentGroup.smithfield, PatternTier.subsidiary),
    ParentNamePattern('patrick cudahy', ParentGroup.smithfield, PatternTier.subsidiary),
  ];

  /// Map a parent name as the site database spells it onto a group, so an API
  /// result still carries country, headquarters and the control note. Parents
  /// the crosswalk does not cover return null, and the card then shows the
  /// parent name alone rather than asserting details we do not have.
  static ParentGroup? groupForParentName(String name) {
    final n = name.toLowerCase();
    if (n.contains('jbs') || n.contains('pilgrim')) return ParentGroup.jbs;
    if (n.contains('tyson')) return ParentGroup.tyson;
    if (n.contains('cargill')) return ParentGroup.cargill;
    if (n.contains('national beef') || n.contains('marfrig')) {
      return ParentGroup.nationalBeef;
    }
    if (n.contains('smithfield') || n.contains('wh group')) {
      return ParentGroup.smithfield;
    }
    return null;
  }

  /// On-device fallback: resolve from the FSIS record's own name + DBA fields.
  static OwnershipDisclosure? resolveLocal({
    required String establishmentNumber,
    required String name,
    required String? dba,
    required MeatSpecies species,
  }) {
    final trimmed = name.trim();
    final dbaEntries = (dba ?? '')
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final candidates = <MapEntry<String, bool>>[
      if (trimmed.isNotEmpty) MapEntry(trimmed, false),
      ...dbaEntries.map((d) => MapEntry(d, true)),
    ];
    if (candidates.isEmpty) return null;

    MapEntry<String, bool>? bestCandidate;
    ParentNamePattern? bestPattern;
    for (final c in candidates) {
      final haystack = c.key.toLowerCase();
      for (final p in patterns) {
        if (!haystack.contains(p.needle)) continue;
        if (bestPattern == null ||
            p.tier.index > bestPattern.tier.index) {
          bestCandidate = c;
          bestPattern = p;
        }
      }
    }
    if (bestPattern == null || bestCandidate == null) return null;

    final field = bestCandidate.value
        ? 'the doing-business-as field'
        : 'the establishment name';
    return OwnershipDisclosure(
      parentName: bestPattern.group.ultimateParent,
      group: bestPattern.group,
      operatingCompany: trimmed.isEmpty ? null : trimmed,
      establishmentNumber: establishmentNumber,
      disclosedEntities: [
        if (trimmed.isNotEmpty) trimmed,
        ...dbaEntries,
      ],
      basis:
          'Matched on "${bestCandidate.key}" in $field of the USDA/FSIS establishment record for EST $establishmentNumber.',
      source: OwnershipSource.localCrosswalk,
      siblings: const [],
      totalRelated: null,
      owner: bestPattern.group.owner(species),
      species: species,
    );
  }

  /// Species from the FSIS record's own activity list, falling back to the
  /// corporate name. Used to pick the right market-share table.
  static MeatSpecies speciesFor(String activities, String nameAndDbas) {
    final a = activities.toLowerCase();
    final n = nameAndDbas.toLowerCase();
    if (a.contains('beef') || a.contains('cattle') || a.contains('bovine')) {
      return MeatSpecies.beef;
    }
    if (a.contains('swine') || a.contains('pork') || a.contains('hog')) {
      return MeatSpecies.pork;
    }
    if (a.contains('chicken') || a.contains('broiler')) {
      return MeatSpecies.chicken;
    }
    if (a.contains('turkey')) return MeatSpecies.turkey;
    if (n.contains('national beef') ||
        n.contains('iowa premium') ||
        n.contains('swift beef') ||
        n.contains('packerland') ||
        n.contains('cargill meat') ||
        n.contains('tyson fresh meats')) {
      return MeatSpecies.beef;
    }
    if (n.contains('smithfield') ||
        n.contains('swift pork') ||
        n.contains('john morrell') ||
        n.contains('farmland foods')) {
      return MeatSpecies.pork;
    }
    if (n.contains('pilgrim')) return MeatSpecies.chicken;
    return MeatSpecies.unknown;
  }
}

// ── Site parent-company database ────────────────────────────────────────────

/// farmanimaltransparency.com's own parent-company database: 16 parents over
/// 330 establishments, returning the parent, the FSIS record and every sibling
/// plant. Authoritative and correctable without an app release. Not complete —
/// EST 245 (Tyson, Lexington NE) and EST 7071 (Butterball) are absent as of
/// 2026-09-06 — so callers fall back to the crosswalk on a miss.
class ParentCompanyService {
  static const _base =
      'https://farmanimaltransparency.com/wp-json/fat/v1/parent-company';

  static final Map<String, OwnershipDisclosure?> _cache = {};

  static String _normalize(String est) => est
      .replaceAll(RegExp(r'EST\.?', caseSensitive: false), '')
      .replaceAll(RegExp(r'P-', caseSensitive: false), '')
      .replaceAll('#', '')
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  static Future<OwnershipDisclosure?> lookup(String? rawEst) async {
    if (rawEst == null) return null;
    final key = _normalize(rawEst);
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    // The database keys plants as "M969+V969" and resolves a bare number only
    // for some of them, so try the prefixed forms too.
    for (final candidate in [key, 'M$key', 'P$key']) {
      try {
        final r = await http
            .get(Uri.parse('$_base/$candidate'))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) continue;
        final d = jsonDecode(r.body);
        if (d is! Map || d['found'] != true) continue;

        final est = Map<String, dynamic>.from(d['establishment'] ?? {});
        final parent = (d['parent_company'] ?? '').toString();
        if (parent.isEmpty) continue;

        final name = (est['name'] ?? '').toString();
        final dbas = (est['dbas'] ?? '').toString();
        final estNumber = (est['establishment_number'] ?? candidate).toString();
        final city = (est['city'] ?? '').toString();
        final state = (est['state'] ?? '').toString();
        final activities = (est['activities'] ?? '').toString();

        final siblings = ((d['related_establishments'] as List?) ?? [])
            .whereType<Map>()
            .map((m) =>
                RelatedEstablishment.fromJson(Map<String, dynamic>.from(m)))
            .toList();

        final group = BigFourOwnership.groupForParentName(parent);
        final species =
            BigFourOwnership.speciesFor(activities, '$name $dbas');

        final disclosure = OwnershipDisclosure(
          parentName: parent,
          group: group,
          operatingCompany: name.isEmpty ? null : name,
          establishmentNumber: estNumber,
          disclosedEntities: [
            if (name.isNotEmpty) name,
            ...dbas
                .split(';')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty),
          ],
          basis:
              'Establishment $estNumber ($name, ${[city, state].where((s) => s.isNotEmpty).join(', ')}) is recorded under this parent in FAT\'s parent-company database, built from the USDA/FSIS establishment directory.',
          source: OwnershipSource.siteDatabase,
          siblings: siblings,
          totalRelated: (d['total_related'] as num?)?.toInt(),
          owner: group?.owner(species),
          species: species,
        );
        _cache[key] = disclosure;
        return disclosure;
      } catch (_) {
        continue;
      }
    }
    _cache[key] = null;
    return null;
  }
}
