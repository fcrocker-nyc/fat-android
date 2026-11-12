// Prepared / Multi-Ingredient lane — detection + category transform.
//
// A canned beef stew, frozen pepperoni pizza, or chicken noodle soup is not a
// single-animal product, and the 16-category meat model mis-scores it two ways:
// per-animal categories (breed, age, feed, welfare, medicine, hormones, farm)
// read as transparency failures when no U.S. labeling regulation requires a
// prepared-food maker to disclose them for ingredient meat; and a product below
// the FSIS meat-content thresholds (~3% raw / 2% cooked) is FDA-regulated —
// it legally carries NO USDA legend and NO establishment number, so the red
// "missing EST" banner would be a false compliance accusation.
//
// This lane mirrors the retail-exemption precedent: inapplicable categories
// go `.notRequired` (blue light, out of the denominator), voluntary
// disclosures keep their credit, and the jurisdiction fork mirrors the
// Siluriformes FSIS/FDA split on the seafood side.

import '../models/fat_models.dart';

class PreparedFoodContext {
  final bool isPrepared;

  /// Distinct meat/poultry species named on the label (display-cased).
  final List<String> speciesMentioned;

  /// What triggered detection — for debugging / future UI.
  final List<String> signals;

  const PreparedFoodContext({
    required this.isPrepared,
    this.speciesMentioned = const [],
    this.signals = const [],
  });

  static const none = PreparedFoodContext(isPrepared: false);
}

class PreparedFoodDetector {
  PreparedFoodDetector._();

  // Product-identity words that name a multi-ingredient prepared food.
  static const List<String> _identityWords = [
    'stew', 'soup', 'pizza', 'entree', 'entrée', 'tv dinner', 'pot pie',
    'burrito', 'ravioli', 'lasagna', 'lasagne', 'casserole', 'dumpling',
    'egg roll', 'eggroll', 'taquito', 'tamale', 'enchilada', 'empanada',
    'chili with beans', 'chili con carne', 'corn dog', 'gumbo', 'jambalaya',
    'fried rice', 'chow mein', 'lo mein', 'stroganoff', 'goulash',
    'noodle bowl', 'skillet meal', 'stuffed pepper', 'shepherds pie',
    "shepherd's pie", 'quesadilla', 'calzone', 'stromboli', 'pierogi',
    'wonton', 'spring roll', 'meat sauce', 'bolognese', 'sloppy joe',
  ];

  // Raw-cut phrases that contain an identity word but are single-animal
  // products (e.g. "Beef Stew Meat" is a whole-muscle cut, not a stew).
  static const List<String> _identityGuards = [
    'stew meat', 'for stew', 'stew beef', 'soup bones', 'for soup',
    'soup meat',
  ];

  // Non-protein component foods that mark a multi-ingredient formulation.
  static const List<String> _componentFoods = [
    'potato', 'carrot', 'tomato', 'celery', 'rice', 'pasta', 'noodle',
    'macaroni', 'bean', 'peas', 'corn', 'cheese', 'crust', 'dough',
    'tortilla', 'bread', 'breading', 'batter', 'gravy', 'broth', 'stock',
    'flour', 'milk', 'cream', 'vegetable',
  ];

  // Species keyword groups — whole-word matched so "ham" never fires inside
  // "hamburger" and "lamb" never fires inside "lambert".
  static const Map<String, List<String>> _speciesKeywords = {
    'Beef': ['beef'],
    'Pork': ['pork', 'bacon', 'ham', 'pepperoni', 'prosciutto', 'chorizo'],
    'Chicken': ['chicken'],
    'Turkey': ['turkey'],
    'Lamb': ['lamb'],
    'Veal': ['veal'],
    'Bison': ['bison'],
  };

  // USDA/FSIS inspection-legend phrases (same family the interpreters use).
  static const List<String> _fsisLegend = [
    'inspected and passed', 'inspected & passed', 'u.s. inspected',
    'us inspected', 'department of agriculture', 'usda inspected',
    'federally inspected', 'inspected for wholesomeness',
  ];

  // Lane gate: the word "ingredients" followed by a comma list.
  static final RegExp _ingredientGate =
      RegExp(r'ingredients\b[\s\S]{0,200}?,[\s\S]{0,120}?,');

  // OCR-tolerant form for the meter-card line only: "INGREDlENTS:",
  // "1ngredients", singular "Ingredient:" — followed by a list (a comma).
  static final RegExp _ingredientOcrTolerant =
      RegExp(r'(?<![a-z])[il1|!]ngred[il1|!]ents?\b\s*[:;.]?[\s\S]{0,200}?,');

  /// True when the scanned text contains an ingredients statement. Reuses the
  /// lane's own gate test and adds an OCR-tolerant form. Display only — it
  /// never feeds [detect], so lane routing, counts and scoring are unchanged.
  static bool hasIngredientStatement(String scannedText) {
    final text = scannedText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return _ingredientGate.hasMatch(text) ||
        _ingredientOcrTolerant.hasMatch(text);
  }

  static bool _wordHit(String text, String kw) =>
      RegExp('\\b${RegExp.escape(kw)}\\b').hasMatch(text);

  static PreparedFoodContext detect(String scannedText) {
    final text = scannedText
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final signals = <String>[];

    // Identity word, unless a raw-cut guard phrase explains it away.
    final guarded = _identityGuards.any(text.contains);
    String? identityHit;
    if (!guarded) {
      for (final w in _identityWords) {
        if (text.contains(w)) {
          identityHit = w;
          break;
        }
      }
    }
    if (identityHit != null) signals.add('identity:$identityHit');

    // Ingredient statement: the word "ingredients" followed by a comma list.
    final hasIngredientStatement = _ingredientGate.hasMatch(text);
    if (hasIngredientStatement) signals.add('ingredient-statement');

    // Distinct species named anywhere on the label.
    final species = <String>[];
    _speciesKeywords.forEach((display, kws) {
      if (kws.any((k) => _wordHit(text, k))) species.add(display);
    });
    // Seafood named alongside the meat (gumbo with sausage and shrimp).
    for (final s in SeafoodPreparedDetector.speciesNamed(text)) {
      if (!species.contains(s) && s != 'Fish') species.add(s);
    }
    if (species.length >= 2) signals.add('multi-species:${species.join('+')}');

    // Non-protein component foods.
    var components = 0;
    for (final c in _componentFoods) {
      if (_wordHit(text, c)) components++;
    }
    if (components >= 3) signals.add('components:$components');

    // Conservative gate: an identity word alone is enough (front-of-pack
    // photo of "BEEF STEW"); otherwise require an ingredient statement plus
    // either a second species or a real multi-component formulation — so a
    // sausage's "pork, water, salt, spices" never lands here.
    final isPrepared = identityHit != null ||
        (hasIngredientStatement && (species.length >= 2 || components >= 3));

    if (!isPrepared) return PreparedFoodContext.none;
    return PreparedFoodContext(
      isPrepared: true,
      speciesMentioned: species,
      signals: signals,
    );
  }

  static bool hasFsisLegend(String scannedText) {
    final t = scannedText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return _fsisLegend.any(t.contains);
  }

  static const String gapNote =
      'Not required for multi-ingredient products — no U.S. labeling '
      'regulation requires a prepared-food maker to disclose this for the '
      'meat, poultry, or seafood used as an ingredient. A regulatory gap, '
      'not a brand failure.';

  static const String fdaJurisdictionNote =
      'Likely FDA-jurisdiction prepared food — no USDA inspection legend or establishment number was found. Labels don\'t state meat content, so FAT infers the jurisdiction: below the USDA thresholds (roughly 3% raw / 2% cooked meat) a product is FDA-regulated and carries neither mark. If the legend is on a panel that wasn\'t scanned, rescan it.';

  /// Blue banner copy for the FDA lane (no legend / EST found). Labels
  /// don't state meat content, so jurisdiction is inferred, not confirmed.
  static const String fdaBannerText =
      'This looks like a multi-ingredient prepared food, and no USDA inspection legend or establishment number was found on the scanned panels. Labels don\'t state the meat percentage, so FAT can\'t confirm which agency regulates it. If the meat or poultry content is below the USDA thresholds (roughly 3% raw / 2% cooked meat), the product is FDA-regulated and isn\'t required to carry either mark. If it\'s above, the legend should be somewhere on the package — check the other panels. The per-animal categories (breed, farm, age, feed, welfare, medicine, hormones) are marked “not applicable” rather than “not disclosed”: no U.S. labeling regulation requires a prepared-food maker to disclose them for ingredient meat. Anything the brand voluntarily discloses still counts and still earns its credibility tier.';

  static const String assemblerNote =
      'On a prepared food, the establishment number identifies the final '
      'assembler — the cannery or processing plant that made the product — not the '
      'slaughterhouse of the meat inside. Upstream sourcing is not disclosed '
      'on the label.';

  /// Transform the meat-lane category map for a prepared product.
  ///
  /// Rules: only `.missing` results are downgraded to `.notRequired` —
  /// anything the brand voluntarily disclosed (known/partial) keeps its
  /// credit and credibility tier. `fsisJurisdiction` = EST found or USDA
  /// legend present; when false, the EST-dependent categories also go
  /// `.notRequired` under the FDA-jurisdiction explanation.
  static Map<FATCategory, FATCategoryResult> apply(
    Map<FATCategory, FATCategoryResult> categories,
    PreparedFoodContext context, {
    required bool fsisJurisdiction,
  }) {
    final out = Map<FATCategory, FATCategoryResult>.from(categories);

    // Species becomes a multi-species list gathered from all matches.
    if (context.speciesMentioned.isNotEmpty) {
      out[FATCategory.species] = FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Contains: ${context.speciesMentioned.join(', ')}',
      );
    }

    // Per-animal categories are structurally unanswerable for blended
    // commodity meat — mark the undisclosed ones not-applicable.
    const perAnimal = [
      FATCategory.breed,
      FATCategory.farmRanch,
      FATCategory.ageAtSlaughter,
      FATCategory.feed,
      FATCategory.animalWelfare,
      FATCategory.medicine,
      FATCategory.hormones,
      FATCategory.supplyChainIntermediary,
    ];
    for (final cat in perAnimal) {
      if (out[cat]?.status == DisclosureStatus.missing) {
        out[cat] = const FATCategoryResult(
          status: DisclosureStatus.notRequired,
          value: gapNote,
        );
      }
    }

    if (!fsisJurisdiction) {
      // FDA lane: no legend and no EST is the LEGAL state, not a failure.
      for (final cat in [
        FATCategory.usdaFsisRequiredLanguage,
        FATCategory.processor,
      ]) {
        if (out[cat]?.status == DisclosureStatus.missing) {
          out[cat] = const FATCategoryResult(
            status: DisclosureStatus.notRequired,
            value: fdaJurisdictionNote,
          );
        }
      }
    } else {
      // FSIS lane: the EST is real but names the assembler, not the source.
      final proc = out[FATCategory.processor];
      if (proc != null && proc.status == DisclosureStatus.known) {
        out[FATCategory.processor] = FATCategoryResult(
          status: proc.status,
          value: proc.value,
          credibility: proc.credibility,
          credibilityNote: proc.credibilityNote == null
              ? assemblerNote
              : '${proc.credibilityNote} | $assemblerNote',
        );
      }
    }

    return out;
  }
}

// ── Seafood side of the Prepared / Multi-Ingredient lane ────────────────────
//
// A clam chowder, crab cakes, fish sticks or a shrimp fried rice routes to the
// seafood pipeline, whose 16 categories ask single-fish questions (wild or
// farmed, vessel or farm, harvest timing, feed). For a multi-ingredient product
// no U.S. rule requires the maker to answer them, and processed seafood is
// outside seafood country-of-origin labeling (7 CFR Part 60), so undisclosed
// answers go `.notRequired` — the same treatment the meat lane gives a stew.
class SeafoodPreparedDetector {
  SeafoodPreparedDetector._();

  // Seafood dishes and formulations. The shared meat-lane identity words
  // (soup, stew, pizza, fried rice, dumpling, gumbo…) apply too.
  static const List<String> _identityWords = [
    'chowder', 'bisque', 'fish stick', 'fish sticks', 'fish cake', 'fishcake',
    'crab cake', 'crabcake', 'salmon cake', 'crab rangoon', 'rangoon',
    'tuna salad', 'seafood salad', 'shrimp salad', 'crab salad',
    'sushi roll', 'california roll', 'paella', 'cioppino', 'bouillabaisse',
    'scampi', 'pad thai', 'alfredo', 'linguine', 'risotto', 'shumai',
    'shu mai', 'har gow', 'imitation crab', 'imitation lobster',
    'crab flavored', 'surimi', 'clam sauce', 'crab dip', 'clam dip',
    'stuffed clams', 'fish taco', 'seafood medley',
  ];

  // Raw-product phrases that contain an identity word but are single-species
  // seafood (e.g. "sushi grade tuna" is a raw loin, "chowder clams" are clams).
  static const List<String> _guards = [
    'sushi grade', 'sushi-grade', 'sashimi grade', 'sashimi-grade',
    'chowder clams', 'for chowder', 'chowder mix', 'for soup', 'for stew',
    'for paella', 'stew meat', 'soup bones',
  ];

  // Seafood species named as ingredients — whole-word, plurals allowed.
  static const Map<String, List<String>> _seafoodKeywords = {
    'Salmon': ['salmon'],
    'Tuna': ['tuna'],
    'Cod': ['cod'],
    'Pollock': ['pollock'],
    'Haddock': ['haddock'],
    'Tilapia': ['tilapia'],
    'Catfish': ['catfish'],
    'Trout': ['trout'],
    'Halibut': ['halibut'],
    'Flounder': ['flounder'],
    'Whiting': ['whiting', 'hake'],
    'Anchovy': ['anchovy', 'anchovies'],
    'Sardine': ['sardine', 'sardines'],
    'Mackerel': ['mackerel'],
    'Shrimp': ['shrimp', 'prawn', 'prawns'],
    'Crab': ['crab', 'crabs', 'crabmeat'],
    'Lobster': ['lobster', 'lobsters'],
    'Crawfish': ['crawfish', 'crayfish'],
    'Clam': ['clam', 'clams'],
    'Oyster': ['oyster', 'oysters'],
    'Mussel': ['mussel', 'mussels'],
    'Scallop': ['scallop', 'scallops'],
    'Squid': ['squid', 'calamari'],
    'Octopus': ['octopus'],
  };

  /// Every fish, shellfish, meat and poultry species named on the label, in a
  /// stable order (seafood first, then the meat-lane species).
  static List<String> speciesNamed(String text) {
    final out = <String>[];
    _seafoodKeywords.forEach((display, kws) {
      if (kws.any((k) => PreparedFoodDetector._wordHit(text, k))) out.add(display);
    });
    if (out.isEmpty && PreparedFoodDetector._wordHit(text, 'fish')) out.add('Fish');
    PreparedFoodDetector._speciesKeywords.forEach((display, kws) {
      if (kws.any((k) => PreparedFoodDetector._wordHit(text, k))) out.add(display);
    });
    return out;
  }

  static PreparedFoodContext detect(String scannedText) {
    final text = scannedText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final signals = <String>[];

    String? identityHit;
    if (!_guards.any(text.contains)) {
      for (final w in [..._identityWords, ...PreparedFoodDetector._identityWords]) {
        // Plural-aware: "crab cakes", "fish tacos", "dumplings".
        if (RegExp('\\b${RegExp.escape(w)}(s|es)?\\b').hasMatch(text)) {
          identityHit = w;
          break;
        }
      }
    }
    if (identityHit != null) signals.add('identity:$identityHit');

    final hasIngredientStatement = PreparedFoodDetector._ingredientGate.hasMatch(text);
    if (hasIngredientStatement) signals.add('ingredient-statement');

    final species = speciesNamed(text);
    if (species.length >= 2) signals.add('multi-species:${species.join('+')}');

    var components = 0;
    for (final c in PreparedFoodDetector._componentFoods) {
      if (PreparedFoodDetector._wordHit(text, c)) components++;
    }
    if (components >= 3) signals.add('components:$components');

    // Same conservative gate as the meat lane: smoked salmon's "salmon, salt,
    // sugar, smoke" or canned tuna's "tuna, water, salt" never lands here.
    final isPrepared = identityHit != null ||
        (hasIngredientStatement && (species.length >= 2 || components >= 3));
    if (!isPrepared) return PreparedFoodContext.none;
    return PreparedFoodContext(isPrepared: true, speciesMentioned: species, signals: signals);
  }

  /// Transform the seafood-lane category map for a prepared product. Only
  /// `.missing` results change — voluntary disclosures keep their credit.
  static Map<SeafoodCategory, FATCategoryResult> apply(
    Map<SeafoodCategory, FATCategoryResult> categories,
    PreparedFoodContext context, {
    required String processedOriginNote,
  }) {
    final out = Map<SeafoodCategory, FATCategoryResult>.from(categories);

    if (context.speciesMentioned.isNotEmpty) {
      out[SeafoodCategory.speciesIdentity] = FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Contains: ${context.speciesMentioned.join(', ')}',
      );
    }

    const perFish = [
      SeafoodCategory.strainVariety,
      SeafoodCategory.farmVesselFishery,
      SeafoodCategory.ageAtHarvest,
      SeafoodCategory.productionMethodFeed,
      SeafoodCategory.animalWelfare,
      SeafoodCategory.medicineAntibioticsChemicals,
      SeafoodCategory.hormones,
      SeafoodCategory.supplyChainIntermediary,
    ];
    for (final cat in perFish) {
      if (out[cat]?.status == DisclosureStatus.missing) {
        out[cat] = const FATCategoryResult(
          status: DisclosureStatus.notRequired,
          value: PreparedFoodDetector.gapNote,
        );
      }
    }

    // Processed seafood is outside seafood COOL, whatever the label's wording.
    if (out[SeafoodCategory.countryOrigin]?.status == DisclosureStatus.missing) {
      out[SeafoodCategory.countryOrigin] = FATCategoryResult(
        status: DisclosureStatus.notRequired,
        value: processedOriginNote,
      );
    }

    // Catfish products are USDA-inspected: the EST names the plant that made
    // the product, not the farm or the processor of the fish inside.
    final proc = out[SeafoodCategory.processor];
    if (proc != null && proc.status == DisclosureStatus.known) {
      out[SeafoodCategory.processor] = FATCategoryResult(
        status: proc.status,
        value: proc.value,
        credibility: proc.credibility,
        credibilityNote: proc.credibilityNote == null
            ? PreparedFoodDetector.assemblerNote
            : '${proc.credibilityNote} | ${PreparedFoodDetector.assemblerNote}',
      );
    }
    return out;
  }

  static const String bannerText =
      'This looks like a multi-ingredient prepared food — a chowder, crab cake, fish stick or similar — where seafood is one ingredient among many. Because it is a processed food, federal country-of-origin labeling doesn’t apply, and no U.S. rule requires the maker to say whether the seafood was wild or farmed, where it was caught or farmed, or how it was raised. Those categories are marked “not applicable” rather than “not disclosed” — a regulatory gap, not a brand failure. Anything the brand voluntarily discloses (for example “made with wild Alaska pollock” or an MSC label) still counts and still earns its credibility tier. One rule does reach the label: fish and crustacean shellfish such as shrimp, crab and lobster must be named by species in the allergen statement. Mollusks such as clams and oysters are not covered by that rule.';
}
