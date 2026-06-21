// SeafoodInterpreter — Flutter port of iOS Seafoodinterpreter.swift.
// Evaluates OCR text against the 16 FAT seafood transparency categories and
// grades Category 13 (Enforcement & Compliance) via the shared brand-data feed.

import '../models/fat_models.dart';
import '../data/brand_resolver.dart';

class SeafoodInterpretation {
  final Map<SeafoodCategory, FATCategoryResult> categories;
  final String? detectedEstablishmentNumber;
  final bool isSiluriformes;
  final SeafoodProductionMethod? productionMethod;

  const SeafoodInterpretation({
    required this.categories,
    required this.detectedEstablishmentNumber,
    required this.isSiluriformes,
    required this.productionMethod,
  });
}

class SeafoodInterpreter {
  static SeafoodInterpretation interpret(String scannedText) {
    final text = scannedText
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final isCatfish = _detectSiluriformes(text);
    final method = _detectProductionMethod(text);
    final est = isCatfish ? extractEstablishmentNumber(text) : null;

    final cats = <SeafoodCategory, FATCategoryResult>{
      SeafoodCategory.regulatoryRequiredLanguage: _regulatory(text, isCatfish),
      SeafoodCategory.speciesIdentity: _species(text),
      SeafoodCategory.strainVariety: _strain(text),
      SeafoodCategory.countryOrigin: _country(text),
      SeafoodCategory.farmVesselFishery: _farmVessel(text),
      SeafoodCategory.processor: _processor(isCatfish, est),
      SeafoodCategory.productionMethodFeed: _methodFeed(text, method),
      SeafoodCategory.animalWelfare: _welfare(text),
      SeafoodCategory.qualityHandling: _quality(text),
      SeafoodCategory.dietaryAttributesAdditives: _dietary(text),
      SeafoodCategory.medicineAntibioticsChemicals: _medicine(text),
      SeafoodCategory.ageAtHarvest: const FATCategoryResult(status: DisclosureStatus.missing),
      SeafoodCategory.enforcementCompliance: _enforcement(scannedText, isCatfish),
      SeafoodCategory.supplyChainIntermediary: _supplyChain(text),
      SeafoodCategory.environmentalImpact: const FATCategoryResult(status: DisclosureStatus.missing),
      SeafoodCategory.economicConcentration: const FATCategoryResult(status: DisclosureStatus.missing),
    };

    return SeafoodInterpretation(
      categories: cats,
      detectedEstablishmentNumber: est,
      isSiluriformes: isCatfish,
      productionMethod: method,
    );
  }

  // ── Routing helper ──
  static bool isSeafood(String scannedText) {
    final t = scannedText.toLowerCase();
    const keywords = [
      'salmon', 'tilapia', 'cod', 'tuna', 'trout', 'bass', 'halibut',
      'mahi mahi', 'mahi-mahi', 'swordfish', 'snapper', 'grouper', 'pollock',
      'haddock', 'sole', 'flounder', 'sardine', 'anchovy', 'mackerel',
      'herring', 'perch', 'walleye', 'pike', 'pangasius', 'swai', 'basa',
      'catfish', 'branzino', 'barramundi', 'rockfish', 'mahi', 'ahi',
      'yellowtail', 'amberjack', 'wahoo', 'monkfish', 'orange roughy',
      'arctic char', 'char', 'shrimp', 'prawns', 'crab', 'lobster', 'clam',
      'mussel', 'oyster', 'scallop', 'squid', 'calamari', 'octopus',
      'crawfish', 'crayfish', 'seafood', 'fish fillet', 'fish stick',
      'fish cake', 'fish portion', 'surimi', 'siluriformes', 'ictalurus',
    ];
    return keywords.any(t.contains);
  }

  // ── Detection ──
  static bool _detectSiluriformes(String t) {
    const k = [
      'catfish', 'channel catfish', 'blue catfish', 'siluriformes',
      'ictalurus', 'pangasius', 'swai', 'basa', 'tra fish', 'striped pangasius',
    ];
    return k.any(t.contains);
  }

  static SeafoodProductionMethod? _detectProductionMethod(String t) {
    const wild = [
      'wild caught', 'wild-caught', 'wild harvest', 'line caught',
      'line-caught', 'net caught', 'trawl caught', 'pole caught',
      'pole-caught', 'ocean caught', 'sea caught', 'wild alaska',
      'wild pacific', 'wild atlantic',
    ];
    if (wild.any(t.contains)) return SeafoodProductionMethod.wildCaught;
    const farm = [
      'farm raised', 'farm-raised', 'aquaculture', 'pond raised',
      'pond-raised', 'responsibly farmed', 'sustainably farmed',
    ];
    if (farm.any(t.contains)) return SeafoodProductionMethod.farmRaised;
    return null;
  }

  static FATCategoryResult _regulatory(String t, bool isCatfish) {
    if (isCatfish) {
      const fsis = [
        'inspected and passed', 'inspected & passed',
        'department of agriculture', 'usda inspected',
        'federally inspected', 'inspected for wholesomeness',
      ];
      if (fsis.any(t.contains)) {
        return const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'USDA/FSIS inspection language detected');
      }
      if (extractEstablishmentNumber(t) != null) {
        return const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'USDA establishment number detected');
      }
      return const FATCategoryResult(status: DisclosureStatus.missing);
    }
    return const FATCategoryResult(
      status: DisclosureStatus.notRequired,
      value:
          'FDA-regulated seafood — no processor registration number or HACCP compliance mark is required on retail consumer packaging.',
    );
  }

  static FATCategoryResult _species(String t) {
    const species = <String, String>{
      'atlantic salmon': 'Atlantic Salmon', 'sockeye salmon': 'Sockeye Salmon',
      'king salmon': 'King Salmon', 'coho salmon': 'Coho Salmon',
      'pink salmon': 'Pink Salmon', 'chum salmon': 'Chum Salmon',
      'salmon': 'Salmon', 'tilapia': 'Tilapia', 'atlantic cod': 'Atlantic Cod',
      'pacific cod': 'Pacific Cod', 'cod': 'Cod', 'albacore': 'Albacore Tuna',
      'yellowfin tuna': 'Yellowfin Tuna', 'ahi tuna': 'Ahi Tuna',
      'skipjack': 'Skipjack Tuna', 'tuna': 'Tuna', 'shrimp': 'Shrimp',
      'prawns': 'Prawns', 'crab': 'Crab', 'lobster': 'Lobster',
      'channel catfish': 'Channel Catfish', 'catfish': 'Catfish',
      'rainbow trout': 'Rainbow Trout', 'trout': 'Trout',
      'chilean sea bass': 'Chilean Sea Bass', 'sea bass': 'Sea Bass',
      'striped bass': 'Striped Bass', 'bass': 'Bass', 'halibut': 'Halibut',
      'mahi mahi': 'Mahi Mahi', 'mahi-mahi': 'Mahi Mahi', 'swordfish': 'Swordfish',
      'red snapper': 'Red Snapper', 'snapper': 'Snapper', 'grouper': 'Grouper',
      'alaska pollock': 'Alaska Pollock', 'pollock': 'Pollock',
      'haddock': 'Haddock', 'dover sole': 'Dover Sole', 'sole': 'Sole',
      'flounder': 'Flounder', 'sardine': 'Sardine', 'anchovy': 'Anchovy',
      'mackerel': 'Mackerel', 'herring': 'Herring', 'pangasius': 'Pangasius',
      'swai': 'Swai', 'basa': 'Basa', 'clam': 'Clam', 'mussel': 'Mussel',
      'oyster': 'Oyster', 'scallop': 'Scallop', 'squid': 'Squid',
      'calamari': 'Calamari', 'octopus': 'Octopus', 'surimi': 'Surimi',
    };
    final keys = species.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (t.contains(k)) {
        return FATCategoryResult(status: DisclosureStatus.known, value: species[k]);
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  static FATCategoryResult _strain(String t) {
    const strain = <String, String>{
      'atlantic salmon': 'Atlantic Salmon (Salmo salar)',
      'sockeye': 'Sockeye (Oncorhynchus nerka)',
      'chinook': 'Chinook (Oncorhynchus tshawytscha)',
      'coho': 'Coho (Oncorhynchus kisutch)',
      'channel catfish': 'Channel Catfish (Ictalurus punctatus)',
      'blue catfish': 'Blue Catfish (Ictalurus furcatus)',
      'rainbow trout': 'Rainbow Trout (Oncorhynchus mykiss)',
      'alaska pollock': 'Alaska Pollock (Gadus chalcogrammus)',
    };
    final keys = strain.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (t.contains(k)) {
        return FATCategoryResult(status: DisclosureStatus.known, value: strain[k]);
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  static FATCategoryResult _country(String t) {
    const patterns = <String, String>{
      'product of usa': 'Product of USA',
      'product of united states': 'Product of United States',
      'product of china': 'Product of China',
      'product of indonesia': 'Product of Indonesia',
      'product of vietnam': 'Product of Vietnam',
      'product of thailand': 'Product of Thailand',
      'product of chile': 'Product of Chile',
      'product of canada': 'Product of Canada',
      'product of norway': 'Product of Norway',
      'product of ecuador': 'Product of Ecuador',
      'product of india': 'Product of India',
      'wild alaska': 'Wild Alaska (USA)',
      'made in usa': 'Made in USA',
      'imported': 'Imported (country not specified)',
    };
    final keys = patterns.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (t.contains(k)) {
        return FATCategoryResult(status: DisclosureStatus.known, value: patterns[k]);
      }
    }
    for (final p in ['distributed by', 'packed in', 'processed in']) {
      if (t.contains(p)) {
        return const FATCategoryResult(
            status: DisclosureStatus.partial,
            value: 'Processing location disclosed, but country of origin unclear');
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  static FATCategoryResult _farmVessel(String t) {
    const patterns = <String, String>{
      'vessel': 'Vessel name disclosed',
      'fishery': 'Fishery disclosed',
      'family farm': 'Family farm disclosed',
      'responsibly sourced': 'Responsibly Sourced',
    };
    for (final e in patterns.entries) {
      if (t.contains(e.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: e.value,
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote: 'No independent verification identified',
        );
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  static FATCategoryResult _processor(bool isCatfish, String? est) {
    if (isCatfish) {
      if (est != null) {
        return FATCategoryResult(
            status: DisclosureStatus.known, value: 'USDA EST. $est');
      }
      return const FATCategoryResult(status: DisclosureStatus.missing);
    }
    return const FATCategoryResult(
      status: DisclosureStatus.notRequired,
      value:
          'FDA-regulated seafood — FDA facility registration numbers are internal administrative records and do not appear on retail consumer packaging.',
    );
  }

  static FATCategoryResult _methodFeed(String t, SeafoodProductionMethod? m) {
    if (m == null) return const FATCategoryResult(status: DisclosureStatus.missing);
    if (m == SeafoodProductionMethod.wildCaught) {
      for (final g in ['line caught', 'line-caught', 'pole caught', 'pole-caught',
        'trawl', 'longline', 'gillnet', 'purse seine', 'hook and line']) {
        if (t.contains(g)) {
          return FATCategoryResult(status: DisclosureStatus.known, value: 'Wild-Caught ($g)');
        }
      }
      return const FATCategoryResult(status: DisclosureStatus.known, value: 'Wild-Caught');
    }
    return const FATCategoryResult(status: DisclosureStatus.known, value: 'Farm-Raised');
  }

  static FATCategoryResult _welfare(String t) {
    const certs = <String, List<String>>{
      'asc certified': ['ASC Certified', 'Third-party certified by Aquaculture Stewardship Council'],
      'asc': ['ASC Certified', 'Third-party certified by Aquaculture Stewardship Council'],
      'global gap': ['GlobalGAP Certified', 'Third-party certified — includes aquaculture welfare standards'],
      'bap certified': ['BAP Certified', 'Best Aquaculture Practices certification'],
      'bap': ['BAP Certified', 'Best Aquaculture Practices certification'],
    };
    final keys = certs.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (t.contains(k)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: certs[k]![0],
          credibility: ClaimCredibility.verified,
          credibilityNote: certs[k]![1],
        );
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  static FATCategoryResult _quality(String t) {
    final found = <String>[];
    if (t.contains('previously frozen')) {
      found.add('Previously Frozen');
    } else if (t.contains('frozen')) {
      found.add('Frozen');
    } else if (t.contains('fresh')) {
      found.add('Fresh');
    }
    if (t.contains('thawed')) found.add('Thawed for Sale');
    if (t.contains('sashimi grade') || t.contains('sushi grade')) found.add('Sashimi/Sushi Grade');
    if (found.isEmpty) return const FATCategoryResult(status: DisclosureStatus.missing);
    return FATCategoryResult(status: DisclosureStatus.known, value: found.join(', '));
  }

  static FATCategoryResult _dietary(String t) {
    final factual = <String>[];
    final marketing = <String>[];
    if (t.contains('sodium tripolyphosphate') || t.contains('stpp')) factual.add('STPP (phosphate glaze)');
    if (t.contains('added water')) factual.add('Added Water');
    if (t.contains('no artificial')) marketing.add('No Artificial Ingredients');
    if (t.contains('no preservative')) marketing.add('No Preservatives');
    if (t.contains('gluten free') || t.contains('gluten-free')) marketing.add('Gluten Free');
    final all = [...factual, ...marketing];
    if (all.isEmpty) return const FATCategoryResult(status: DisclosureStatus.missing);
    if (marketing.isEmpty) {
      return FATCategoryResult(status: DisclosureStatus.known, value: all.join(', '));
    }
    return FATCategoryResult(
      status: DisclosureStatus.known,
      value: all.join(', '),
      credibility: ClaimCredibility.labelClaimOnly,
      credibilityNote: 'Label claim — no independent verification identified',
    );
  }

  static FATCategoryResult _medicine(String t) {
    const patterns = <String, List<String>>{
      'antibiotic free': ['Antibiotic Free', 'Label claim — no independent audit identified'],
      'antibiotic-free': ['Antibiotic Free', 'Label claim — no independent audit identified'],
      'no antibiotics': ['No Antibiotics', 'Label claim — no independent audit identified'],
      'no hormones': ['No Hormones', 'Label claim — hormones are not approved for use in fish in the US'],
    };
    for (final e in patterns.entries) {
      if (t.contains(e.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: e.value[0],
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote: e.value[1],
        );
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  // 13. Enforcement & Compliance — graded by event type + recency from the feed.
  static FATCategoryResult _enforcement(String scannedText, bool isCatfish) {
    if (isCatfish) {
      // FSIS — handled by the EST processor lookup.
      return const FATCategoryResult(status: DisclosureStatus.missing);
    }
    final resolution = BrandResolver.instance.resolve(scannedText);
    if (resolution == null) {
      return const FATCategoryResult(
        status: DisclosureStatus.notRequired,
        value:
            'SIMP (Seafood Import Monitoring Program) requires harvest and chain-of-custody records for 13 specific high-risk imported species. It does not apply to domestic seafood or most imported species. No equivalent federal traceability program exists for most retail seafood.',
      );
    }
    if (resolution.shouldSuppressFdaLookup) {
      return FATCategoryResult(
        status: DisclosureStatus.missing,
        value:
            'No public FDA enforcement bridge for ${resolution.matchedBrand} (responsible company: ${resolution.primaryResponsibleCompany}). Absence of a public match is not evidence of a clean record.',
      );
    }
    final summary = BrandResolver.instance.enforcementSummary(resolution);
    if (summary == null) {
      return FATCategoryResult(
        status: DisclosureStatus.partial,
        value:
            'Public FDA enforcement bridge exists for ${resolution.primaryResponsibleCompany}, but no enforcement actions appear in the current 2023–2026 dataset. Older actions may exist outside this window.',
        credibility: ClaimCredibility.usdaApproved,
        credibilityNote: 'FAT brand→FDA bridge; no in-window public events.',
      );
    }
    return FATCategoryResult(
      status: summary.hasHighSeverity ? DisclosureStatus.known : DisclosureStatus.partial,
      value: summary.displayText,
      credibility: ClaimCredibility.usdaApproved,
      credibilityNote: summary.recencyNote,
    );
  }

  static FATCategoryResult _supplyChain(String t) {
    const patterns = <String, String>{
      'imported by': 'Importer named on label',
      'importer': 'Importer named on label',
      'distributed by': 'Distributor named on label',
      'distributor': 'Distributor named on label',
      'aggregator': 'Aggregator referenced on label',
      'cooperative': 'Producer cooperative referenced on label',
      'grow-out': 'Grow-out operation referenced on label',
      'grow out': 'Grow-out operation referenced on label',
    };
    for (final e in patterns.entries) {
      if (t.contains(e.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.partial,
          value: '${e.value}; captivity/ownership relationship not stated — see FAT supply-chain map.',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote: 'No independent verification identified',
        );
      }
    }
    return const FATCategoryResult(status: DisclosureStatus.missing);
  }

  // ── EST extraction (catfish) ──
  static String? extractEstablishmentNumber(String text) {
    final patterns = [
      RegExp(r'(?:usda\s{0,2})?est\.?\s{0,2}(\d{1,6})', caseSensitive: false),
      RegExp(r'establishment\s{0,3}(?:number\s{0,3})?(?:#\s{0,2})?(\d{1,6})', caseSensitive: false),
      RegExp(r'est#\s{0,2}(\d{1,6})', caseSensitive: false),
      RegExp(r'p-(\d{1,6})', caseSensitive: false),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null && m.groupCount >= 1) {
        final raw = m.group(1)!;
        final n = int.tryParse(raw);
        if (n != null && n > 0 && n < 999999 && raw.length <= 6) return raw;
      }
    }
    return null;
  }
}
