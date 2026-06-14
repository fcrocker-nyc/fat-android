/// Result of a meat brand lookup.
class MeatBrandResult {
  final String brandName;
  final String corporateParent;
  final String parentCountry; // Country flag emoji + name
  final bool isForeignOwned;
  final List<String> species; // Beef, Pork, Chicken, Turkey
  final String marketPosition; // e.g. "#1 US beef processor"
  final String plantCount; // e.g. "120+ US facilities"
  final List<String> keyPlantLocations; // Major plant cities
  final List<String> knownEstNumbers; // EST numbers linked to this brand
  final String ownershipNotes;
  final String? regulatoryNotes;
  final List<String> relatedBrands; // Other brands under same parent

  const MeatBrandResult({
    required this.brandName,
    required this.corporateParent,
    required this.parentCountry,
    required this.isForeignOwned,
    required this.species,
    required this.marketPosition,
    required this.plantCount,
    required this.keyPlantLocations,
    required this.knownEstNumbers,
    required this.ownershipNotes,
    this.regulatoryNotes,
    required this.relatedBrands,
  });
}

/// Local database of major US retail and wholesale meat brands.
class MeatBrandDatabase {
  /// Search for a meat brand by name. Returns matches.
  ///
  /// Case-insensitive: returns all records where brandName, corporateParent,
  /// or any relatedBrands entry contains the query (trimmed, lowercased).
  static List<MeatBrandResult> search(String query) {
    final lowered = query.toLowerCase().trim();
    if (lowered.isEmpty) return [];

    return all.where((brand) {
      return brand.brandName.toLowerCase().contains(lowered) ||
          brand.corporateParent.toLowerCase().contains(lowered) ||
          brand.relatedBrands
              .any((b) => b.toLowerCase().contains(lowered));
    }).toList();
  }

  /// Detect brand from EST number. Returns null if no match.
  static MeatBrandResult? brandForEST(String est) {
    for (final brand in all) {
      if (brand.knownEstNumbers.contains(est)) return brand;
    }
    return null;
  }

  static const List<MeatBrandResult> all = [
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // THE BIG FOUR + MAJOR PROCESSORS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    MeatBrandResult(
      brandName: 'Tyson',
      corporateParent: 'Tyson Foods, Inc.',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Beef', 'Pork', 'Chicken'],
      marketPosition:
          'Largest meat company in the US. #2 globally after JBS. Produces ~20% of US beef, chicken, and pork. Fortune 500 (#85). 133,000 employees.',
      plantCount:
          '120+ US facilities across beef, pork, chicken, and prepared foods',
      keyPlantLocations: [
        'Springdale, Arkansas (headquarters)',
        'Amarillo, Texas (beef)',
        'Holcomb, Kansas (beef)',
        'Lexington, Nebraska (beef)',
        'Dakota City, Nebraska (beef — IBP legacy)',
        'Storm Lake, Iowa (pork)',
        'Waterloo, Iowa (pork)',
        'Joslin, Illinois (pork)',
        'Springdale, Arkansas (chicken)',
        'Wilkesboro, North Carolina (chicken)',
        'Eagle Mountain, Utah (case-ready beef/pork)',
        'Sherman, Texas (case-ready)',
        'Council Bluffs, Iowa (case-ready)',
      ],
      knownEstNumbers: ['245', '969', '337', '795', '13556', '1326', '578A'],
      ownershipNotes:
          'Founded 1935 by John W. Tyson in Springdale, Arkansas. Publicly traded (NYSE: TSN). Acquired IBP Inc. (largest beef/pork processor) in 2001 for \$3.2 billion. Three generations of Tyson family leadership. Supplies McDonald\'s, Burger King, Wendy\'s, KFC, Taco Bell, Walmart, and Kroger.',
      regulatoryNotes:
          'Multiple price-fixing investigations. In 2022, Tyson settled a \$221.5M antitrust lawsuit alleging chicken price-fixing. Closed multiple plants in 2023-2025 restructuring including Perry, Iowa (pork, 1,200 jobs), four chicken plants, and Emporia, Kansas (beef, 809 jobs). Subject to proposed legislation by Democratic senators to break up the company over market power concerns.',
      relatedBrands: [
        'Jimmy Dean',
        'Hillshire Farm',
        'Ball Park',
        'Wright Brand',
        'Aidells',
        'State Fair',
        'IBP',
      ],
    ),

    MeatBrandResult(
      brandName: 'JBS',
      corporateParent: 'JBS S.A.',
      parentCountry: '🇧🇷 Brazil',
      isForeignOwned: true,
      species: ['Beef', 'Pork', 'Chicken', 'Lamb'],
      marketPosition:
          'World\'s largest meat company. #1 global beef processor. 9 US beef plants, 5 US pork plants. Owns Pilgrim\'s Pride (#2 US chicken). ~16,000 beef employees, ~11,000 pork employees in US.',
      plantCount:
          '14+ major US beef/pork facilities plus Pilgrim\'s Pride chicken operations in 14 states',
      keyPlantLocations: [
        'Greeley, Colorado (beef — JBS USA HQ)',
        'Cactus, Texas (beef)',
        'Grand Island, Nebraska (beef)',
        'Hyrum, Utah (beef)',
        'Souderton, Pennsylvania (beef)',
        'Tolleson, Arizona (beef)',
        'Brooks, Alberta, Canada (beef)',
        'Marshalltown, Iowa (pork)',
        'Worthington, Minnesota (pork)',
        'Ottumwa, Iowa (pork)',
        'Beardstown, Illinois (pork)',
        'Louisville, Kentucky (pork)',
      ],
      knownEstNumbers: ['578', '969G', '7', '312', '244', '864'],
      ownershipNotes:
          'Founded 1953 by Jose Batista Sobrinho in Goias, Brazil. JBS S.A. is publicly traded in Brazil; approved for NYSE listing in May 2025. Acquired Swift & Company (2007, \$225M), Smithfield Beef Group (2008, \$565M), and 64% of Pilgrim\'s Pride (2009, \$800M). BNDES (Brazilian state development bank) invested \$2.6B+ to fuel JBS\'s global expansion. World\'s largest protein company with 200,000+ employees globally.',
      regulatoryNotes:
          'JBS S.A. founders (Batista brothers) pleaded guilty to bribery in Brazil in 2017, paying \$3.2 billion — the largest leniency fine in Brazilian history. Multiple food safety recalls in US operations. 2021 ransomware attack shut down US plants. Pilgrim\'s Pride subsidiary paid \$110M in 2021 to settle chicken price-fixing charges. In January 2025, Pilgrim\'s Pride donated \$5M to Trump\'s inauguration — the largest single donor. Senator Elizabeth Warren raised concerns about regulatory influence.',
      relatedBrands: [
        'Pilgrim\'s Pride',
        'Swift',
        '1855 Premium',
        'Cedar River Farms',
        'Aspen Ridge',
        'Clear River Farms',
      ],
    ),

    MeatBrandResult(
      brandName: 'Pilgrim\'s Pride',
      corporateParent: 'JBS S.A.',
      parentCountry: '🇧🇷 Brazil',
      isForeignOwned: true,
      species: ['Chicken'],
      marketPosition:
          '#2 US chicken producer. Operations in 14 states and Puerto Rico. JBS owns 75.3% stake.',
      plantCount: '30+ US chicken processing facilities',
      keyPlantLocations: [
        'Greeley, Colorado (HQ — shared with JBS USA)',
        'Waco, Texas',
        'Lufkin, Texas',
        'Mt. Pleasant, Texas',
        'Moorefield, West Virginia',
        'Sanford, North Carolina',
        'Douglas, Georgia',
        'Athens, Georgia',
      ],
      knownEstNumbers: ['7851', '538', '17024', '449', '1359', '20728'],
      ownershipNotes:
          'Founded 1946 in Pittsburg, Texas as Bo Pilgrim\'s chicken company. Filed for bankruptcy in 2008. JBS acquired 64% stake in 2009 for \$800M, now owns 75.3%. Publicly traded (NASDAQ: PPC) but controlled by JBS. Second-largest chicken producer in the US.',
      regulatoryNotes:
          'Paid \$110.5M in 2021 to settle DOJ charges of conspiring to fix prices and rig bids for broiler chicken (2012-2017). Former CEO Jayson Penn was indicted on price-fixing charges. \$5M donation to Trump inauguration in January 2025 drew scrutiny from Senator Elizabeth Warren. Planning \$400M chicken plant in Georgia.',
      relatedBrands: ['Gold Kist', 'Country Pride'],
    ),

    MeatBrandResult(
      brandName: 'Cargill',
      corporateParent: 'Cargill, Incorporated',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Beef', 'Turkey'],
      marketPosition:
          'Largest privately held company in the US by revenue (\$160B+). One of the Big Four beef packers. Also a major turkey processor.',
      plantCount:
          'Multiple beef processing plants and turkey operations in the US',
      keyPlantLocations: [
        'Wayzata, Minnesota (global headquarters)',
        'Wichita, Kansas (headquarters — Cargill Protein)',
        'Dodge City, Kansas (beef)',
        'Fort Morgan, Colorado (beef)',
        'Friona, Texas (beef)',
        'Schuyler, Nebraska (beef)',
        'Springdale, Arkansas (turkey — Cargill/Butterball JV)',
      ],
      knownEstNumbers: ['86R', '86G', '86T', '969H'],
      ownershipNotes:
          'Founded 1865. Privately held — owned by the Cargill and MacMillan families. Largest private company in the US. One of the Big Four beef packers alongside Tyson, JBS, and National Beef. Sold its US pork business to JBS in 2015. Exiting some beef operations — sold Fresno plant in 2023.',
      regulatoryNotes:
          'Among the beef packers investigated by USDA and DOJ over cattle market competition concerns. As a private company, faces less public scrutiny than publicly traded competitors.',
      relatedBrands: ['Sterling Silver', 'Rumba Meats'],
    ),

    MeatBrandResult(
      brandName: 'National Beef',
      corporateParent: 'Marfrig Global Foods',
      parentCountry: '🇧🇷 Brazil',
      isForeignOwned: true,
      species: ['Beef'],
      marketPosition:
          '#4 US beef packer. Marfrig owns 51% controlling stake. One of the Big Four alongside Tyson, JBS, and Cargill.',
      plantCount: '2 major beef processing plants',
      keyPlantLocations: [
        'Kansas City, Missouri (headquarters)',
        'Dodge City, Kansas (beef processing)',
        'Liberal, Kansas (beef processing)',
      ],
      knownEstNumbers: ['208', '208A'],
      ownershipNotes:
          'National Beef Packing Company LLC is headquartered in Kansas City, Missouri. Brazilian meat giant Marfrig Global Foods acquired a controlling 51% stake. Marfrig is publicly traded in Brazil. DOJ blocked JBS\'s attempted acquisition of National Beef in 2008 on antitrust grounds.',
      regulatoryNotes:
          'Foreign-owned (Brazil) through Marfrig. Part of the Big Four that collectively control approximately 85% of the US beef market. DOJ and USDA have investigated cattle market competition concerns involving all Big Four packers.',
      relatedBrands: ['Kansas City Steaks', 'National Beef Leathers'],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // PORK SPECIALISTS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    MeatBrandResult(
      brandName: 'Smithfield',
      corporateParent: 'WH Group (Shuanghui International)',
      parentCountry: '🇨🇳 China',
      isForeignOwned: true,
      species: ['Pork'],
      marketPosition:
          '#1 pork producer in the world. ~27% of US pork processing. Largest hog producer in the US.',
      plantCount:
          '40+ US facilities including farms, processing plants, and distribution',
      keyPlantLocations: [
        'Smithfield, Virginia (headquarters + processing)',
        'Tar Heel, North Carolina (largest pork plant in the world)',
        'Sioux Falls, South Dakota (John Morrell legacy)',
        'Clinton, North Carolina',
        'Milan, Missouri',
        'Monmouth, Illinois',
        'Green Bay, Wisconsin (Packerland)',
        'Salt Lake City, Utah',
      ],
      knownEstNumbers: ['4427', '177', '562', '18076', '3751', '6240'],
      ownershipNotes:
          'Founded 1936 in Smithfield, Virginia. WH Group (formerly Shuanghui International), headquartered in Hong Kong/Henan, China, acquired Smithfield Foods in 2013 for \$7.1 billion — the largest Chinese acquisition of a US company at the time. WH Group is publicly traded on the Hong Kong Stock Exchange.',
      regulatoryNotes:
          'Foreign-owned by a Chinese company. The \$7.1B acquisition by WH Group raised national security and food sovereignty concerns. Smithfield\'s hog operations have faced numerous environmental lawsuits, particularly in North Carolina over waste lagoons and spray fields. In 2018-2020, juries awarded hundreds of millions to NC neighbors affected by hog farm operations (later reduced on appeal).',
      relatedBrands: [
        'Eckrich',
        'Nathan\'s Famous (hot dogs)',
        'Armour',
        'Cook\'s',
        'Farmland',
        'John Morrell',
        'Kretschmar',
        'Curly\'s',
        'Carando',
        'Margherita',
      ],
    ),

    MeatBrandResult(
      brandName: 'Hormel',
      corporateParent: 'Hormel Foods Corporation',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Pork', 'Turkey', 'Chicken'],
      marketPosition:
          '~10% of US pork processing. Fortune 500 company. Major prepared meats producer.',
      plantCount: '30+ US facilities',
      keyPlantLocations: [
        'Austin, Minnesota (headquarters + flagship plant)',
        'Fremont, Nebraska',
        'Rochelle, Illinois',
        'Dubuque, Iowa',
        'Knoxville, Iowa',
        'Osceola, Iowa',
      ],
      knownEstNumbers: ['675', '38E', '7516', '1928'],
      ownershipNotes:
          'Founded 1891 in Austin, Minnesota by George A. Hormel. Publicly traded (NYSE: HRL). One of the few major US meat companies that remains domestically owned and publicly traded. Known for SPAM, invented in 1937.',
      regulatoryNotes: null,
      relatedBrands: [
        'SPAM',
        'Dinty Moore',
        'Jennie-O Turkey (turkey)',
        'Applegate (natural/organic)',
        'Columbus Craft Meats',
        'Planters',
      ],
    ),

    MeatBrandResult(
      brandName: 'Seaboard Triumph Foods',
      corporateParent: 'Seaboard Corporation / Triumph Foods',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Pork'],
      marketPosition:
          '~4% of US pork processing. Joint venture between Seaboard Corp and Triumph Foods.',
      plantCount: '2 major pork processing plants',
      keyPlantLocations: [
        'Sioux City, Iowa (JV plant — one of the newest/largest in the US)',
        'St. Joseph, Missouri (Triumph Foods)',
      ],
      knownEstNumbers: ['6912', '51301'],
      ownershipNotes:
          'Joint venture between Seaboard Corporation (NYSE: SEB, based in Merriam, Kansas) and Triumph Foods (privately held, St. Joseph, Missouri). The Sioux City plant opened in 2017 with capacity for 21,000 hogs per day.',
      regulatoryNotes: null,
      relatedBrands: ['Seaboard Foods', 'Triumph Foods', 'Premium Farms'],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // POULTRY SPECIALISTS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    MeatBrandResult(
      brandName: 'Perdue Farms',
      corporateParent: 'Perdue Farms, Inc.',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Chicken', 'Turkey'],
      marketPosition:
          '#3 US chicken producer. Privately held, family-owned. ~6% US chicken market share. Also processes turkey and premium/organic products.',
      plantCount: '20+ US poultry processing facilities',
      keyPlantLocations: [
        'Salisbury, Maryland (headquarters)',
        'Accomac, Virginia',
        'Georgetown, Delaware',
        'Bridgewater, Virginia',
        'Monterey, Tennessee',
        'Cromwell, Kentucky',
        'Washington, Indiana',
        'Perry, Georgia',
      ],
      knownEstNumbers: ['4074', '682', '7114', '7012', '18218'],
      ownershipNotes:
          'Founded 1920 by Arthur Perdue in Salisbury, Maryland. Privately held — third-generation family ownership (Jim Perdue). Known for the Frank Perdue advertising campaigns of the 1970s-80s. Acquired Niman Ranch (premium natural meats) in 2015 and Coleman Natural Foods.',
      regulatoryNotes:
          'Perdue was an early adopter of \'No Antibiotics Ever\' programs and Certified Humane certification in the chicken industry. Has faced OSHA investigations over worker safety at processing plants.',
      relatedBrands: [
        'Perdue Harvestland',
        'Coleman Natural',
        'Niman Ranch',
        'Panorama Meats',
      ],
    ),

    MeatBrandResult(
      brandName: 'Koch Foods',
      corporateParent: 'Koch Foods, Inc.',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Chicken'],
      marketPosition:
          '#5 US chicken producer. Privately held. Vertically integrated from hatcheries to processing.',
      plantCount: '15+ US poultry facilities',
      keyPlantLocations: [
        'Park Ridge, Illinois (headquarters)',
        'Morristown, Tennessee',
        'Chattanooga, Tennessee',
        'Ashland, Alabama',
        'Gadsden, Alabama',
        'Morton, Mississippi',
        'Fairfield, Ohio',
      ],
      knownEstNumbers: ['509', '6901', '20197', '7467'],
      ownershipNotes:
          'Founded 1985 by Joseph Grendys, a first-generation immigrant from Poland. Privately held. One of the largest privately owned chicken companies in the US. No relation to Koch Industries (the Koch brothers\' company).',
      regulatoryNotes:
          'In 2019, Koch Foods paid \$3.75M to settle EEOC harassment and discrimination claims at its Morton, Mississippi plant. The Morton plant was the site of a major ICE immigration raid in August 2019, one of the largest workplace raids in US history (680 workers detained).',
      relatedBrands: ['Koch Foods'],
    ),

    MeatBrandResult(
      brandName: 'Wayne-Sanderson Farms',
      corporateParent: 'Continental Grain / Cargill JV',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Chicken'],
      marketPosition:
          '#3-4 US chicken producer. Formed from 2022 merger of Wayne Farms and Sanderson Farms (\$4.53B deal).',
      plantCount: '25+ US chicken processing facilities',
      keyPlantLocations: [
        'Oakwood, Georgia (headquarters)',
        'Laurel, Mississippi (legacy Sanderson HQ)',
        'Hazlehurst, Mississippi',
        'Bryan/College Station, Texas',
        'Kinston, North Carolina',
        'Enterprise, Alabama',
        'Danville, Arkansas',
        'Jack, Alabama',
      ],
      knownEstNumbers: ['20914', '278', '13024', '14072'],
      ownershipNotes:
          'Continental Grain Company and Cargill acquired Sanderson Farms in 2022 for \$4.53 billion and merged it with Wayne Farms to create Wayne-Sanderson Farms LLC. Continental Grain (privately held, NYC-based, Fribourg family) holds the majority stake.',
      regulatoryNotes:
          'Sanderson Farms was previously the third-largest US poultry producer and was the last major publicly traded pure-play chicken company before the acquisition. Sanderson Farms was named in chicken price-fixing lawsuits but consistently denied wrongdoing.',
      relatedBrands: ['Sanderson Farms', 'Wayne Farms'],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TURKEY SPECIALISTS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    MeatBrandResult(
      brandName: 'Butterball',
      corporateParent: 'Seaboard Corporation / Maxwell Farms',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Turkey'],
      marketPosition:
          '#1 turkey brand in the US. Produces ~20% of all US turkey. Largest vertically integrated turkey company.',
      plantCount: '6+ US turkey processing facilities',
      keyPlantLocations: [
        'Garner, North Carolina (headquarters)',
        'Mount Olive, North Carolina (processing)',
        'Ozark, Arkansas (processing)',
        'Jonesboro, Arkansas (processing)',
        'Carthage, Missouri (processing)',
        'Huntsville, Arkansas',
      ],
      knownEstNumbers: ['7071', '18044', '45029', '7355'],
      ownershipNotes:
          'Butterball LLC is a joint venture between Seaboard Corporation (NYSE: SEB) and Maxwell Farms (owned by the Goldsboro Milling Company). Originally part of ConAgra, then purchased by Carolina Turkey in 2006. Seaboard acquired its stake in 2010. The most recognized turkey brand in America.',
      regulatoryNotes:
          'Subject to animal welfare investigations by Mercy For Animals (2012, 2016) documenting conditions at turkey farms supplying Butterball. North Carolina Attorney General investigated animal cruelty charges in 2012. Five workers were charged. Butterball subsequently implemented third-party animal welfare audits.',
      relatedBrands: ['Carolina Turkey'],
    ),

    MeatBrandResult(
      brandName: 'Jennie-O',
      corporateParent: 'Hormel Foods Corporation',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Turkey'],
      marketPosition:
          '#2 turkey processor in the US. Wholly owned subsidiary of Hormel Foods.',
      plantCount: '6+ US turkey processing facilities in Minnesota',
      keyPlantLocations: [
        'Willmar, Minnesota (headquarters)',
        'Faribault, Minnesota',
        'Melrose, Minnesota',
        'Pelican Rapids, Minnesota',
        'Montevideo, Minnesota',
        'Benson, Minnesota',
      ],
      knownEstNumbers: ['7516', '18076J', '135'],
      ownershipNotes:
          'Jennie-O Turkey Store is a wholly owned subsidiary of Hormel Foods (NYSE: HRL). Created from the 1986 merger of Jennie-O Foods and Turkey Store Company. Named after founder Earl B. Olson\'s daughter. All major operations are in Minnesota.',
      regulatoryNotes:
          'Subject to HPAI (highly pathogenic avian influenza) impacts — millions of turkeys culled during 2015 and 2022 outbreaks. Jennie-O recalled 91,000+ pounds of ground turkey in 2018 due to Salmonella concerns.',
      relatedBrands: ['Hormel', 'SPAM'],
    ),

    MeatBrandResult(
      brandName: 'Cargill Turkey',
      corporateParent: 'Cargill, Incorporated',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Turkey'],
      marketPosition: '#3 US turkey processor. Part of Cargill Protein.',
      plantCount: '3+ turkey processing facilities',
      keyPlantLocations: [
        'Springdale, Arkansas',
        'Harrisonburg, Virginia',
        'Dayton, Virginia',
      ],
      knownEstNumbers: ['45040', '374'],
      ownershipNotes:
          'Cargill\'s turkey operations are part of Cargill Protein, a division of privately held Cargill, Incorporated. Cargill sold its poultry business in 2019 to Continental Grain (now part of Wayne-Sanderson) but retained turkey operations.',
      regulatoryNotes: null,
      relatedBrands: ['Honeysuckle White', 'Shady Brook Farms'],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // PREMIUM / SPECIALTY
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    MeatBrandResult(
      brandName: 'Applegate',
      corporateParent: 'Hormel Foods Corporation',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Beef', 'Pork', 'Chicken', 'Turkey'],
      marketPosition:
          'Leading natural and organic processed meat brand. Part of Hormel.',
      plantCount: 'Contract manufacturing — does not operate own plants',
      keyPlantLocations: [
        'Bridgewater, New Jersey (headquarters — marketing/admin only)',
      ],
      knownEstNumbers: [],
      ownershipNotes:
          'Founded 1987 by Stephen McDonnell. Acquired by Hormel Foods in 2015. Positioned as Hormel\'s natural/organic brand. Products are Certified Humane, No Antibiotics Ever, and use organic ingredients. Uses contract manufacturers rather than own processing plants.',
      regulatoryNotes:
          'Certified Humane products. No Antibiotics Ever across all products. USDA Organic options available. One of the first major brands to eliminate nitrates/nitrites from processed meats.',
      relatedBrands: ['Hormel', 'Jennie-O'],
    ),

    MeatBrandResult(
      brandName: 'Niman Ranch',
      corporateParent: 'Perdue Farms, Inc.',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Beef', 'Pork', 'Lamb'],
      marketPosition:
          'Premium natural meat brand. Network of 700+ independent family farmers and ranchers.',
      plantCount: 'Uses Perdue and contract processing facilities',
      keyPlantLocations: ['Alameda, California (brand headquarters)'],
      knownEstNumbers: [],
      ownershipNotes:
          'Founded 1970s by Bill Niman in Bolinas, California. Acquired by Perdue Farms in 2015. Operates as a premium brand within Perdue\'s portfolio. Sources from a network of 700+ independent US family farmers and ranchers who follow strict protocols: no antibiotics ever, no hormones, no crates/cages, and pasture-based raising.',
      regulatoryNotes:
          'All Niman Ranch products are Certified Humane. No Antibiotics Ever. No Added Hormones. Animals raised on pasture by independent family farmers.',
      relatedBrands: ['Perdue', 'Coleman Natural'],
    ),

    MeatBrandResult(
      brandName: 'Oscar Mayer',
      corporateParent: 'Kraft Heinz Company',
      parentCountry: '🇺🇸 United States',
      isForeignOwned: false,
      species: ['Beef', 'Pork', 'Chicken', 'Turkey'],
      marketPosition:
          'Leading processed meats brand (hot dogs, lunch meats, bacon). Part of Kraft Heinz.',
      plantCount: '3+ US processing facilities',
      keyPlantLocations: [
        'Chicago, Illinois (Kraft Heinz HQ)',
        'Madison, Wisconsin (legacy Oscar Mayer plant — closed 2017)',
        'Kirksville, Missouri',
        'Davenport, Iowa',
      ],
      knownEstNumbers: ['3', '537', '4858'],
      ownershipNotes:
          'Founded 1883 by Oscar F. Mayer, a German immigrant, in Chicago. Acquired by General Foods in 1981, then Philip Morris/Kraft in 1989. Now part of Kraft Heinz Company (NASDAQ: KHC), formed from the 2015 merger of Kraft and H.J. Heinz (backed by Berkshire Hathaway and 3G Capital of Brazil).',
      regulatoryNotes:
          'Kraft Heinz is partially owned by 3G Capital, a Brazilian private equity firm. 3G Capital\'s cost-cutting approach led to significant workforce reductions across Kraft Heinz operations.',
      relatedBrands: ['Kraft Heinz', 'LUNCHABLES', 'Wienermobile'],
    ),
  ];
}
