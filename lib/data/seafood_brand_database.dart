// Ported from Seafoodbranddatabase.swift — pure Dart, no Flutter imports.

/// Result of a seafood brand lookup.
class SeafoodBrandResult {
  final String brandName;
  final String corporateParent;

  /// Country flag emoji + name.
  final String parentCountry;
  final bool isForeignOwned;

  /// MSC, ASC, BAP, etc.
  final List<String> certifications;

  /// What they sell.
  final List<String> primarySpecies;

  /// Where they source from.
  final String sourcingNotes;

  /// Corporate ownership context.
  final String ownershipNotes;

  // ── Expanded fields ──

  /// Known processing plant locations (city, state/country).
  final List<String> plantLocations;

  /// Fleet/vessel information — own fleet, contracted, or N/A.
  final String? fleetInfo;

  /// Primary sourcing regions/countries for raw material.
  final List<String> sourcingRegions;

  /// Farm or aquaculture sourcing details (for farm-raised products).
  final String? farmSourcing;

  /// URL to FDA enforcement lookup for this brand/parent on FAT website.
  /// null if no enforcement actions on file.
  final String? fdaEnforcementURL;

  /// Notable regulatory or legal history.
  final String? regulatoryNotes;

  const SeafoodBrandResult({
    required this.brandName,
    required this.corporateParent,
    required this.parentCountry,
    required this.isForeignOwned,
    required this.certifications,
    required this.primarySpecies,
    required this.sourcingNotes,
    required this.ownershipNotes,
    required this.plantLocations,
    this.fleetInfo,
    required this.sourcingRegions,
    this.farmSourcing,
    this.fdaEnforcementURL,
    this.regulatoryNotes,
  });
}

/// Local database of major US retail seafood brands.
/// Covers the brands consumers most commonly encounter at grocery stores.
class SeafoodBrandDatabase {
  /// Search for a seafood brand by name. Returns matches.
  ///
  /// Case-insensitive; matches against brandName, corporateParent, or any
  /// primarySpecies entry containing the trimmed/lowercased query.
  static List<SeafoodBrandResult> search(String query) {
    final lowered = query.toLowerCase().trim();
    if (lowered.isEmpty) return [];

    return all.where((brand) {
      return brand.brandName.toLowerCase().contains(lowered) ||
          brand.corporateParent.toLowerCase().contains(lowered) ||
          brand.primarySpecies
              .any((s) => s.toLowerCase().contains(lowered));
    }).toList();
  }

  /// Browse all brands (for display or scrolling).
  static const List<SeafoodBrandResult> all = [
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // FROZEN VALUE-ADDED SEAFOOD
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SeafoodBrandResult(
      brandName: "Gorton's",
      corporateParent: "Nippon Suisan Kaisha (Nissui)",
      parentCountry: "\u{1F1EF}\u{1F1F5} Japan",
      isForeignOwned: true,
      certifications: ["MSC (wild-caught)", "BAP (farmed shrimp)"],
      primarySpecies: ["Pollock", "Cod", "Haddock", "Shrimp", "Tilapia"],
      sourcingNotes:
          "Alaska pollock is primary whitefish. Shrimp sourced from BAP-certified farms in Ecuador and Asia. Over 99% of wild-caught fish from MSC-certified fisheries.",
      ownershipNotes:
          "Founded 1849 in Gloucester, MA as John Pew & Sons. Owned by General Mills (1968-1995), Unilever (1995-2001). Acquired by Nissui in 2001 for \$175M. Nissui is Japan's largest seafood conglomerate.",
      plantLocations: [
        "Gloucester, Massachusetts (flagship production hub)",
        "Lebanon, Indiana (opened Sept 2025 — \$89M value-added facility)"
      ],
      fleetInfo:
          "No company-owned fishing fleet. Sources through Nissui's global 'Global Links' supply chain spanning Asia, Europe, and the Americas.",
      sourcingRegions: [
        "Alaska (pollock)",
        "North Atlantic (cod, haddock)",
        "Ecuador (shrimp)",
        "Southeast Asia (shrimp, tilapia)"
      ],
      farmSourcing:
          "Farm-raised shrimp from BAP 4-star certified operations including Ecuador's Titi Shrimp Fishery Improvement Project.",
      fdaEnforcementURL: null,
      regulatoryNotes:
          "Nissui parent was linked to Japanese whaling in the Southern Ocean. Under pressure from environmental groups, Nissui withdrew support for whaling by 2006. Gorton's holds leading US market share in home-prepared frozen seafood.",
    ),

    SeafoodBrandResult(
      brandName: "Mrs. Paul's",
      corporateParent: "Nippon Suisan Kaisha (Nissui)",
      parentCountry: "\u{1F1EF}\u{1F1F5} Japan",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Pollock", "Cod", "Shrimp", "Clams"],
      sourcingNotes:
          "Fish sticks and fillets primarily use Alaska pollock. Sister brand to Van de Kamp's under the Nissui umbrella.",
      ownershipNotes:
          "Owned by Nissui through its US subsidiary. Acquired from Unilever as part of the Gorton's deal in 2001.",
      plantLocations: ["Gloucester, Massachusetts", "Lebanon, Indiana"],
      fleetInfo:
          "No company-owned fleet. Sources through Nissui's global supply chain.",
      sourcingRegions: [
        "Alaska (pollock)",
        "North Atlantic (cod)",
        "Gulf of Mexico (shrimp)"
      ],
      farmSourcing: null,
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Van de Kamp's",
      corporateParent: "Nippon Suisan Kaisha (Nissui)",
      parentCountry: "\u{1F1EF}\u{1F1F5} Japan",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Pollock", "Cod", "Shrimp"],
      sourcingNotes:
          "Fish sticks and fillets primarily use Alaska pollock. Sister brand to Mrs. Paul's.",
      ownershipNotes:
          "Originally a Southern California brand. Now part of Nissui's frozen seafood portfolio alongside Gorton's.",
      plantLocations: ["Gloucester, Massachusetts", "Lebanon, Indiana"],
      fleetInfo:
          "No company-owned fleet. Sources through Nissui's global supply chain.",
      sourcingRegions: ["Alaska (pollock)", "North Atlantic (cod)"],
      farmSourcing: null,
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Sea Cuisine",
      corporateParent: "High Liner Foods",
      parentCountry: "\u{1F1E8}\u{1F1E6} Canada",
      isForeignOwned: true,
      certifications: ["MSC (select products)", "ASC (select products)"],
      primarySpecies: ["Salmon", "Tilapia", "Shrimp", "Cod", "Haddock"],
      sourcingNotes:
          "Sources globally. High Liner purchases raw material from Canada, US, Europe, Asia, and South America. About 70% of revenue is from US operations.",
      ownershipNotes:
          "Retail brand of High Liner Foods (TSX: HLF). Founded 1899 in Lunenburg, Nova Scotia. Exited harvesting in 2004 after East Coast cod moratorium. Grew through acquisitions: Fishery Products International (2007), Viking Seafoods (2010), Icelandic Group (2011).",
      plantLocations: [
        "Lunenburg, Nova Scotia (flagship — est. 1964)",
        "Portsmouth, New Hampshire",
        "Newport News, Virginia",
        "Malden, Massachusetts",
        "New Bedford, Massachusetts"
      ],
      fleetInfo:
          "No company-owned fleet since 2004. Purchases globally from independent fisheries and aquaculture.",
      sourcingRegions: [
        "Canada (cod, haddock)",
        "Alaska (pollock)",
        "Norway (salmon)",
        "Chile (salmon)",
        "Asia (tilapia, shrimp)"
      ],
      farmSourcing:
          "Farm-raised salmon from Norway, Chile, and Canada. Farm-raised tilapia and shrimp from Asia and Latin America. Some products ASC certified.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "High Liner",
      corporateParent: "High Liner Foods",
      parentCountry: "\u{1F1E8}\u{1F1E6} Canada",
      isForeignOwned: true,
      certifications: ["MSC (select products)", "ASC (select products)"],
      primarySpecies: ["Cod", "Haddock", "Pollock", "Salmon", "Shrimp"],
      sourcingNotes:
          "One of North America's largest frozen seafood processors. Also sells under Fisher Boy, Mirabel, C. Wirthy, and Icelandic Seafood labels.",
      ownershipNotes:
          "High Liner Foods Inc. (TSX: HLF). Over 1,100 employees. 70% of revenue from US operations, 75% of US business is foodservice.",
      plantLocations: [
        "Lunenburg, Nova Scotia (flagship — est. 1964)",
        "Portsmouth, New Hampshire",
        "Newport News, Virginia",
        "Malden, Massachusetts",
        "New Bedford, Massachusetts"
      ],
      fleetInfo: "No company-owned fleet since 2004.",
      sourcingRegions: [
        "Canada",
        "Alaska",
        "Iceland",
        "Norway",
        "Chile",
        "Asia",
        "South America"
      ],
      farmSourcing:
          "Farm-raised products from ASC or BAP certified operations where available.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "SeaPak",
      corporateParent: "Rich Products Corporation",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["BAP (select products)"],
      primarySpecies: ["Shrimp", "Salmon", "Crab"],
      sourcingNotes:
          "Shrimp sourced primarily from Asia and Latin America. Some products carry BAP certification.",
      ownershipNotes:
          "Based in St. Simons Island, Georgia. Subsidiary of Rich Products Corporation, a privately held US food company in Buffalo, NY with \$4B+ annual revenue.",
      plantLocations: ["St. Simons Island, Georgia", "Brownsville, Texas"],
      fleetInfo:
          "No company-owned fleet. Sources from contracted farms and fisheries globally.",
      sourcingRegions: [
        "Southeast Asia (shrimp)",
        "Latin America (shrimp)",
        "Ecuador (shrimp)",
        "India (shrimp)"
      ],
      farmSourcing:
          "Farm-raised shrimp from BAP-certified aquaculture in Asia and Latin America.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Trident Seafoods",
      corporateParent: "Trident Seafoods Corporation",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["MSC (Alaska pollock, cod)"],
      primarySpecies: ["Pollock", "Cod", "Salmon", "Crab", "Surimi"],
      sourcingNotes:
          "Largest US seafood company. Primarily sources from Alaska fisheries. Vertically integrated — operates own fishing fleet and processing plants.",
      ownershipNotes:
          "Privately held, headquartered in Seattle, WA. Founded 1973 by Chuck Bundrant. ~9,000 employees globally. Currently restructuring: sold Kodiak plant to Pacific Seafood (2024), seeking buyers for select Alaska plants.",
      plantLocations: [
        "Seattle, Washington (HQ + R&D)",
        "Akutan, Alaska (largest seafood plant in North America — 1,400+ seasonal workers)",
        "Naknek, Alaska (Bristol Bay — 600+ seasonal)",
        "Wrangell, Alaska (salmon)",
        "Sand Point, Alaska",
        "Carrollton, Georgia (value-added)",
        "Motley, Minnesota (value-added)"
      ],
      fleetInfo:
          "Owns 2 catcher/processor vessels (300-312 ft), salmon tenders, freighters (Eastern Wind, Sea Trader), plus processing vessel Independence. Works with ~1,400 independent fishing vessels. Sold F/V Bountiful in 2024 as part of restructuring.",
      sourcingRegions: [
        "Alaska (pollock, cod, salmon, crab)",
        "Bering Sea",
        "Gulf of Alaska",
        "Bristol Bay"
      ],
      farmSourcing: null,
      fdaEnforcementURL:
          "https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/trident-seafoods-recalling-pacific-salmon-burger-public-notice",
      regulatoryNotes:
          "Major restructuring 2023-2025: selling select Alaska plants, reducing headcount 10%. Planning new facility at Captains Bay, Unalaska to replace aging Akutan plant. In March 2021 Trident Seafoods issued a public-notice recall for Pacific Salmon Burgers.",
    ),

    SeafoodBrandResult(
      brandName: "King & Prince Seafood",
      corporateParent: "Nippon Suisan Kaisha (Nissui)",
      parentCountry: "\u{1F1EF}\u{1F1F5} Japan",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Shrimp", "Pollock", "Cod", "Crab"],
      sourcingNotes:
          "Primarily serves foodservice/restaurant market. Part of Nissui's US portfolio with Gorton's, Mrs. Paul's, Van de Kamp's.",
      ownershipNotes: "Based in Brunswick, Georgia. Acquired by Nissui in 2005.",
      plantLocations: ["Brunswick, Georgia"],
      fleetInfo:
          "No company-owned fleet. Sources through Nissui's global supply chain.",
      sourcingRegions: [
        "Alaska (pollock, cod)",
        "Southeast Asia (shrimp)",
        "Latin America (shrimp)"
      ],
      farmSourcing: "Farm-raised shrimp from global aquaculture operations.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Fisher Boy",
      corporateParent: "High Liner Foods",
      parentCountry: "\u{1F1E8}\u{1F1E6} Canada",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Pollock", "Cod"],
      sourcingNotes:
          "Budget-friendly fish sticks and fillets. Part of High Liner's retail portfolio alongside Sea Cuisine.",
      ownershipNotes: "Retail brand of High Liner Foods (TSX: HLF).",
      plantLocations: [
        "Lunenburg, Nova Scotia",
        "Portsmouth, New Hampshire",
        "Newport News, Virginia"
      ],
      fleetInfo: "No company-owned fleet.",
      sourcingRegions: ["Alaska (pollock)", "North Atlantic (cod, haddock)"],
      farmSourcing: null,
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // CANNED / SHELF-STABLE SEAFOOD
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SeafoodBrandResult(
      brandName: "Bumble Bee Seafoods",
      corporateParent: "FCF Co., Ltd.",
      parentCountry: "\u{1F1F9}\u{1F1FC} Taiwan",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Tuna", "Salmon", "Sardines", "Mackerel", "Crab"],
      sourcingNotes:
          "Canned and pouched seafood. Also sells under Brunswick, Snow's, Beach Cliff, and Wild Selections brands. Clover Leaf in Canada. FCF has 30+ global subsidiaries.",
      ownershipNotes:
          "Founded 1899 in Astoria, Oregon. Filed bankruptcy Nov 2019 after price-fixing conviction. Acquired by FCF Co., Ltd. (Taiwan) in March 2020 for \$928M. FCF is the largest tuna supplier in the Western Pacific.",
      plantLocations: [
        "San Diego, California (headquarters)",
        "Santa Fe Springs, California (canning)",
        "FCF plants in Ghana and Papua New Guinea"
      ],
      fleetInfo:
          "FCF parent operates fishing bases in Pacific Island nations, Mauritius, Cape Town (South Africa), and Montevideo (Uruguay). 30+ global subsidiaries and fishing bases.",
      sourcingRegions: [
        "Pacific Ocean (tuna)",
        "Atlantic Ocean (tuna)",
        "Indian Ocean (tuna)",
        "NE US coast (herring/sardines)",
        "Pacific Islands"
      ],
      farmSourcing: null,
      fdaEnforcementURL: null,
      regulatoryNotes:
          "Former CEO convicted of criminal price-fixing conspiracy with Chicken of the Sea and StarKist (2010-2013). Paid \$25M criminal fine. Filed bankruptcy 2019. 2020 Greenpeace report linked FCF parent to illegal fishing and forced labor. In 2012 a worker died after being trapped in an industrial oven at the Santa Fe Springs plant.",
    ),

    SeafoodBrandResult(
      brandName: "Chicken of the Sea",
      corporateParent: "Thai Union Group",
      parentCountry: "\u{1F1F9}\u{1F1ED} Thailand",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Tuna", "Salmon", "Sardines", "Shrimp", "Crab"],
      sourcingNotes:
          "Canned and pouched seafood. Thai Union is the world's largest canned tuna producer with operations in 17 countries and \$4B+ annual revenue.",
      ownershipNotes:
          "Wholly owned subsidiary of Thai Union Group PCL (publicly traded in Thailand). Thai Union is the world's largest shelf-stable tuna processor.",
      plantLocations: [
        "San Diego, California (headquarters)",
        "Lyons, Georgia (US tuna processing — frozen loins shipped via Savannah)",
        "Thai Union facilities in Thailand, Seychelles, Ghana, Papua New Guinea"
      ],
      fleetInfo:
          "Thai Union operates and contracts fishing vessels globally. Subject to scrutiny over labor practices on fishing vessels in Southeast Asian waters.",
      sourcingRegions: [
        "Pacific Ocean (tuna)",
        "Indian Ocean (tuna)",
        "Atlantic Ocean (tuna)",
        "Thailand (shrimp)",
        "Southeast Asia"
      ],
      farmSourcing:
          "Farm-raised shrimp primarily from Thailand. Thai Union has own shrimp farming operations.",
      fdaEnforcementURL:
          "https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/avanti-frozen-foods-recalls-frozen-cooked-shrimp-because-possible-health-risk-0",
      regulatoryNotes:
          "Involved in 2010-2013 canned tuna price-fixing conspiracy. Thai Union parent has faced scrutiny over labor conditions on fishing vessels and in processing facilities in Southeast Asia. Chicken of the Sea frozen cooked shrimp named in June–August 2021 Avanti Frozen Foods recalls tied to a Salmonella Weltevreden outbreak; Avanti added to FDA Import Alert 16-120 (fish and fishery products; seafood HACCP) on March 4, 2025.",
    ),

    SeafoodBrandResult(
      brandName: "StarKist",
      corporateParent: "Dongwon Industries",
      parentCountry: "\u{1F1F0}\u{1F1F7} South Korea",
      isForeignOwned: true,
      certifications: ["MSC (select products)"],
      primarySpecies: ["Tuna", "Salmon", "Sardines", "Chicken"],
      sourcingNotes:
          "Canned and pouched tuna. American Samoa facility provides Buy American qualification under territorial exemptions from US minimum wage and Jones Act.",
      ownershipNotes:
          "Subsidiary of Dongwon Industries, a South Korean conglomerate (\$5B+ assets). Dongwon acquired StarKist from Del Monte Foods in 2008 for \$300M+. Founded 1917, HQ in Pittsburgh, PA.",
      plantLocations: [
        "Pittsburgh, Pennsylvania (headquarters)",
        "Pago Pago, American Samoa (primary tuna processing)",
        "Guayaquil, Ecuador",
        "Manta, Ecuador"
      ],
      fleetInfo:
          "Dongwon parent operates one of the world's largest tuna fishing fleets with extensive operations across the Pacific.",
      sourcingRegions: [
        "Western Pacific (tuna)",
        "Central Pacific (tuna)",
        "American Samoa",
        "Ecuador"
      ],
      farmSourcing: null,
      fdaEnforcementURL: null,
      regulatoryNotes:
          "Pleaded guilty in 2018 to price-fixing canned tuna (2011-2013). Paid \$55M+ in civil settlements. Postponed \$77M American Samoa plant expansion citing insufficient cash. Operates under exemptions to Nicholson and Jones Acts in American Samoa.",
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // OTHER BRANDS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SeafoodBrandResult(
      brandName: "Aqua Star",
      corporateParent: "Aqua Star Inc.",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["MSC (select products)", "BAP (select products)"],
      primarySpecies: ["Shrimp", "Salmon", "Tilapia", "Pollock"],
      sourcingNotes:
          "Sources globally from wild-caught and farm-raised operations.",
      ownershipNotes:
          "Privately held US company based in Seattle, Washington.",
      plantLocations: ["Seattle, Washington (headquarters)"],
      fleetInfo: "No company-owned fleet. Global supplier network.",
      sourcingRegions: [
        "Alaska (pollock, salmon)",
        "Southeast Asia (shrimp, tilapia)",
        "Latin America (shrimp)"
      ],
      farmSourcing:
          "Farm-raised shrimp and tilapia from BAP-certified operations.",
      fdaEnforcementURL:
          "https://www.fda.gov/safety/major-product-recalls/2025-recalls-frozen-shrimp-products-associated-cesium-137-contamination-pt-bahari-makmur-sejati-due",
      regulatoryNotes:
          "Multiple official FDA recalls (August–October 2025) for Aqua Star frozen shrimp products due to possible cesium-137 contamination tied to Indonesian processor PT. Bahari Makmur Sejati. FDA issued a public advisory on August 19, 2025. PT. Bahari Makmur Sejati added to Import Alert 99-51 (insanitary conditions / chemical contamination) on August 14, 2025 and Import Alert 99-52 (frozen shrimp, cesium-137) on October 3, 2025.",
    ),

    SeafoodBrandResult(
      brandName: "Johnny Seafood",
      corporateParent: "Johnny's Fine Foods",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: [],
      primarySpecies: ["Shrimp"],
      sourcingNotes:
          "Frozen breaded shrimp products. Sourcing details not widely disclosed.",
      ownershipNotes: "US-based food company.",
      plantLocations: ["Tacoma, Washington"],
      fleetInfo: "No company-owned fleet.",
      sourcingRegions: ["Asia (shrimp)", "Latin America (shrimp)"],
      farmSourcing:
          "Farm-raised shrimp — specific sources not publicly disclosed.",
      fdaEnforcementURL: null,
      regulatoryNotes:
          "No third-party sustainability certifications identified.",
    ),

    SeafoodBrandResult(
      brandName: "Sea Best",
      corporateParent: "Beaver Street Fisheries",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["BAP (select products)"],
      primarySpecies: ["Tilapia", "Salmon", "Shrimp", "Swai", "Catfish"],
      sourcingNotes:
          "One of the largest frozen seafood importers in the US. Tilapia and swai primarily from Asia and Latin America.",
      ownershipNotes:
          "Beaver Street Fisheries is privately held, based in Jacksonville, Florida.",
      plantLocations: ["Jacksonville, Florida (headquarters + cold storage)"],
      fleetInfo: "No company-owned fleet. Imports globally.",
      sourcingRegions: [
        "China (tilapia)",
        "Vietnam (swai/pangasius)",
        "Indonesia (shrimp)",
        "India (shrimp)",
        "US (catfish)"
      ],
      farmSourcing:
          "Farm-raised tilapia from China/Latin America. Farm-raised swai from Vietnam. Some BAP certified.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Blue Circle Foods",
      corporateParent: "Blue Circle Foods",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["ASC"],
      primarySpecies: ["Salmon"],
      sourcingNotes:
          "Specializes in responsibly farmed Atlantic salmon. ASC certified.",
      ownershipNotes:
          "US-based salmon company focused on responsible aquaculture.",
      plantLocations: ["Portland, Oregon"],
      fleetInfo: "No fishing fleet. Aquaculture-based.",
      sourcingRegions: [
        "Norway (salmon farms)",
        "Chile (salmon farms)",
        "Scotland (salmon farms)"
      ],
      farmSourcing:
          "All products are farm-raised Atlantic salmon from ASC-certified operations.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Vital Choice",
      corporateParent: "Vital Choice Wild Seafood & Organics",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["MSC"],
      primarySpecies: ["Salmon", "Tuna", "Halibut", "Sablefish", "Sardines"],
      sourcingNotes:
          "Specializes in wild-caught Alaskan and Pacific Northwest seafood. Direct-to-consumer. Founded by former Alaska commercial fisherman.",
      ownershipNotes:
          "Privately held, based in Bellingham, Washington.",
      plantLocations: ["Bellingham, Washington"],
      fleetInfo:
          "Sources from independent Alaska and Pacific NW fishing vessels. Founder is a former commercial fisherman with direct fleet relationships.",
      sourcingRegions: [
        "Alaska (salmon, halibut, sablefish)",
        "Pacific Northwest (salmon)",
        "Pacific Ocean (tuna, sardines)"
      ],
      farmSourcing: null,
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),

    SeafoodBrandResult(
      brandName: "Panamei Seafood",
      corporateParent: "Mazzetta Company",
      parentCountry: "\u{1F1FA}\u{1F1F8} United States",
      isForeignOwned: false,
      certifications: ["BAP (select products)"],
      primarySpecies: ["Shrimp", "Calamari", "Clams", "Mussels"],
      sourcingNotes:
          "Sources globally. One of the largest private-label seafood importers in North America.",
      ownershipNotes:
          "Mazzetta Company LLC, privately held, based in Des Plaines, Illinois.",
      plantLocations: ["Des Plaines, Illinois"],
      fleetInfo: "No company-owned fleet. Imports globally.",
      sourcingRegions: [
        "Southeast Asia (shrimp, calamari)",
        "Latin America (shrimp)",
        "Pacific (squid)",
        "New Zealand (mussels)"
      ],
      farmSourcing:
          "Farm-raised shrimp from BAP-certified operations.",
      fdaEnforcementURL: null,
      regulatoryNotes: null,
    ),
  ];
}
