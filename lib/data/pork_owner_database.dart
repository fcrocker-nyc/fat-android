// Pure Dart port of PorkOwnerData.swift.
// Models corporate ownership of meat brands across species
// (pork, beef, chicken, turkey). No Flutter imports.

// ── Meat Species ────────────────────────────────────────────────────────────

enum MeatSpecies {
  pork,
  beef,
  chicken,
  turkey,
  unknown,
}

extension MeatSpeciesLabel on MeatSpecies {
  String get label {
    switch (this) {
      case MeatSpecies.pork:
        return 'Pork';
      case MeatSpecies.beef:
        return 'Beef';
      case MeatSpecies.chicken:
        return 'Chicken';
      case MeatSpecies.turkey:
        return 'Turkey';
      case MeatSpecies.unknown:
        return 'unknown';
    }
  }
}

// ── Corporate Owner ─────────────────────────────────────────────────────────

class PorkCorporateOwner {
  final String id;
  final String name;
  final String country;
  final String flag;
  final double marketSharePct;
  final bool isTop3;
  final String note;
  final String? profileURL;

  const PorkCorporateOwner({
    required this.id,
    required this.name,
    required this.country,
    required this.flag,
    required this.marketSharePct,
    required this.isTop3,
    required this.note,
    this.profileURL,
  });

  double get hhiContribution => marketSharePct * marketSharePct;
}

// ── Detection Source ────────────────────────────────────────────────────────

enum DetectionSource {
  brandName,
  estNumber,
}

// ── Ownership Result ────────────────────────────────────────────────────────

class PorkOwnerResult {
  final String detectedBrand;
  final PorkCorporateOwner owner;
  final DetectionSource source;
  final MeatSpecies species;

  const PorkOwnerResult({
    required this.detectedBrand,
    required this.owner,
    required this.source,
    this.species = MeatSpecies.pork,
  });
}

// ── Brand Keyword Entry ─────────────────────────────────────────────────────

class BrandKeyword {
  final String keyword;
  final String ownerID;

  const BrandKeyword(this.keyword, this.ownerID);
}

/// Mirrors Swift's `String.capitalized`: uppercases the first letter of each
/// whitespace-separated word, lowercases the rest.
String _capitalized(String input) {
  return input
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

// ── HHI ─────────────────────────────────────────────────────────────────────

class PorkMarketHHI {
  static const double estimatedFull = 1620;

  static double get top3Contribution => PorkOwnerDatabase.owners
      .where((o) => o.isTop3)
      .fold(0.0, (sum, o) => sum + o.hhiContribution);

  static String classification(double hhi) {
    if (hhi < 1500) return 'Unconcentrated';
    if (hhi < 2500) return 'Moderately Concentrated';
    return 'Highly Concentrated';
  }
}

// ── Database ────────────────────────────────────────────────────────────────

class PorkOwnerDatabase {
  // ── Pork Corporate Owners ─────────────────────────────────────────────────

  static const List<PorkCorporateOwner> owners = [
    PorkCorporateOwner(
      id: 'whgroup',
      name: 'WH Group (Shuanghui International)',
      country: 'China',
      flag: '\u{1F1E8}\u{1F1F3}',
      marketSharePct: 27.0,
      isTop3: true,
      note:
          "WH Group, headquartered in Hong Kong/Henan, acquired Smithfield Foods in 2013 for \$7.1B \u{2014} the largest Chinese acquisition of a US company at the time. Smithfield is the world's largest pork producer.",
      profileURL: 'https://www.whgroup.com',
    ),
    PorkCorporateOwner(
      id: 'tyson',
      name: 'Tyson Foods, Inc.',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 18.0,
      isTop3: true,
      note:
          'Publicly traded US company (NYSE: TSN), majority-controlled by the Tyson family through a dual-class share structure. Headquartered in Springdale, Arkansas.',
      profileURL: 'https://www.tysonfoods.com',
    ),
    PorkCorporateOwner(
      id: 'jbs',
      name: 'JBS S.A.',
      country: 'Brazil',
      flag: '\u{1F1E7}\u{1F1F7}',
      marketSharePct: 16.0,
      isTop3: true,
      note:
          "JBS S.A. is the world's largest meat processing company, headquartered in S\u{00E3}o Paulo, Brazil. Majority-owned by J&F Investimentos, controlled by the Batista family.",
      profileURL: 'https://jbssa.com',
    ),
    PorkCorporateOwner(
      id: 'hormel',
      name: 'Hormel Foods Corporation',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 10.0,
      isTop3: false,
      note:
          'Publicly traded US company (NYSE: HRL), widely held. Headquartered in Austin, Minnesota. Known for SPAM and a broad portfolio of branded meats.',
      profileURL: 'https://www.hormelfoods.com',
    ),
    PorkCorporateOwner(
      id: 'seaboard',
      name: 'Seaboard Corporation',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 4.0,
      isTop3: false,
      note:
          'Privately controlled US conglomerate (NYSE: SEB), primarily controlled by the Bresky family. Headquartered in Merriam, Kansas.',
      profileURL: 'https://www.seaboardcorp.com',
    ),
    PorkCorporateOwner(
      id: 'kraftheinz',
      name: 'The Kraft Heinz Company',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 3.0,
      isTop3: false,
      note:
          'Publicly traded US company (NASDAQ: KHC). Major shareholders include Berkshire Hathaway and 3G Capital. Processes pork primarily through the Oscar Mayer brand.',
      profileURL: 'https://www.kraftheinzcompany.com',
    ),
    PorkCorporateOwner(
      id: 'sigma',
      name: 'Alfa S.A.B. de C.V. (Sigma Alimentos)',
      country: 'Mexico',
      flag: '\u{1F1F2}\u{1F1FD}',
      marketSharePct: 2.0,
      isTop3: false,
      note:
          'Sigma Alimentos is a subsidiary of Alfa S.A.B. de C.V., a Mexican multinational conglomerate. Acquired Bar-S Foods in 2010.',
      profileURL: 'https://www.sigma-alimentos.com',
    ),
  ];

  // ── Pork Brand Keywords ───────────────────────────────────────────────────

  static const List<BrandKeyword> brandKeywords = [
    BrandKeyword('smithfield', 'whgroup'),
    BrandKeyword('farmland', 'whgroup'),
    BrandKeyword('eckrich', 'whgroup'),
    BrandKeyword('gwaltney', 'whgroup'),
    BrandKeyword('john morrell', 'whgroup'),
    BrandKeyword('armour', 'whgroup'),
    BrandKeyword("cook's", 'whgroup'),
    BrandKeyword('cooks ham', 'whgroup'),
    BrandKeyword('kretschmar', 'whgroup'),
    BrandKeyword('margherita', 'whgroup'),
    BrandKeyword("nathan's famous", 'whgroup'),
    BrandKeyword('nathans famous', 'whgroup'),
    BrandKeyword('patrick cudahy', 'whgroup'),
    BrandKeyword("curly's", 'whgroup'),
    BrandKeyword('curlys', 'whgroup'),
    BrandKeyword('jimmy dean', 'tyson'),
    BrandKeyword('hillshire farm', 'tyson'),
    BrandKeyword('hillshire farms', 'tyson'),
    BrandKeyword('ball park', 'tyson'),
    BrandKeyword('ballpark', 'tyson'),
    BrandKeyword('state fair', 'tyson'),
    BrandKeyword('wright brand', 'tyson'),
    BrandKeyword('wright bacon', 'tyson'),
    BrandKeyword('swift premium', 'jbs'),
    BrandKeyword('swift pork', 'jbs'),
    BrandKeyword('hormel', 'hormel'),
    BrandKeyword('spam', 'hormel'),
    BrandKeyword('applegate', 'hormel'),
    BrandKeyword('natural choice', 'hormel'),
    BrandKeyword('always tender', 'hormel'),
    BrandKeyword('black label', 'hormel'),
    BrandKeyword('cure 81', 'hormel'),
    BrandKeyword('cure81', 'hormel'),
    BrandKeyword('prairie fresh', 'seaboard'),
    BrandKeyword("daily's", 'seaboard'),
    BrandKeyword('dailys', 'seaboard'),
    BrandKeyword('oscar mayer', 'kraftheinz'),
    BrandKeyword('oscar meyer', 'kraftheinz'),
    BrandKeyword('bar-s', 'sigma'),
    BrandKeyword('bar s foods', 'sigma'),
  ];

  // ── Pork Establishment Owners ─────────────────────────────────────────────

  static const Map<String, String> establishmentOwners = {
    '18079': 'whgroup',
    '6399': 'whgroup',
    '9400': 'whgroup',
    '5843': 'whgroup',
    '7257': 'whgroup',
    '20414': 'whgroup',
    '13217': 'whgroup',
    '21276': 'tyson',
    '44': 'tyson',
    '89': 'tyson',
    '969': 'tyson',
    '8095': 'tyson',
    '9105': 'tyson',
    '6250': 'jbs',
    '6199': 'jbs',
    '2353': 'jbs',
    '7286': 'jbs',
    '7427': 'jbs',
    '3': 'hormel',
    '199': 'hormel',
    '490': 'hormel',
    '1827': 'hormel',
    '6328': 'hormel',
    '4021': 'seaboard',
    '7893': 'seaboard',
  };

  // ── Pork Lookups ──────────────────────────────────────────────────────────

  static PorkCorporateOwner? ownerForID(String id) {
    for (final o in owners) {
      if (o.id == id) return o;
    }
    return null;
  }

  static PorkOwnerResult? detectOwnerInText(String text) {
    final normalized = text.toLowerCase();
    for (final entry in brandKeywords) {
      if (normalized.contains(entry.keyword)) {
        final owner = ownerForID(entry.ownerID);
        if (owner != null) {
          return PorkOwnerResult(
            detectedBrand: _capitalized(entry.keyword),
            owner: owner,
            source: DetectionSource.brandName,
          );
        }
      }
    }
    return null;
  }

  static PorkOwnerResult? detectOwnerForEstablishment(String est) {
    final digits = normalizeEst(est);
    if (digits.isEmpty) return null;
    final ownerID = establishmentOwners[digits];
    if (ownerID == null) return null;
    final owner = ownerForID(ownerID);
    if (owner == null) return null;
    return PorkOwnerResult(
      detectedBrand: 'EST. $digits',
      owner: owner,
      source: DetectionSource.estNumber,
    );
  }

  // ── Beef Processors & Brands ──────────────────────────────────────────────

  static const List<PorkCorporateOwner> beefOwners = [
    PorkCorporateOwner(
      id: 'jbs_beef',
      name: 'JBS USA (Beef)',
      country: 'Brazil',
      flag: '\u{1F1E7}\u{1F1F7}',
      marketSharePct: 25.0,
      isTop3: true,
      note:
          "JBS S.A., headquartered in S\u{00E3}o Paulo, Brazil, is the world's largest meat processing company. Acquired Swift & Company in 2007. Majority-owned by the Batista family.",
      profileURL: 'https://jbssa.com',
    ),
    PorkCorporateOwner(
      id: 'tyson_beef',
      name: 'Tyson Fresh Meats (Beef)',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 23.0,
      isTop3: true,
      note:
          'Tyson Foods (NYSE: TSN) is the second-largest US beef packer. Majority-controlled by the Tyson family. Headquartered in Springdale, Arkansas.',
      profileURL: 'https://www.tysonfoods.com',
    ),
    PorkCorporateOwner(
      id: 'cargill_beef',
      name: 'Cargill Meat Solutions',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 21.0,
      isTop3: true,
      note:
          'Cargill is one of the largest privately held US companies. About 21% of US fed cattle slaughter. Family- and employee-owned, headquartered in Wayzata, Minnesota.',
      profileURL: 'https://www.cargill.com',
    ),
    PorkCorporateOwner(
      id: 'national_beef',
      name: 'National Beef Packing Co.',
      country: 'Brazil',
      flag: '\u{1F1E7}\u{1F1F7}',
      marketSharePct: 11.0,
      isTop3: false,
      note:
          'Majority-owned by Marfrig Global Foods S.A. (Brazil). Headquartered in Kansas City, Missouri.',
      profileURL: 'https://www.nationalbeef.com',
    ),
  ];

  static const List<BrandKeyword> beefBrandKeywords = [
    BrandKeyword('swift', 'jbs_beef'),
    BrandKeyword('swift premium', 'jbs_beef'),
    BrandKeyword('1855', 'jbs_beef'),
    BrandKeyword('cedar river farms', 'jbs_beef'),
    BrandKeyword('iowa premium', 'tyson_beef'),
    BrandKeyword('excel beef', 'cargill_beef'),
    BrandKeyword('sterling silver', 'cargill_beef'),
    BrandKeyword('rumba meats', 'cargill_beef'),
    BrandKeyword('national beef', 'national_beef'),
    BrandKeyword('kansas city steak', 'national_beef'),
  ];

  static const Map<String, String> beefEstablishmentOwners = {
    '672': 'jbs_beef',
    '267': 'jbs_beef',
    '245': 'tyson_beef',
    '549': 'tyson_beef',
    '210': 'tyson_beef',
    '86j': 'cargill_beef',
    '13600': 'cargill_beef',
    '2662': 'cargill_beef',
    '1521': 'national_beef',
    '316': 'national_beef',
    '208': 'national_beef',
  };

  static PorkOwnerResult? detectBeefOwnerInText(String text) {
    final normalized = text.toLowerCase();
    for (final entry in beefBrandKeywords) {
      if (normalized.contains(entry.keyword)) {
        for (final owner in beefOwners) {
          if (owner.id == entry.ownerID) {
            return PorkOwnerResult(
              detectedBrand: _capitalized(entry.keyword),
              owner: owner,
              source: DetectionSource.brandName,
              species: MeatSpecies.beef,
            );
          }
        }
      }
    }
    return null;
  }

  static PorkOwnerResult? detectBeefOwnerForEstablishment(String est) {
    final digits = normalizeEst(est);
    if (digits.isEmpty) return null;
    final ownerID = beefEstablishmentOwners[digits];
    if (ownerID == null) return null;
    for (final owner in beefOwners) {
      if (owner.id == ownerID) {
        return PorkOwnerResult(
          detectedBrand: 'EST. $digits',
          owner: owner,
          source: DetectionSource.estNumber,
          species: MeatSpecies.beef,
        );
      }
    }
    return null;
  }

  // ── Chicken Processors & Brands ───────────────────────────────────────────

  static const List<PorkCorporateOwner> chickenOwners = [
    PorkCorporateOwner(
      id: 'tyson_chicken',
      name: 'Tyson Foods (Chicken)',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 20.0,
      isTop3: true,
      note:
          'Tyson Foods is the largest US chicken processor. Headquartered in Springdale, Arkansas.',
      profileURL: 'https://www.tysonfoods.com',
    ),
    PorkCorporateOwner(
      id: 'pilgrims',
      name: "Pilgrim's Pride (JBS)",
      country: 'Brazil',
      flag: '\u{1F1E7}\u{1F1F7}',
      marketSharePct: 18.0,
      isTop3: true,
      note:
          'Majority-owned by JBS S.A. (Brazil). JBS acquired controlling stake in 2009. Headquartered in Greeley, Colorado.',
      profileURL: 'https://www.pilgrims.com',
    ),
    PorkCorporateOwner(
      id: 'wayne_sanderson',
      name: 'Wayne-Sanderson Farms',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 15.0,
      isTop3: true,
      note:
          'Formed in 2022 through merger of Wayne Farms and Sanderson Farms under Continental Grain Company and Cargill JV. Headquartered in Oakwood, Georgia.',
      profileURL: 'https://waynesandersonfarms.com',
    ),
    PorkCorporateOwner(
      id: 'koch_foods',
      name: 'Koch Foods',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 9.0,
      isTop3: false,
      note:
          'Privately held US chicken processor headquartered in Park Ridge, Illinois. No relation to Koch Industries.',
      profileURL: 'https://www.kochfoods.com',
    ),
    PorkCorporateOwner(
      id: 'perdue',
      name: 'Perdue Farms',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 8.0,
      isTop3: false,
      note:
          'Family-owned, privately held. Headquartered in Salisbury, Maryland. Founded 1920.',
      profileURL: 'https://www.perduefarms.com',
    ),
  ];

  static const List<BrandKeyword> chickenBrandKeywords = [
    BrandKeyword('tyson chicken', 'tyson_chicken'),
    BrandKeyword('tyson naturals', 'tyson_chicken'),
    BrandKeyword("pilgrim's", 'pilgrims'),
    BrandKeyword('pilgrims pride', 'pilgrims'),
    BrandKeyword('just bare', 'pilgrims'),
    BrandKeyword('sanderson farms', 'wayne_sanderson'),
    BrandKeyword('wayne farms', 'wayne_sanderson'),
    BrandKeyword('perdue', 'perdue'),
    BrandKeyword('harvestland', 'perdue'),
    BrandKeyword('perdue airchilled', 'perdue'),
  ];

  static const Map<String, String> chickenEstablishmentOwners = {
    '7211': 'tyson_chicken',
    '8066': 'tyson_chicken',
    '2459': 'tyson_chicken',
    '9280': 'tyson_chicken',
    '7851': 'pilgrims',
    '7869': 'pilgrims',
    '8429': 'pilgrims',
    '1439': 'pilgrims',
    '9010': 'wayne_sanderson',
    '9012': 'wayne_sanderson',
    '8700': 'wayne_sanderson',
    '2000': 'perdue',
    '6085': 'perdue',
    '7756': 'perdue',
  };

  static PorkOwnerResult? detectChickenOwnerInText(String text) {
    final normalized = text.toLowerCase();
    for (final entry in chickenBrandKeywords) {
      if (normalized.contains(entry.keyword)) {
        for (final owner in chickenOwners) {
          if (owner.id == entry.ownerID) {
            return PorkOwnerResult(
              detectedBrand: _capitalized(entry.keyword),
              owner: owner,
              source: DetectionSource.brandName,
              species: MeatSpecies.chicken,
            );
          }
        }
      }
    }
    return null;
  }

  static PorkOwnerResult? detectChickenOwnerForEstablishment(String est) {
    final digits = normalizeEst(est);
    if (digits.isEmpty) return null;
    final ownerID = chickenEstablishmentOwners[digits];
    if (ownerID == null) return null;
    for (final owner in chickenOwners) {
      if (owner.id == ownerID) {
        return PorkOwnerResult(
          detectedBrand: 'EST. $digits',
          owner: owner,
          source: DetectionSource.estNumber,
          species: MeatSpecies.chicken,
        );
      }
    }
    return null;
  }

  // ── Turkey Processors & Brands ────────────────────────────────────────────

  static const List<PorkCorporateOwner> turkeyOwners = [
    PorkCorporateOwner(
      id: 'butterball',
      name: 'Butterball LLC',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 20.0,
      isTop3: true,
      note:
          'Butterball is the #1 turkey brand in the US, producing ~20% of all US turkey. Joint venture between Seaboard Corporation (NYSE: SEB) and Maxwell Farms (Goldsboro Milling). Headquartered in Garner, North Carolina. 7,300+ employees.',
      profileURL: 'https://www.butterball.com',
    ),
    PorkCorporateOwner(
      id: 'jennieo',
      name: 'Jennie-O Turkey Store (Hormel)',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 17.0,
      isTop3: true,
      note:
          "Jennie-O Turkey Store is a wholly owned subsidiary of Hormel Foods (NYSE: HRL). Headquartered in Willmar, Minnesota. Created from 1986 merger of Jennie-O Foods and Turkey Store Company. Named after founder Earl B. Olson's daughter. All major operations in Minnesota.",
      profileURL: 'https://www.jennieo.com',
    ),
    PorkCorporateOwner(
      id: 'cargill_turkey',
      name: 'Cargill Protein (Turkey)',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 13.0,
      isTop3: true,
      note:
          'Cargill is the #3 US turkey producer. Part of Cargill Protein division. Sells under Honeysuckle White and Shady Brook Farms brands. Closed Springdale, Arkansas turkey plant in 2025. Cargill is the largest privately held US company.',
      profileURL: 'https://www.cargill.com',
    ),
    PorkCorporateOwner(
      id: 'farbest',
      name: 'Farbest Foods',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 5.0,
      isTop3: false,
      note:
          'Farbest Foods is a family-owned, vertically integrated turkey company based in Huntingburg, Indiana. One of the top 5 US turkey processors.',
      profileURL: 'https://www.farbestfoods.com',
    ),
    PorkCorporateOwner(
      id: 'foster_turkey',
      name: 'Foster Farms (Turkey)',
      country: 'United States',
      flag: '\u{1F1FA}\u{1F1F8}',
      marketSharePct: 4.0,
      isTop3: false,
      note:
          'Foster Farms is a privately held West Coast poultry company headquartered in Livingston, California. Processes both chicken and turkey.',
      profileURL: 'https://www.fosterfarms.com',
    ),
  ];

  static const List<BrandKeyword> turkeyBrandKeywords = [
    // Butterball
    BrandKeyword('butterball', 'butterball'),
    BrandKeyword('carolina turkey', 'butterball'),

    // Jennie-O / Hormel
    BrandKeyword('jennie-o', 'jennieo'),
    BrandKeyword('jennie o', 'jennieo'),
    BrandKeyword('jennieo', 'jennieo'),

    // Cargill Turkey
    BrandKeyword('honeysuckle white', 'cargill_turkey'),
    BrandKeyword('honeysuckle', 'cargill_turkey'),
    BrandKeyword('shady brook farms', 'cargill_turkey'),
    BrandKeyword('shady brook', 'cargill_turkey'),

    // Farbest
    BrandKeyword('farbest', 'farbest'),

    // Foster Farms turkey
    BrandKeyword('foster farms turkey', 'foster_turkey'),
  ];

  static const Map<String, String> turkeyEstablishmentOwners = {
    // Butterball plants
    '7071': 'butterball', // Butterball – Mt. Olive, NC
    '18044': 'butterball', // Butterball – Ozark, AR
    '45029': 'butterball', // Butterball – Carthage, MO
    '7355': 'butterball', // Butterball – Huntsville, AR

    // Jennie-O plants
    '7516': 'jennieo', // Jennie-O – Willmar, MN
    '135': 'jennieo', // Jennie-O – Faribault, MN
    '18076': 'jennieo', // Jennie-O – Melrose, MN

    // Cargill Turkey plants
    '45040': 'cargill_turkey', // Cargill – Springdale, AR (closing 2025)
    '374': 'cargill_turkey', // Cargill – Harrisonburg, VA
    '9618': 'cargill_turkey', // Cargill – Dayton, VA

    // Farbest
    '5765': 'farbest', // Farbest – Huntingburg, IN
  };

  static PorkOwnerResult? detectTurkeyOwnerInText(String text) {
    final normalized = text.toLowerCase();
    for (final entry in turkeyBrandKeywords) {
      if (normalized.contains(entry.keyword)) {
        for (final owner in turkeyOwners) {
          if (owner.id == entry.ownerID) {
            return PorkOwnerResult(
              detectedBrand: _capitalized(entry.keyword),
              owner: owner,
              source: DetectionSource.brandName,
              species: MeatSpecies.turkey,
            );
          }
        }
      }
    }
    return null;
  }

  static PorkOwnerResult? detectTurkeyOwnerForEstablishment(String est) {
    final digits = normalizeEst(est);
    if (digits.isEmpty) return null;
    final ownerID = turkeyEstablishmentOwners[digits];
    if (ownerID == null) return null;
    for (final owner in turkeyOwners) {
      if (owner.id == ownerID) {
        return PorkOwnerResult(
          detectedBrand: 'EST. $digits',
          owner: owner,
          source: DetectionSource.estNumber,
          species: MeatSpecies.turkey,
        );
      }
    }
    return null;
  }

  // ── Unified Detection ─────────────────────────────────────────────────────

  /// Mirrors Swift's normalizeEst: strips EST./EST/M/P-/V (case-insensitive
  /// except the exact "P-"), then trims whitespace.
  static String normalizeEst(String est) {
    var s = est;
    s = _replaceCaseInsensitive(s, 'EST.', '');
    s = _replaceCaseInsensitive(s, 'EST', '');
    s = _replaceCaseInsensitive(s, 'M', '');
    s = s.replaceAll('P-', '');
    s = _replaceCaseInsensitive(s, 'V', '');
    return s.trim();
  }

  static String _replaceCaseInsensitive(
      String input, String target, String replacement) {
    return input.replaceAll(
      RegExp(RegExp.escape(target), caseSensitive: false),
      replacement,
    );
  }

  static PorkOwnerResult? detectOwnerForSpeciesInText(
      MeatSpecies species, String text) {
    switch (species) {
      case MeatSpecies.pork:
        return detectOwnerInText(text);
      case MeatSpecies.beef:
        return detectBeefOwnerInText(text);
      case MeatSpecies.chicken:
        return detectChickenOwnerInText(text);
      case MeatSpecies.turkey:
        return detectTurkeyOwnerInText(text);
      case MeatSpecies.unknown:
        return null;
    }
  }

  static PorkOwnerResult? detectOwnerForSpeciesEstablishment(
      MeatSpecies species, String est) {
    switch (species) {
      case MeatSpecies.pork:
        return detectOwnerForEstablishment(est);
      case MeatSpecies.beef:
        return detectBeefOwnerForEstablishment(est);
      case MeatSpecies.chicken:
        return detectChickenOwnerForEstablishment(est);
      case MeatSpecies.turkey:
        return detectTurkeyOwnerForEstablishment(est);
      case MeatSpecies.unknown:
        return null;
    }
  }

  static PorkOwnerResult? detectOwnerAnySpeciesInText(String text) {
    return detectOwnerInText(text) ??
        detectBeefOwnerInText(text) ??
        detectChickenOwnerInText(text) ??
        detectTurkeyOwnerInText(text);
  }

  static PorkOwnerResult? detectOwnerAnySpeciesForEstablishment(String est) {
    return detectOwnerForEstablishment(est) ??
        detectBeefOwnerForEstablishment(est) ??
        detectChickenOwnerForEstablishment(est) ??
        detectTurkeyOwnerForEstablishment(est);
  }
}
