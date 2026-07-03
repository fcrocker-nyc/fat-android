// Service-Case Seafood Capture Schema (v1.0)
//
// Dart port of the iOS `ServiceCaseSchema.swift`, itself the in-app encoding of
// the FAT Engineering Note "Service-Case Seafood Capture Schema" (companion to
// Seafood Research Series Paper No. 5):
// https://farmanimaltransparency.com/seafood-research-series-engineering-note-service-case-capture-schema/
//
// The data spec for loose seafood captured at a full-service counter, where
// there is no package to scan — only a USDA AMS placard. Governing rule,
// encoded below: report what the sign says, flag the species, and never confirm
// what a photo cannot prove (species identity stays `unverified`).

const String serviceCaseSchemaVersion = '1.0';

// ── Confidence vocabulary ────────────────────────────────────────────────────

/// The FAT disclosure vocabulary (known / partial / missing) plus the two
/// states the service case specifically requires (unverified / notApplicable).
enum ConfidenceState {
  known,
  partial,
  unverified,
  missing,
  notApplicable;

  String get label => switch (this) {
        ConfidenceState.known => 'known',
        ConfidenceState.partial => 'partial',
        ConfidenceState.unverified => 'unverified',
        ConfidenceState.missing => 'missing',
        ConfidenceState.notApplicable => 'not_applicable',
      };

  String get definition => switch (this) {
        ConfidenceState.known =>
          'A legally mandated fact captured legibly from the placard, or a hard key resolved to a record.',
        ConfidenceState.partial =>
          'Captured but ambiguous, or a named value that cannot be verified beyond the sign.',
        ConfidenceState.unverified =>
          'A claim a photo categorically cannot confirm; distinct from partial, and never auto-upgraded.',
        ConfidenceState.missing =>
          'A fact required in this venue but absent — a compliance signal.',
        ConfidenceState.notApplicable =>
          'The venue (or a processed item) is exempt, so absence is not a finding.',
      };

  String get appliesTo => switch (this) {
        ConfidenceState.known => 'origin, method, shellfish cert',
        ConfidenceState.partial => 'Seafood List name match',
        ConfidenceState.unverified => 'species identity',
        ConfidenceState.missing => 'origin/method at a covered retailer',
        ConfidenceState.notApplicable => 'exempt fishmonger / butcher / value-added',
      };
}

// ── Gate enums ───────────────────────────────────────────────────────────────

enum EstablishmentType {
  coveredRetailer,
  exemptFishmonger,
  exemptButcher,
  exemptFoodservice,
  unknown;

  /// COOL binds PACA-licensed retailers and exempts fish markets, butcher
  /// shops, and food-service establishments.
  bool get isCovered => this == EstablishmentType.coveredRetailer;

  String get display => switch (this) {
        EstablishmentType.coveredRetailer => 'Supermarket / covered retailer',
        EstablishmentType.exemptFishmonger => 'Fish market (exempt)',
        EstablishmentType.exemptButcher => 'Butcher shop (exempt)',
        EstablishmentType.exemptFoodservice => 'Food service (exempt)',
        EstablishmentType.unknown => 'Unknown',
      };
}

enum CategoryLane { fda, fsisSiluriformes, shellfishIcssl }

enum MethodOfProduction {
  wild,
  farmed,
  mixed;

  String get raw => switch (this) {
        MethodOfProduction.wild => 'WILD',
        MethodOfProduction.farmed => 'FARMED',
        MethodOfProduction.mixed => 'MIXED',
      };
}

enum PreviouslyFrozen { labeledPreviouslyFrozen, presentedFresh, unknown }

/// Resolution stops at the highest tier that fires; identity for any covered
/// case without a hard key terminates at the Tier 3 advisory because species
/// can never be photo-confirmed.
enum ResolutionTier {
  notApplicable,
  tier1Direct,
  tier3Advisory;

  String get raw => switch (this) {
        ResolutionTier.notApplicable => 'not_applicable',
        ResolutionTier.tier1Direct => 'tier1_direct',
        ResolutionTier.tier3Advisory => 'tier3_advisory',
      };
}

// ── Sub-structures ───────────────────────────────────────────────────────────

class SeafoodListMatch {
  final String? acceptableMarketName;
  final String? scientificName;
  final bool isAcceptableName;

  const SeafoodListMatch({
    this.acceptableMarketName,
    this.scientificName,
    required this.isAcceptableName,
  });

  /// The name maps, but the fish is unverified — always partial when matched.
  ConfidenceState get confidence =>
      acceptableMarketName == null ? ConfidenceState.missing : ConfidenceState.partial;
}

// ── The record ───────────────────────────────────────────────────────────────

class ServiceCaseRecord {
  // Gate
  EstablishmentType establishmentType;
  bool processedValueAdded;
  CategoryLane categoryLane;

  // Cluster A — mandated disclosure (COOL)
  List<String> countryOfOrigin;
  bool originLegible;
  MethodOfProduction? methodOfProduction;
  bool methodLegible;

  // Cluster B — identity
  String? marketNameDisplayed;
  SeafoodListMatch? seafoodListMatch;
  String? substitutionRiskBand; // high / moderate / low
  String? productForm;

  // Cluster B — on-device visual cross-check. A LOW-CONFIDENCE camera cue (ML Kit image
  // labeling), used only to corroborate or flag-mismatch the placard name — never to assert species.
  String? placardBroadType;
  bool placardIsSalmonid = false;
  String? visualObservation; // coarse label from the camera, e.g. "fish", "crab"
  double? visualConfidence; // 0..1
  String? visualCrossCheck; // corroborates / conflict / inconclusive / noFish / noPlacard

  // Cluster C — hard keys & context
  String? shellfishCertNumber;
  String? fsisEstablishmentNumber;
  PreviouslyFrozen previouslyFrozen;
  double? pricePerLb;

  ServiceCaseRecord({
    this.establishmentType = EstablishmentType.unknown,
    this.processedValueAdded = false,
    this.categoryLane = CategoryLane.fda,
    this.countryOfOrigin = const [],
    this.originLegible = false,
    this.methodOfProduction,
    this.methodLegible = false,
    this.marketNameDisplayed,
    this.seafoodListMatch,
    this.substitutionRiskBand,
    this.productForm,
    this.shellfishCertNumber,
    this.fsisEstablishmentNumber,
    this.previouslyFrozen = PreviouslyFrozen.unknown,
    this.pricePerLb,
  });

  /// Is a COOL placard owed here? Gates compliance scoring of Cluster A.
  bool get disclosureRequired => establishmentType.isCovered && !processedValueAdded;

  /// Species identity is the one field a photo can never confirm.
  ConfidenceState get speciesIdentityConfidence => ConfidenceState.unverified;

  /// Plain-language verdict for the sign-vs-camera cross-check.
  String get visualVerdict {
    switch (visualCrossCheck) {
      case 'corroborates':
        return 'Whole-fish view is consistent with the sign.';
      case 'conflict':
        return '⚠️ Whole-fish view does not match the sign — possible mislabeling.';
      case 'inconclusive':
        return 'Whole-fish view is inconclusive (low confidence).';
      case 'notWhole':
        return 'Whole fish only — this looks like a fillet or cut, so the visual check does not apply.';
      case 'noFish':
        return 'No whole fish detected — point the camera at the whole fish (not a fillet).';
      case 'noPlacard':
        return 'Visual read only — no market name read from the sign.';
      default:
        return '—';
    }
  }

  ConfidenceState _disclosureConfidence({required bool legible, required bool present}) {
    if (!disclosureRequired) return ConfidenceState.notApplicable;
    if (present && legible) return ConfidenceState.known;
    if (present) return ConfidenceState.partial;
    return ConfidenceState.missing;
  }

  ConfidenceState get originConfidence =>
      _disclosureConfidence(legible: originLegible, present: countryOfOrigin.isNotEmpty);

  ConfidenceState get methodConfidence =>
      _disclosureConfidence(legible: methodLegible, present: methodOfProduction != null);

  bool get hasHardKey =>
      (shellfishCertNumber != null && shellfishCertNumber!.isNotEmpty) ||
      (fsisEstablishmentNumber != null && fsisEstablishmentNumber!.isNotEmpty);

  bool get isImported =>
      countryOfOrigin.isNotEmpty &&
      !countryOfOrigin.every((c) => c.toUpperCase() == 'US');

  /// The gate runs first; a hard key closes identity directly; otherwise
  /// identity terminates at the Tier 3 advisory.
  ResolutionTier resolve() {
    if (!establishmentType.isCovered || processedValueAdded) {
      return ResolutionTier.notApplicable;
    }
    if (hasHardKey) return ResolutionTier.tier1Direct;
    return ResolutionTier.tier3Advisory;
  }

  /// Enforcement lanes attached to the final record.
  List<String> enforcementLanes() {
    if (resolve() == ResolutionTier.notApplicable) return const [];
    final lanes = <String>['ams_cool'];
    switch (categoryLane) {
      case CategoryLane.fda:
        lanes.add('fda_integrity');
      case CategoryLane.fsisSiluriformes:
        lanes.add('fsis');
      case CategoryLane.shellfishIcssl:
        lanes.add('icssl');
    }
    if (isImported) lanes.add('noaa_simp');
    return lanes;
  }

  /// Snapper fillet at a covered supermarket counter — the published worked
  /// example. Used by the Learn explainer.
  static ServiceCaseRecord get snapperWorkedExample => ServiceCaseRecord(
        establishmentType: EstablishmentType.coveredRetailer,
        categoryLane: CategoryLane.fda,
        countryOfOrigin: const ['US'],
        originLegible: true,
        methodOfProduction: MethodOfProduction.wild,
        methodLegible: true,
        marketNameDisplayed: 'Red Snapper',
        seafoodListMatch: const SeafoodListMatch(
          acceptableMarketName: 'snapper, red',
          scientificName: 'Lutjanus campechanus',
          isAcceptableName: true,
        ),
        substitutionRiskBand: 'high',
        productForm: 'fillet',
        previouslyFrozen: PreviouslyFrozen.presentedFresh,
        pricePerLb: 9.99,
      );
}

// ── OCR-text parser ──────────────────────────────────────────────────────────

/// Turns recognized placard text (+ the user-selected venue) into a
/// ServiceCaseRecord. Heuristic and conservative: it sets a field's "legible"
/// flag only when it is confident, so ambiguous captures fall to `partial`
/// rather than over-claiming `known`. Field-level user confirmation/editing is
/// a v1.1 open item.
class ServiceCaseParser {
  // Common market-name → (acceptable name, scientific name, specific?) map.
  // Specific=false marks non-specific / fraud-prone names (bare "sea bass",
  // bare "snapper") that resolve to a partial, non-acceptable match.
  // FDA Seafood List resolution table (displayed placard name -> [acceptable market name,
  // scientific name, specific?]). Curated to common U.S. counter species; scientific names given
  // only where confidently known. TODO: reconcile against the official FDA Seafood List before ship.
  static const Map<String, List<dynamic>> _seafoodList = {
    // Salmonids
    'atlantic salmon': ['salmon, Atlantic', 'Salmo salar', true],
    'sockeye salmon': ['salmon, sockeye', 'Oncorhynchus nerka', true],
    'coho salmon': ['salmon, coho', 'Oncorhynchus kisutch', true],
    'king salmon': ['salmon, Chinook', 'Oncorhynchus tshawytscha', true],
    'chinook salmon': ['salmon, Chinook', 'Oncorhynchus tshawytscha', true],
    'pink salmon': ['salmon, pink', 'Oncorhynchus gorbuscha', true],
    'chum salmon': ['salmon, chum', 'Oncorhynchus keta', true],
    'salmon': ['salmon', '', false],
    'steelhead': ['trout, rainbow', 'Oncorhynchus mykiss', true],
    'rainbow trout': ['trout, rainbow', 'Oncorhynchus mykiss', true],
    'trout': ['trout', '', false],
    'arctic char': ['char, Arctic', 'Salvelinus alpinus', true],
    'whitefish': ['whitefish, lake', 'Coregonus clupeaformis', true],
    // Tunas & mackerels
    'yellowfin tuna': ['tuna, yellowfin', 'Thunnus albacares', true],
    'ahi tuna': ['tuna, yellowfin', 'Thunnus albacares', true],
    'ahi': ['tuna, yellowfin', 'Thunnus albacares', true],
    'bigeye tuna': ['tuna, bigeye', 'Thunnus obesus', true],
    'bluefin tuna': ['tuna, bluefin', 'Thunnus thynnus', true],
    'albacore': ['tuna, albacore', 'Thunnus alalunga', true],
    'skipjack': ['tuna, skipjack', 'Katsuwonus pelamis', true],
    'tuna': ['tuna', '', false],
    'escolar': ['escolar', 'Lepidocybium flavobrunneum', true],
    'mackerel': ['mackerel', '', false],
    'atlantic mackerel': ['mackerel, Atlantic', 'Scomber scombrus', true],
    'spanish mackerel': ['mackerel, Spanish', 'Scomberomorus maculatus', true],
    'king mackerel': ['mackerel, king', 'Scomberomorus cavalla', true],
    'wahoo': ['wahoo', 'Acanthocybium solandri', true],
    // Cods, pollock & relatives
    'atlantic cod': ['cod, Atlantic', 'Gadus morhua', true],
    'pacific cod': ['cod, Pacific', 'Gadus macrocephalus', true],
    'cod': ['cod', '', false],
    'black cod': ['sablefish', 'Anoplopoma fimbria', true],
    'sablefish': ['sablefish', 'Anoplopoma fimbria', true],
    'lingcod': ['lingcod', 'Ophiodon elongatus', true],
    'haddock': ['haddock', 'Melanogrammus aeglefinus', true],
    'alaska pollock': ['pollock, Alaska', 'Gadus chalcogrammus', true],
    'pollock': ['pollock, Alaska', 'Gadus chalcogrammus', true],
    'whiting': ['whiting', '', false],
    'hake': ['hake', 'Merluccius', true],
    'monkfish': ['monkfish', 'Lophius americanus', true],
    'tilefish': ['tilefish', 'Lopholatilus chamaeleonticeps', true],
    'orange roughy': ['roughy, orange', 'Hoplostethus atlanticus', true],
    // Flatfish
    'pacific halibut': ['halibut, Pacific', 'Hippoglossus stenolepis', true],
    'atlantic halibut': ['halibut, Atlantic', 'Hippoglossus hippoglossus', true],
    'halibut': ['halibut', '', false],
    'petrale sole': ['sole, petrale', 'Eopsetta jordani', true],
    'dover sole': ['sole, Dover', '', false],
    'sole': ['sole', '', false],
    'flounder': ['flounder', '', false],
    'turbot': ['turbot', '', false],
    'plaice': ['plaice', '', false],
    // Snapper, grouper, bass, drum
    'red snapper': ['snapper, red', 'Lutjanus campechanus', true],
    'yellowtail snapper': ['snapper, yellowtail', 'Ocyurus chrysurus', true],
    'snapper': ['snapper', '', false],
    'red grouper': ['grouper, red', 'Epinephelus morio', true],
    'black grouper': ['grouper, black', 'Mycteroperca bonaci', true],
    'grouper': ['grouper', '', false],
    'black sea bass': ['sea bass, black', 'Centropristis striata', true],
    'chilean sea bass': ['seabass, Patagonian toothfish', 'Dissostichus eleginoides', true],
    'striped bass': ['bass, striped', 'Morone saxatilis', true],
    'branzino': ['bass, European', 'Dicentrarchus labrax', true],
    'sea bass': ['sea bass', '', false],
    'barramundi': ['barramundi', 'Lates calcarifer', true],
    'red drum': ['drum, red', 'Sciaenops ocellatus', true],
    'redfish': ['drum, red', 'Sciaenops ocellatus', true],
    'drum': ['drum', '', false],
    'croaker': ['croaker', '', false],
    'scup': ['scup', 'Stenotomus chrysops', true],
    'porgy': ['porgy', '', false],
    'rockfish': ['rockfish', 'Sebastes', true],
    'ocean perch': ['ocean perch', 'Sebastes', true],
    'yellow perch': ['perch, yellow', 'Perca flavescens', true],
    'perch': ['perch', '', false],
    'walleye': ['walleye', 'Sander vitreus', true],
    // Other finfish
    'mahi mahi': ['mahimahi', 'Coryphaena hippurus', true],
    'mahi-mahi': ['mahimahi', 'Coryphaena hippurus', true],
    'mahi': ['mahimahi', 'Coryphaena hippurus', true],
    'swordfish': ['swordfish', 'Xiphias gladius', true],
    'hamachi': ['yellowtail, Japanese', 'Seriola quinqueradiata', true],
    'yellowtail': ['yellowtail', 'Seriola', true],
    'amberjack': ['amberjack', 'Seriola', true],
    'pompano': ['pompano, Florida', 'Trachinotus carolinus', true],
    'bluefish': ['bluefish', 'Pomatomus saltatrix', true],
    'sardine': ['sardine', '', false],
    'anchovy': ['anchovy', 'Engraulis', true],
    'herring': ['herring', 'Clupea harengus', true],
    'smelt': ['smelt', '', false],
    'skate': ['skate', 'Raja', true],
    'tilapia': ['tilapia', 'Oreochromis', true],
    // Siluriformes (FSIS-regulated)
    'channel catfish': ['catfish, channel', 'Ictalurus punctatus', true],
    'catfish': ['catfish', 'Ictalurus', true],
    'basa': ['basa', 'Pangasius bocourti', true],
    'swai': ['swai', 'Pangasianodon hypophthalmus', true],
    'tra': ['tra', 'Pangasianodon hypophthalmus', true],
    'pangasius': ['pangasius', 'Pangasius', true],
    // Crustaceans
    'white shrimp': ['shrimp, white', 'Litopenaeus setiferus', true],
    'tiger shrimp': ['shrimp, tiger', 'Penaeus monodon', true],
    'shrimp': ['shrimp', '', false],
    'prawns': ['prawn', '', false],
    'prawn': ['prawn', '', false],
    'blue crab': ['crab, blue', 'Callinectes sapidus', true],
    'dungeness crab': ['crab, Dungeness', 'Metacarcinus magister', true],
    'king crab': ['crab, king', 'Paralithodes camtschaticus', true],
    'snow crab': ['crab, snow', 'Chionoecetes opilio', true],
    'crab': ['crab', '', false],
    'maine lobster': ['lobster, American', 'Homarus americanus', true],
    'spiny lobster': ['lobster, spiny', 'Panulirus', true],
    'lobster': ['lobster', '', false],
    'crawfish': ['crawfish', 'Procambarus clarkii', true],
    'crayfish': ['crayfish', 'Procambarus clarkii', true],
    // Molluscs
    'eastern oyster': ['oyster, Eastern', 'Crassostrea virginica', true],
    'pacific oyster': ['oyster, Pacific', 'Magallana gigas', true],
    'oyster': ['oyster', '', false],
    'littleneck clam': ['clam, littleneck', 'Mercenaria mercenaria', true],
    'quahog': ['clam, quahog', 'Mercenaria mercenaria', true],
    'clam': ['clam', '', false],
    'blue mussel': ['mussel, blue', 'Mytilus edulis', true],
    'mussel': ['mussel', '', false],
    'sea scallop': ['scallop, sea', 'Placopecten magellanicus', true],
    'bay scallop': ['scallop, bay', 'Argopecten irradians', true],
    'scallop': ['scallop', '', false],
    'calamari': ['squid', '', false],
    'squid': ['squid', '', false],
    'octopus': ['octopus', 'Octopus vulgaris', true],
  };

  static const List<String> _siluriformes = ['catfish', 'basa', 'swai', 'tra', 'pangasius'];
  static const List<String> _shellfish = ['oyster', 'clam', 'mussel', 'scallop', 'quahog'];
  static const List<String> _processedWords = [
    'breaded', 'marinated', 'seasoned', 'crab cake', 'stuffed', 'teriyaki', 'tempura', 'battered'
  ];
  static const List<String> _productForms = ['fillet', 'steak', 'whole', 'loin', 'portion'];

  // Country tokens seen on placards → normalized display.
  static const Map<String, String> _countryMap = {
    'usa': 'US', 'u.s.a': 'US', 'u.s.': 'US', 'us': 'US', 'united states': 'US',
    'america': 'US', 'domestic': 'US', 'chile': 'Chile', 'canada': 'Canada',
    'norway': 'Norway', 'vietnam': 'Vietnam', 'china': 'China', 'india': 'India',
    'mexico': 'Mexico', 'peru': 'Peru', 'ecuador': 'Ecuador', 'indonesia': 'Indonesia',
    'thailand': 'Thailand', 'scotland': 'Scotland', 'iceland': 'Iceland', 'russia': 'Russia',
    'japan': 'Japan', 'honduras': 'Honduras', 'argentina': 'Argentina',
  };

  static ServiceCaseRecord parse(String ocrText, EstablishmentType venue) {
    final lower = ocrText.toLowerCase();
    final r = ServiceCaseRecord(establishmentType: venue);

    // Processed / value-added gate.
    r.processedValueAdded = _processedWords.any(lower.contains);

    // Cluster A — origin.
    final origins = <String>[];
    _countryMap.forEach((token, norm) {
      if (RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(lower) && !origins.contains(norm)) {
        origins.add(norm);
      }
    });
    r.countryOfOrigin = origins;
    // Legible if an explicit origin cue is present.
    r.originLegible = origins.isNotEmpty &&
        (lower.contains('product of') || lower.contains('origin') ||
         lower.contains('caught in') || lower.contains('farmed in'));

    // Cluster A — method of production.
    final wild = lower.contains('wild');
    final farmed = lower.contains('farm') || lower.contains('aquacult');
    if (wild && farmed) {
      r.methodOfProduction = MethodOfProduction.mixed;
    } else if (wild) {
      r.methodOfProduction = MethodOfProduction.wild;
    } else if (farmed) {
      r.methodOfProduction = MethodOfProduction.farmed;
    }
    r.methodLegible = r.methodOfProduction != null;

    // Cluster B — market name (longest matching key wins, e.g. "red snapper").
    String? matchedKey;
    for (final key in _seafoodList.keys) {
      if (lower.contains(key) && (matchedKey == null || key.length > matchedKey.length)) {
        matchedKey = key;
      }
    }
    if (matchedKey != null) {
      r.marketNameDisplayed = _titleCase(matchedKey);
      final entry = _seafoodList[matchedKey]!;
      final specific = entry[2] as bool;
      r.seafoodListMatch = SeafoodListMatch(
        acceptableMarketName: entry[0] as String,
        scientificName: (entry[1] as String).isEmpty ? null : entry[1] as String,
        isAcceptableName: specific,
      );
      // Lane routing.
      if (_siluriformes.any(matchedKey.contains)) {
        r.categoryLane = CategoryLane.fsisSiluriformes;
      } else if (_shellfish.any(matchedKey.contains)) {
        r.categoryLane = CategoryLane.shellfishIcssl;
      } else {
        r.categoryLane = CategoryLane.fda;
      }
      // Substitution-risk prior (documented mislabeling-prone groups — Oceana studies, FDA RPM).
      const high = ['snapper', 'tuna', 'escolar', 'grouper', 'sea bass', 'cod', 'halibut',
                    'sole', 'salmon', 'yellowtail', 'tilefish', 'wahoo', 'mahi', 'king mackerel',
                    'white tuna'];
      r.substitutionRiskBand = high.any(matchedKey.contains) ? 'high' : 'moderate';
      r.placardBroadType = _coarseType(matchedKey);
      r.placardIsSalmonid =
          ['salmon', 'trout', 'char', 'steelhead'].any(matchedKey.contains);
    }

    // Product form.
    for (final f in _productForms) {
      if (lower.contains(f)) { r.productForm = f; break; }
    }

    // Cluster C — previously frozen.
    if (lower.contains('previously frozen')) {
      r.previouslyFrozen = PreviouslyFrozen.labeledPreviouslyFrozen;
    } else if (lower.contains('fresh')) {
      r.previouslyFrozen = PreviouslyFrozen.presentedFresh;
    }

    // Cluster C — price ($x.xx /lb).
    final priceM = RegExp(r'\$?\s*(\d{1,3}\.\d{2})\s*/?\s*l?b?').firstMatch(lower);
    if (priceM != null) r.pricePerLb = double.tryParse(priceM.group(1)!);

    // Cluster C — shellfish cert (state tag, e.g. "MA 123 SS" / "WA-1234-SP").
    final certM = RegExp(r'\b([A-Z]{2})[- ]?(\d{2,4})[- ]?(SS|SP)\b').firstMatch(ocrText);
    if (certM != null) r.shellfishCertNumber = certM.group(0);

    // Cluster C — FSIS establishment legend (rare on a loose case).
    final estM = RegExp(r'\b(?:EST|P)[. ]?\s*(\d{2,5})\b').firstMatch(ocrText.toUpperCase());
    if (estM != null) r.fsisEstablishmentNumber = estM.group(0);

    return r;
  }

  static String _titleCase(String s) =>
      s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  // Coarse animal type a phone camera can plausibly discriminate (finfish vs the shellfish
  // types). Deliberately NOT species-level — the visual pass is a mislabeling cross-check.
  static String coarseType(String key) {
    final k = key.toLowerCase();
    if (['oyster', 'clam', 'mussel', 'scallop', 'quahog'].any(k.contains)) return 'mollusk';
    if (k.contains('crab')) return 'crab';
    if (k.contains('lobster')) return 'lobster';
    if (['shrimp', 'prawn', 'crawfish', 'crayfish'].any(k.contains)) return 'shrimp';
    if (['squid', 'calamari', 'octopus', 'cuttlefish'].any(k.contains)) return 'cephalopod';
    return 'finfish';
  }

  static String _coarseType(String key) => coarseType(key);

  /// Merge the on-device visual read into a parsed record and cross-check it against the resolved
  /// placard name. The visual read is a LOW-CONFIDENCE cue: it can flag a broad-type mismatch
  /// (sign says "crab", camera sees a finfish) but never asserts a species.
  static void applyVisual(VisualRead? v, ServiceCaseRecord r) {
    if (v == null) {
      r.visualCrossCheck = 'noFish';
      return;
    }
    r.visualObservation = v.display;
    r.visualConfidence = v.confidence;
    // Whole fish only: a fillet, steak, or cut cannot be visually cross-checked.
    if (v.broadType == 'cut') {
      r.visualCrossCheck = 'notWhole';
      return;
    }
    final placard = r.placardBroadType;
    if (placard == null) {
      r.visualCrossCheck = 'noPlacard';
      return;
    }
    final strong = v.confidence >= 0.45;
    final sameBroad = v.broadType == placard ||
        (['crab', 'lobster', 'shrimp'].contains(v.broadType) &&
            ['crab', 'lobster', 'shrimp'].contains(placard) &&
            !strong);
    if (!sameBroad) {
      if (strong) {
        r.visualCrossCheck = 'conflict';
        r.substitutionRiskBand = 'high';
      } else {
        r.visualCrossCheck = 'inconclusive';
      }
    } else if (v.fineTag == 'salmon' &&
        r.placardIsSalmonid == false &&
        strong &&
        (r.seafoodListMatch?.isAcceptableName ?? false)) {
      r.visualCrossCheck = 'conflict';
      r.substitutionRiskBand = 'high';
    } else {
      r.visualCrossCheck = 'corroborates';
    }
  }
}

/// Low-confidence on-device visual read of a WHOLE fish (ML Kit image labeling).
/// broadType: finfish / crab / lobster / shrimp / cephalopod / mollusk / cut.
class VisualRead {
  final String display; // human label, e.g. "fish", "crab", "salmon"
  final String broadType;
  final String? fineTag; // "salmon" when discriminable; else null
  final double confidence; // 0..1
  const VisualRead(this.display, this.broadType, this.fineTag, this.confidence);
}
