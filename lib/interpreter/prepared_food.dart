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
    final hasIngredientStatement =
        RegExp(r'ingredients\b[\s\S]{0,200}?,[\s\S]{0,120}?,').hasMatch(text);
    if (hasIngredientStatement) signals.add('ingredient-statement');

    // Distinct species named anywhere on the label.
    final species = <String>[];
    _speciesKeywords.forEach((display, kws) {
      if (kws.any((k) => _wordHit(text, k))) species.add(display);
    });
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

  static const String _gapNote =
      'Not required for multi-ingredient products — no U.S. labeling '
      'regulation requires a prepared-food maker to disclose this for the '
      'meat, poultry, or seafood used as an ingredient. A regulatory gap, '
      'not a brand failure.';

  static const String _fdaJurisdictionNote =
      'FDA-jurisdiction prepared food — products whose meat or poultry '
      'content is below the FSIS thresholds (roughly 3% raw / 2% cooked) '
      'are regulated by FDA, not USDA, and legally carry no USDA inspection '
      'legend and no establishment number. Their absence is not a '
      'compliance failure.';

  static const String assemblerNote =
      'On a prepared food, the establishment number identifies the final '
      'assembler — the cannery or plant that made the product — not the '
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
          value: _gapNote,
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
            value: _fdaJurisdictionNote,
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
