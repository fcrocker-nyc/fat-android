// Label Interpreter — Dart port of LabelInterpreter.swift (v1.1)
import '../models/fat_models.dart';
import '../data/brand_resolver.dart';
import 'retail_exemption.dart';

class LabelInterpreter {
  LabelInterpreter._();

  static Map<FATCategory, FATCategoryResult> interpret(String scannedText) {
    final normalized = scannedText
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final species         = _detectSpecies(normalized);
    final breed           = _detectBreed(normalized);
    final country         = _detectCountryOrigin(normalized);
    final farm            = _detectFarmRanch(normalized);
    final intermediary    = _detectSupplyChainIntermediary(normalized);
    // Processor is Known when an establishment number is present on the label —
    // the EST number IS the disclosure of the federally inspected plant
    // (mirrors iOS LabelInterpreter.detectProcessor).
    final processor       = extractEstablishmentNumber(normalized) != null
        ? const FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'Establishment number disclosed on label')
        : const FATCategoryResult(status: DisclosureStatus.missing);
    var feed              = _applyFeedSpeciesGate(_detectFeed(normalized), species.value);
    // Fold pasture / regenerative sub-claims into Feed (mirrors iOS): a
    // "pasture raised" or "regenerative" label still credits the Feed category.
    // Also fold when feed is `partial`: an unqualified "grass-fed" earns no
    // credit, but a pasture / regenerative claim on the same label can still earn
    // the category on its own. When that happens, keep the reason the grass claim
    // was uncredited so the explanation isn't lost. Mirrors iOS buildFeedResult.
    if (feed.status == DisclosureStatus.missing ||
        feed.status == DisclosureStatus.partial) {
      final uncreditedWhy =
          feed.status == DisclosureStatus.partial ? feed.credibilityNote : null;
      final pasture = _detectPasture(normalized);
      final regen = _detectRegenerative(normalized);
      FATCategoryResult? earned;
      if (pasture.status == DisclosureStatus.known ||
          pasture.status == DisclosureStatus.partial) {
        earned = pasture;
      } else if (regen.status == DisclosureStatus.known ||
          regen.status == DisclosureStatus.partial) {
        earned = regen;
      }
      if (earned != null) {
        feed = uncreditedWhy == null
            ? earned
            : FATCategoryResult(
                status: earned.status,
                value: earned.value,
                credibility: earned.credibility,
                credibilityNote: [
                  if (earned.credibilityNote != null) earned.credibilityNote!,
                  uncreditedWhy,
                ].join(' | '),
              );
      }
    }
    final welfare         = _detectAnimalWelfare(normalized);
    final quality         = _detectQualityPalatability(normalized);
    final medicine        = _detectMedicine(normalized);
    final hormones        = _detectHormones(normalized);
    final age             = _detectAgeAtSlaughter(normalized);
    final organic         = _detectOrganic(normalized);
    final fsis            = _detectUSDAFSIS(normalized);

    // Brand + Who (owner / corporate parent) via the shared resolver — same
    // engine and data as iOS. Brand is Known when a brand alias matches; Who is
    // Known when that match carries a responsible company. Both all-or-nothing.
    final resolution = BrandResolver.instance.resolve(normalized);
    final brand = resolution != null
        ? FATCategoryResult(
            status: DisclosureStatus.known, value: resolution.matchedBrand)
        : const FATCategoryResult(status: DisclosureStatus.missing);
    final who = (resolution != null &&
            resolution.primaryResponsibleCompany.trim().isNotEmpty)
        ? FATCategoryResult(
            status: DisclosureStatus.known,
            value: resolution.primaryResponsibleCompany)
        : const FATCategoryResult(status: DisclosureStatus.missing);

    final map = <FATCategory, FATCategoryResult>{
      FATCategory.usdaFsisRequiredLanguage: fsis,
      FATCategory.species:                  species,
      FATCategory.breed:                    breed,
      FATCategory.countryOrigin:            country,
      FATCategory.farmRanch:                farm,
      FATCategory.ageAtSlaughter:           age,
      FATCategory.processor:                processor,
      FATCategory.who:                      who,
      FATCategory.brand:                    brand,
      FATCategory.feed:                     feed,
      FATCategory.animalWelfare:            welfare,
      FATCategory.medicine:                 medicine,
      FATCategory.hormones:                 hormones,
      FATCategory.qualityPalatability:      quality,
      FATCategory.organic:                  organic,
      FATCategory.supplyChainIntermediary:  intermediary,
    };

    // Poultry has no finishing-phase intermediary stage (no feedlot /
    // backgrounder / sale barn) — birds move directly from the growing farm to
    // the processor. Silence on this category is therefore structural, not a
    // disclosure gap: report notRequired instead of missing. Mirrors iOS.
    if ((species.value == 'Chicken' || species.value == 'Turkey') &&
        (map[FATCategory.supplyChainIntermediary]?.status ??
                DisclosureStatus.missing) ==
            DisclosureStatus.missing) {
      map[FATCategory.supplyChainIntermediary] = const FATCategoryResult(
        status: DisclosureStatus.notRequired,
        value:
            'Intermediaries are not used in poultry — birds move directly from the farm to the processor.',
      );
    }

    // USDA retail-store exemption (9 CFR 303.1(d)). When a store-cut / store-ground
    // package is detected (no EST number + positive in-store evidence), the
    // establishment-dependent categories are structurally unanswerable — report
    // them `notRequired` (a regulatory gap, not a store failure) rather than
    // `missing`. Only categories currently `missing` are re-labeled; a genuine
    // disclosure is never downgraded. Mirrors iOS LabelInterpreter.
    final exemption = RetailExemptionDetector.detect(
      normalized,
      estFound: extractEstablishmentNumber(normalized) != null,
      isMeat: species.status == DisclosureStatus.known,
    );
    if (exemption.isExempt) {
      const exemptCats = [
        FATCategory.processor,
        FATCategory.usdaFsisRequiredLanguage,
        FATCategory.supplyChainIntermediary,
      ];
      for (final cat in exemptCats) {
        if ((map[cat]?.status ?? DisclosureStatus.missing) ==
            DisclosureStatus.missing) {
          map[cat] = const FATCategoryResult(
            status: DisclosureStatus.notRequired,
            value: RetailExemption.categoryNote,
          );
        }
      }
    }

    return map;
  }

  /// Detects the USDA retail-store exemption for a scanned label. Pure and cheap;
  /// call sites use it to set the `retailExempt` flag on the FATResult (and to
  /// suppress the "no establishment number" compliance warning).
  static RetailExemption detectRetailExemption(String scannedText) {
    final normalized = scannedText
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return RetailExemptionDetector.detect(
      normalized,
      estFound: extractEstablishmentNumber(normalized) != null,
      isMeat: _detectSpecies(normalized).status == DisclosureStatus.known,
    );
  }

  // ── Species ──────────────────────────────────────────────────────────────

  /// Whole-word / whole-phrase match. Short species keywords ('ham', 'cow',
  /// 'hen', 'pig', 'sow', 'tra') were matching as bare substrings — 'ham'
  /// inside 'hamburger' (and inside address/brand strings like 'Framingham',
  /// 'Graham') mislabeled beef as Pork. Anchoring on word boundaries fixes that
  /// while still matching multi-word phrases like 'ground beef'.
  static final Map<String, RegExp> _wordRe = {};
  static bool _containsWord(String keyword, String text) {
    final re = _wordRe.putIfAbsent(
        keyword, () => RegExp('\\b${RegExp.escape(keyword)}\\b', caseSensitive: false));
    return re.hasMatch(text);
  }

  static FATCategoryResult _detectSpecies(String text) {
    // Product-type keywords (highest priority)
    const porkKeywords = ['ham', 'bacon', 'prosciutto', 'pancetta', 'sow',
      'pork tenderloin', 'pork loin', 'pork sirloin',
      'pork chop', 'pork belly', 'spare rib', 'bratwurst', 'chorizo', 'kielbasa',
      'andouille', 'mortadella', 'salami', 'pepperoni', 'pulled pork', 'carnitas'];
    for (final k in porkKeywords) {
      if (_containsWord(k, text)) return _known('Pork');
    }

    // Beef-UNIQUE cuts only. Ambiguous cuts ("tenderloin", "sirloin") shared
    // across species are a last resort (Tier 3) AFTER the bare-animal-word check,
    // so a "Pork Tenderloin" label is not mislabeled Beef.
    // "hamburger" is beef by regulation (9 CFR 319.15).
    const beefKeywords = ['brisket', 'ribeye', 'rib eye', 'filet mignon',
      'beef tenderloin', 'flank steak', 'chuck roast', 'ground beef', 'beef patty',
      'beef burger', 'hamburger',
      'beef short rib', 'corned beef', 'pastrami', 'beef jerky', 'veal', 't-bone',
      'porterhouse', 'new york strip', 'tri tip'];
    for (final k in beefKeywords) {
      if (_containsWord(k, text)) return _known('Beef');
    }

    const chickenKeywords = ['chicken breast', 'chicken thigh', 'chicken wing',
      'chicken leg', 'chicken drumstick', 'chicken nugget', 'chicken tender',
      'whole chicken', 'rotisserie chicken', 'broiler chicken', 'chicken fillet'];
    for (final k in chickenKeywords) {
      if (_containsWord(k, text)) return _known('Chicken');
    }

    const turkeyKeywords = ['turkey breast', 'turkey thigh', 'turkey wing', 'turkey leg',
      'turkey burger', 'turkey bacon', 'turkey sausage', 'whole turkey'];
    for (final k in turkeyKeywords) {
      if (_containsWord(k, text)) return _known('Turkey');
    }

    const lambKeywords = ['lamb chop', 'lamb rack', 'lamb shank', 'lamb loin',
      'leg of lamb', 'mutton chop'];
    for (final k in lambKeywords) {
      if (_containsWord(k, text)) return _known('Lamb');
    }

    // Catfish — 4th FSIS-regulated species per FAT DSA v1.1
    const catfishKeywords = ['channel catfish', 'blue catfish', 'flathead catfish',
      'catfish fillet', 'catfish nugget', 'pangasius', 'swai', 'basa', 'tra'];
    for (final k in catfishKeywords) {
      if (_containsWord(k, text)) return _known('Catfish (Siluriformes)');
    }

    // Generic species keywords
    final speciesMap = <List<String>, String>{
      ['beef', 'cattle', 'cow', 'steer', 'heifer']: 'Beef',
      ['pork', 'pig', 'swine', 'hog']:              'Pork',
      ['chicken', 'poultry', 'hen', 'rooster']:     'Chicken',
      ['turkey']:                                    'Turkey',
      ['lamb', 'sheep', 'mutton']:                  'Lamb',
      ['catfish', 'siluriformes']:                   'Catfish (Siluriformes)',
    };
    for (final entry in speciesMap.entries) {
      for (final k in entry.key) {
        if (_containsWord(k, text)) return _known(entry.value);
      }
    }

    // Tier 3: genuinely ambiguous cuts default to beef only as a last resort,
    // reached ONLY after no explicit species word was found above.
    for (final k in const ['tenderloin', 'sirloin']) {
      if (_containsWord(k, text)) return _known('Beef');
    }

    return FATCategoryResult.missing;
  }

  // ── Breed ────────────────────────────────────────────────────────────────

  static FATCategoryResult _detectBreed(String text) {
    const breeds = ['angus', 'hereford', 'wagyu', 'longhorn', 'charolais',
      'berkshire', 'duroc', 'hampshire', 'yorkshire', 'cornish', 'plymouth rock'];
    for (final b in breeds) {
      if (text.contains(b)) {
        return _known(_capitalize(b));
      }
    }
    return FATCategoryResult.missing;
  }

  // ── Country / Origin ─────────────────────────────────────────────────────

  static FATCategoryResult _detectCountryOrigin(String text) {
    const patterns = <String, String>{
      'product of usa':            'Product of USA',
      'made in usa':               'Made in USA',
      'product of united states':  'Product of United States',
    };
    for (final entry in patterns.entries) {
      if (text.contains(entry.key)) return _known(entry.value);
    }
    for (final k in ['born in', 'raised in', 'processed in']) {
      if (text.contains(k)) return _known(_capitalize(k));
    }
    // Clarify that an absent origin statement is not a claim of origin either
    // way. Mandatory COOL for beef and pork muscle cuts was repealed in 2015,
    // so most carry no origin label — the omission does not mean imported.
    return const FATCategoryResult(
      status: DisclosureStatus.missing,
      credibilityNote:
          'Not disclosed is not a claim of origin — it does not mean the product is imported, or that it is domestic. Mandatory country-of-origin labeling on beef and pork muscle cuts was repealed in 2015, so most carry no origin statement at all.',
    );
  }

  // ── Farm / Ranch ─────────────────────────────────────────────────────────

  static FATCategoryResult _detectFarmRanch(String text) {
    // Generic marketing phrases ("family farm", "farm raised", etc.) are NOT a
    // specific source identity, so they earn Partial — which scores 0 under this
    // category's all-or-nothing rule. Full credit (Known → 6 pts) is reserved for
    // a specifically named farm, ranch, or grower group.
    const genericClaims = ['family farm', 'local farm', 'small farm',
      'ranch', 'pasture raised', 'farm raised'];
    for (final p in genericClaims) {
      if (text.contains(p)) {
        return FATCategoryResult(
          status: DisclosureStatus.partial,
          value: _capitalize(p),
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote:
              'Generic farm claim — not a specific, named source. No source-identity credit.',
        );
      }
    }
    return FATCategoryResult.missing;
  }

  // ── Supply-Chain Intermediary (Cat. 5 / 5b) — v1.1 ──────────────────────

  static FATCategoryResult _detectSupplyChainIntermediary(String text) {
    // 1. NPDES permit detection
    String? npdesPermit;
    final npdesPatterns = [
      RegExp(r'(?:npdes|cafo\s+permit|permit\s+no\.?)\s+([a-z]{2}\d{5,9})', caseSensitive: false),
      RegExp(r'\b([a-z]{2}00\d{5,7})\b', caseSensitive: false),
    ];
    for (final re in npdesPatterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        npdesPermit = m.group(1)?.toUpperCase();
        break;
      }
    }
    final npdesNote = npdesPermit != null
        ? 'NPDES permit $npdesPermit detected. Per FAT DSA v1.1, this qualifies as Tier 2 identity substantiation.'
        : null;

    // 2. Known packer-owned operators
    const operators = <String, _OperatorInfo>{
      'five rivers cattle': _OperatorInfo('Five Rivers Cattle Feeding',
          'Packer-owned captive feedlot. Five Rivers is a wholly owned subsidiary of Cargill Meat Solutions.'),
      'five rivers': _OperatorInfo('Five Rivers Cattle Feeding (Cargill)',
          'Packer-owned captive feedlot. Five Rivers is a wholly owned subsidiary of Cargill Meat Solutions.'),
      'cargill cattle': _OperatorInfo('Cargill Cattle Feeding',
          'Packer-owned captive feedyard operated by Cargill.'),
      'excel beef': _OperatorInfo('Excel Beef (Cargill)',
          'Packer-owned feedyard under Cargill\'s Excel beef brand.'),
      'national beef feedyard': _OperatorInfo('National Beef Feedyard',
          'Packer-affiliated feedyard associated with National Beef Packing Co.'),
      'conagra feeder': _OperatorInfo('ConAgra Feeders',
          'Captive feedlot formerly operated by ConAgra Foods\' beef division.'),
      'monfort feed': _OperatorInfo('Monfort Feeding (JBS/Greeley)',
          'Historic ConAgra/Monfort captive feedyard in Greeley, CO.'),
    };

    for (final entry in operators.entries) {
      if (text.contains(entry.key)) {
        final cred = npdesPermit != null ? ClaimCredibility.usdaApproved : ClaimCredibility.labelClaimOnly;
        final note = entry.value.note + (npdesNote != null ? ' $npdesNote' : '');
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: entry.value.display,
          credibility: cred,
          credibilityNote: note,
          captivityStatus: CaptivityStatus.packerOwned,
        );
      }
    }

    // 3. Explicit captivity language
    const packerOwnedKw = ['packer owned', 'packer-owned', 'packer controlled',
      'captive feedyard', 'captive feedlot', 'captive supply',
      'owned by cargill', 'owned by jbs', 'owned by tyson', 'owned by national beef'];
    for (final k in packerOwnedKw) {
      if (text.contains(k)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Packer-owned/captive supply disclosed',
          credibility: npdesPermit != null ? ClaimCredibility.usdaApproved : ClaimCredibility.labelClaimOnly,
          credibilityNote: 'Label discloses packer-owned or captive-supply finishing.${npdesNote != null ? ' $npdesNote' : ''}',
          captivityStatus: CaptivityStatus.packerOwned,
        );
      }
    }

    const contractKw = ['packer contracted', 'packer-contracted', 'contract feedyard'];
    for (final k in contractKw) {
      if (text.contains(k)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Packer-contracted finishing',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote: 'Label discloses a packer-contracted finishing operation.',
          captivityStatus: CaptivityStatus.packerContracted,
        );
      }
    }

    const independentKw = ['independent feedlot', 'independent feedyard', 'independent finisher'];
    for (final k in independentKw) {
      if (text.contains(k)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Independent finishing disclosed',
          credibility: npdesPermit != null ? ClaimCredibility.usdaApproved : ClaimCredibility.labelClaimOnly,
          credibilityNote: 'Label discloses an independent finishing operation.${npdesNote != null ? ' $npdesNote' : ''}',
          captivityStatus: CaptivityStatus.independent,
        );
      }
    }

    // 4. Generic feedlot/intermediary disclosure
    const genericKw = ['feedlot', 'feed yard', 'feedyard', 'feed lot',
      'custom fed at', 'custom fed by', 'finished at', 'contract grower',
      'contract finisher', 'integrator', 'days on feed', 'days in finishing', 'grow-out'];
    for (final p in genericKw) {
      if (text.contains(p)) {
        final cred = npdesPermit != null ? ClaimCredibility.usdaApproved : ClaimCredibility.labelClaimOnly;
        final note = npdesPermit != null
            ? 'Intermediary referenced on label. $npdesNote Captivity not stated.'
            : 'Intermediary referenced; no independent audit identified. Captivity not stated.';
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: _capitalize(p),
          credibility: cred,
          credibilityNote: note,
          captivityStatus: CaptivityStatus.undisclosed,
        );
      }
    }

    // 5. NPDES permit alone
    if (npdesPermit != null) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'NPDES Permit $npdesPermit detected',
        credibility: ClaimCredibility.usdaApproved,
        credibilityNote: npdesNote,
        captivityStatus: CaptivityStatus.undisclosed,
      );
    }

    // 6. Partial
    const partialKw = ['grain finished', 'grain-finished', 'corn finished',
      'vertically integrated', 'company owned farm'];
    for (final p in partialKw) {
      if (text.contains(p)) {
        return FATCategoryResult(
          status: DisclosureStatus.partial,
          value: 'Finishing method implied; intermediary not named',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote: 'Finishing claim present but feedlot/grower identity not disclosed.',
          captivityStatus: CaptivityStatus.undisclosed,
        );
      }
    }

    return FATCategoryResult.missing;
  }

  // ── Feed ─────────────────────────────────────────────────────────────────

  /// Grass claims, per **FSIS Guideline FSIS-GD-2024-0006 (Aug 2024), "Diet Claims."**
  /// Mirrors iOS LabelInterpreter.detectFeed — see that file for the full citation.
  ///
  /// • "Grass Fed, Grassfed, Grass-Fed and 100% Grass-Fed" are SYNONYMOUS to FSIS →
  ///   one tier, never ranked against each other.
  /// • Grass Fed = only (100%) forage after weaning, "never confined to a feedlot",
  ///   continuous pasture access until slaughter → earns credit.
  /// • "Grass Finished … is not synonymous with Grass Fed. Animals that are Grass
  ///   Finished can be fed grain." → grass-finished alone earns nothing.
  /// • Under-100% partial claims and mixed diets earn nothing.
  ///
  /// The weakness of an uncertified grass claim is verification (documentary review
  /// at label approval, not an on-farm audit) — carried in the credibility tier.
  static FATCategoryResult _detectFeed(String text) {
    final hasGrassFed = text.contains('grass fed') || text.contains('grassfed');
    final hasFinished =
        text.contains('grass finished') || text.contains('grassfinished');
    final hasGrain = text.contains('grain fed') ||
        text.contains('grain finished') ||
        text.contains('grain finish') ||
        text.contains('corn fed');

    int? partialPercent;
    for (final p in const [
      r'(\d{1,3})\s*%\s*grass\s*fed',
      r'(\d{1,3})\s*percent\s*grass\s*fed',
      r'(\d{1,3})\s*%\s*grassfed',
      r'(\d{1,3})\s*percent\s*grassfed',
    ]) {
      final m = RegExp(p).firstMatch(text);
      final v = m == null ? null : int.tryParse(m.group(1) ?? '');
      if (v != null && v < 100) {
        partialPercent = v;
        break;
      }
    }

    if (hasGrassFed || hasFinished) {
      if (partialPercent != null) {
        return FATCategoryResult(
          status: DisclosureStatus.partial,
          value: '$partialPercent% grass fed — partial claim, no credit',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote:
              'FSIS treats a diet under 100% forage as a partial Grass Fed claim that '
              'must reflect the actual circumstances of raising. The animal ate grain, '
              'so this does not earn the feed category.',
        );
      }
      if (hasGrain) {
        return const FATCategoryResult(
          status: DisclosureStatus.partial,
          value: 'Mixed diet (grass + grain) — no credit',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote:
              "The label also discloses grain. Under FSIS's Mixed Diet and Partially "
              'Grass Fed guidance this is not a Grass Fed claim, so it does not earn '
              'the feed category.',
        );
      }
      if (hasGrassFed) {
        return const FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Grass Fed (100% forage)',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote:
              'FSIS: "Grass Fed, Grassfed, Grass-Fed and 100% Grass-Fed" are synonymous '
              '— cattle fed only forage after weaning, never confined to a feedlot, with '
              'continuous pasture access until slaughter. Substantiated by documentation '
              'at label approval, not an on-farm audit, unless a third-party certifier '
              '(e.g. AGA, AGW) appears on the label.',
        );
      }
      return const FATCategoryResult(
        status: DisclosureStatus.partial,
        value: 'Grass Finished only — no credit',
        credibility: ClaimCredibility.labelClaimOnly,
        credibilityNote:
            'FSIS: "Grass Finished … is not synonymous with Grass Fed. Animals that are '
            'Grass Finished can be fed grain." Because grain is permitted earlier in '
            'life, this claim does not earn the feed category. "Grass Fed" is the '
            'stronger term.',
      );
    }

    const patterns = <String, (String, ClaimCredibility, String)>{
      'grain fed':      ('Grain Fed',      ClaimCredibility.labelClaimOnly,   'No independent verification identified'),
      'vegetarian fed': ('Vegetarian Fed', ClaimCredibility.labelClaimOnly,   'No independent verification identified'),
      'corn fed':       ('Corn Fed',       ClaimCredibility.labelClaimOnly,   'No independent verification identified'),
    };
    for (final entry in patterns.entries) {
      if (text.contains(entry.key)) {
        final (display, cred, note) = entry.value;
        return FATCategoryResult(status: DisclosureStatus.known, value: display, credibility: cred, credibilityNote: note);
      }
    }
    return FATCategoryResult.missing;
  }

  static FATCategoryResult _applyFeedSpeciesGate(FATCategoryResult feed, String? species) {
    // Accept partial too: an unqualified "grass-fed" is now partial (no credit),
    // and the species-misuse warning must still fire for pork/poultry.
    if (feed.status != DisclosureStatus.known &&
        feed.status != DisclosureStatus.partial) {
      return feed;
    }
    final v = feed.value?.toLowerCase() ?? '';
    if (!v.contains('grass')) return feed;
    final s = species?.toLowerCase() ?? '';
    if (['pork', 'chicken', 'turkey'].contains(s)) {
      return FATCategoryResult(
        status: feed.status,
        value: feed.value,
        credibility: ClaimCredibility.labelClaimOnly,
        credibilityNote: '"Grass-fed" is not an appropriate frame for $s. '
            'Look instead for pasture-raised or outdoor-access claims.',
      );
    }
    return feed;
  }

  // ── Animal Welfare ───────────────────────────────────────────────────────

  static FATCategoryResult _detectAnimalWelfare(String text) {
    const verified = <String, (String, String)>{
      'certified humane':      ('Certified Humane', 'Third-party certified by Humane Farm Animal Care'),
      'animal welfare approved': ('Animal Welfare Approved', 'Third-party certified by A Greener World'),
      'global animal partnership': ('Global Animal Partnership', 'Third-party step rating system'),
      'american humane':       ('American Humane Certified', 'Third-party certified by American Humane Association'),
    };
    for (final entry in verified.entries) {
      if (text.contains(entry.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: entry.value.$1,
          credibility: ClaimCredibility.verified,
          credibilityNote: entry.value.$2,
        );
      }
    }
    if (text.contains('cage free')) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Cage Free',
        credibility: ClaimCredibility.labelClaimOnly,
        credibilityNote: 'FSIS defines cage free as not confined to a cage — birds may still be in crowded indoor barns with no outdoor access.',
      );
    }
    // Outdoor / pasture / woodland RAISING is a welfare disclosure (how the animal
    // lived), distinct from Feed. Unverified without a cert, but a meaningful
    // positive versus cage/indoor confinement — earns the category at the
    // label-claim tier, like "cage free" (and a stronger claim than it).
    const outdoor = [
      'raised outdoors', 'raised outside', 'pasture raised', 'pasture-raised',
      'raised on pasture', 'pasture access', 'outdoor access',
      'free range', 'free-range', 'free roaming', 'free-roaming',
      'pasture or forest', 'pasture or woodland', 'pasture and woodland',
      'raised on pasture or', 'woodland raised', 'forest raised',
    ];
    for (final c in outdoor) {
      if (text.contains(c)) {
        return const FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Raised Outdoors / Pasture Access',
          credibility: ClaimCredibility.labelClaimOnly,
          credibilityNote:
              'The label claims the animal was raised outdoors with pasture (or woodland) access — a meaningful welfare positive versus cage or indoor confinement. No third-party welfare certification (e.g. Certified Humane, Animal Welfare Approved, Global Animal Partnership) or audit was found, so it is an unverified marketing claim.',
        );
      }
    }
    return FATCategoryResult.missing;
  }

  // ── Pasture ──────────────────────────────────────────────────────────────

  static FATCategoryResult _detectPasture(String text) {
    if (text.contains('certified humane') || text.contains('animal welfare approved')) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Pasture Raised (certified)',
        credibility: ClaimCredibility.verified,
        credibilityNote: 'Third-party certification requires meaningful outdoor access.',
      );
    }
    if (text.contains('pasture raised') || text.contains('pasture-raised')) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Pasture Raised',
        credibility: ClaimCredibility.producerAffidavit,
        credibilityNote: 'FSIS-approved claim with producer documentation; no on-farm audit.',
      );
    }
    if (text.contains('free range') || text.contains('free-range')) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Free Range',
        credibility: ClaimCredibility.producerAffidavit,
        credibilityNote: 'FSIS minimum = 5 min/day outdoor access for poultry. No third-party audit.',
      );
    }
    return FATCategoryResult.missing;
  }

  // ── Regenerative ─────────────────────────────────────────────────────────

  static FATCategoryResult _detectRegenerative(String text) {
    if (text.contains('regenerative organic certified') || text.contains('roc certified')) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Regenerative Organic Certified',
        credibility: ClaimCredibility.verified,
        credibilityNote: 'Third-party certification with comprehensive soil, welfare, and fairness standards.',
      );
    }
    if (text.contains('regenerative')) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Regenerative claim',
        credibility: ClaimCredibility.producerAffidavit,
        credibilityNote: 'FSIS-approved label language backed by producer affidavit only; no on-farm audit.',
      );
    }
    return FATCategoryResult.missing;
  }

  // ── Quality / Palatability ───────────────────────────────────────────────

  static FATCategoryResult _detectQualityPalatability(String text) {
    const grades = <String, String>{
      'usda prime':  'USDA Prime',
      'usda choice': 'USDA Choice',
      'usda select': 'USDA Select',
    };
    for (final entry in grades.entries) {
      if (text.contains(entry.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: entry.value,
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA quality grade verified by USDA inspection.',
        );
      }
    }
    // "All Natural" — FSIS-defined labeling claim: minimally processed, no
    // artificial ingredients or added color. NOT a raising claim, no audit.
    // Headline forms only; bare "natural" would false-positive on "natural
    // flavors" / "natural juices" / "naturally smoked". Mirrors iOS.
    if (text.contains('all natural') || text.contains('100% natural')) {
      return const FATCategoryResult(
        status: DisclosureStatus.partial,
        value: 'All Natural',
        credibility: ClaimCredibility.producerAffidavit,
        credibilityNote:
            'FSIS “natural” claim: minimally processed, no artificial ingredients or added color. It is NOT a raising claim — it says nothing about feed, welfare, antibiotics, or hormones — and carries no independent audit.',
      );
    }
    return FATCategoryResult.missing;
  }

  // ── Medicine / Antibiotics ───────────────────────────────────────────────

  static FATCategoryResult _detectMedicine(String text) {
    const patterns = <String, String>{
      'no antibiotics ever':       'No Antibiotics Ever',
      'raised without antibiotics': 'Raised Without Antibiotics',
      'never ever antibiotics':    'Never Ever Antibiotics',
      'antibiotic free':           'Antibiotic Free',
      'no antibiotics':            'No Antibiotics',
      'no added medications':      'No Added Medications',
      'no medications':            'No Medications',
      'medication free':           'Medication Free',
    };
    for (final entry in patterns.entries) {
      if (text.contains(entry.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: entry.value,
          credibility: ClaimCredibility.producerAffidavit,
          credibilityNote: 'FSIS-approved claim with producer documentation; no on-farm audit.',
        );
      }
    }
    return FATCategoryResult.missing;
  }

  // ── Hormones ─────────────────────────────────────────────────────────────

  static FATCategoryResult _detectHormones(String text) {
    const patterns = <String, String>{
      'no hormones administered': 'No Hormones Administered',
      'no added hormones':        'No Added Hormones',
      'hormone free':             'Hormone Free',
      'raised without hormones':  'Raised Without Hormones',
      'never ever hormones':      'Never Ever Hormones',
    };
    for (final entry in patterns.entries) {
      if (text.contains(entry.key)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: entry.value,
          credibility: ClaimCredibility.producerAffidavit,
          credibilityNote: 'FSIS-approved claim with producer documentation; no on-farm audit.',
        );
      }
    }
    for (final k in ['federal regulations prohibit', 'no hormones used in accordance']) {
      if (text.contains(k)) {
        return FATCategoryResult(
          status: DisclosureStatus.partial,
          value: 'Statutory prohibition noted',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'Hormones prohibited by law for this species — not an added claim.',
        );
      }
    }
    return FATCategoryResult.missing;
  }

  // ── Organic ──────────────────────────────────────────────────────────────

  static FATCategoryResult _detectOrganic(String text) {
    for (final k in ['usda organic', 'certified organic', '100% organic']) {
      if (text.contains(k)) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'USDA Certified Organic',
          credibility: ClaimCredibility.verified,
          credibilityNote: 'USDA NOP — independent accredited certifier required; annual on-farm audit.',
        );
      }
    }
    if (text.contains('organic')) {
      return FATCategoryResult(
        status: DisclosureStatus.partial,
        value: 'Organic claim (uncertified)',
        credibility: ClaimCredibility.labelClaimOnly,
        credibilityNote: 'Contains "organic" but no USDA NOP seal or certifier identified.',
      );
    }
    return FATCategoryResult.missing;
  }

  // ── Age at Slaughter ─────────────────────────────────────────────────────

  // USDA 9 CFR 381.170 poultry class terms set a legal age ceiling and are
  // the only age-linked fact on most chicken labels. Credibility is usdaApproved.
  // Typical commercial broiler slaughter: ~47 days (NCC 2024 Broiler Performance Report).
  static FATCategoryResult _detectAgeAtSlaughter(String text) {
    final hasChickenContext = text.contains('chicken') || text.contains('broiler') ||
        text.contains('fryer') || text.contains('roaster') || text.contains('roasting') ||
        text.contains('capon') || text.contains('stewing hen') || text.contains('fowl') ||
        text.contains('cornish') || text.contains('baking hen');

    if (hasChickenContext) {
      if (text.contains('cornish game hen') || text.contains('cornish hen')) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Cornish Game Hen — < 5 weeks old (9 CFR 381.170)',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA standard of identity — 9 CFR 381.170. Class name sets a legal ceiling on age.',
        );
      }
      if (text.contains('stewing hen') || text.contains('stewing chicken') ||
          text.contains('baking hen') || text.contains('baking chicken')) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Stewing Hen / Fowl — ≥ 10 months old (9 CFR 381.170)',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA standard of identity — 9 CFR 381.170. Indicates a spent laying hen, typically 12–18 months at slaughter.',
        );
      }
      if (text.contains('fowl')) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Fowl — ≥ 10 months old (9 CFR 381.170)',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA standard of identity — 9 CFR 381.170. Mature poultry; indicates a spent laying hen.',
        );
      }
      if (text.contains('capon')) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Capon — < 4 months old (9 CFR 381.170)',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA standard of identity — 9 CFR 381.170. Surgically unsexed male chicken, under 4 months at slaughter.',
        );
      }
      if (text.contains('roaster') || text.contains('roasting chicken')) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Roaster — < 12 weeks old (9 CFR 381.170)',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA standard of identity — 9 CFR 381.170, as amended 81 FR 21709 (2016). Typical commercial roaster slaughter: 8–10 weeks.',
        );
      }
      if (text.contains('broiler') || text.contains('fryer')) {
        return FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Broiler / Fryer — < 10 weeks old (9 CFR 381.170)',
          credibility: ClaimCredibility.usdaApproved,
          credibilityNote: 'USDA standard of identity — 9 CFR 381.170. Typical commercial slaughter age is ~47 days (NCC 2024 Broiler Performance Report).',
        );
      }
      // Chicken label with no class term — age not disclosed. State the likely
      // reality alongside (mirrors iOS): undisclosed retail chicken is almost
      // always the USDA broiler/fryer class, the youngest slaughter class.
      // Class taxonomy is USDA's (9 CFR 381.170); the six-week fact is
      // ASPCA-documented; ~47-day average is NCC.
      return const FATCategoryResult(
        status: DisclosureStatus.missing,
        credibilityNote:
            'Undisclosed retail chicken is almost always the USDA “broiler/fryer” class (9 CFR 381.170, under 10 weeks) — in practice slaughtered at about six weeks old, still a juvenile and the youngest of the major farmed animals (ASPCA; NCC reports a ~47-day industry average).',
      );
    }

    // Non-poultry
    if (text.contains('veal')) {
      return FATCategoryResult(status: DisclosureStatus.partial, value: 'Veal (bovine calf, typically < 6 months)');
    }
    if (text.contains('lamb')) {
      return FATCategoryResult(status: DisclosureStatus.partial, value: 'Lamb (< 1 year)');
    }
    for (final k in ['young', 'mature']) {
      if (text.contains(k)) {
        return FATCategoryResult(status: DisclosureStatus.partial, value: _capitalize(k));
      }
    }
    return FATCategoryResult.missing;
  }

  // ── USDA / FSIS Language ─────────────────────────────────────────────────

  static FATCategoryResult _detectUSDAFSIS(String text) {
    const patterns = ['inspected and passed', 'inspected & passed',
      'department of agriculture', 'usda inspected', 'federally inspected',
      'inspected for wholesomeness'];
    for (final p in patterns) {
      if (text.contains(p)) {
        return FATCategoryResult(status: DisclosureStatus.known, value: 'USDA/FSIS required language detected');
      }
    }
    if (extractEstablishmentNumber(text) != null) {
      return FATCategoryResult(status: DisclosureStatus.known, value: 'USDA establishment number detected');
    }
    return FATCategoryResult.missing;
  }

  // ── EST Number Extraction ────────────────────────────────────────────────

  static String? extractEstablishmentNumber(String text) {
    final patterns = [
      RegExp(r'(?:usda\s*)?est\.?\s*(\d{1,6})', caseSensitive: false),
      RegExp(r'establishment\s*(?:number\s*)?(?:#\s*)?(\d{1,6})', caseSensitive: false),
      RegExp(r'est#\s*(\d{1,6})', caseSensitive: false),
      RegExp(r'(?<![a-z])p\s*-\s*(\d{2,6})', caseSensitive: false),
      RegExp(r'(?<![a-z])p(\d{3,6})(?![a-z0-9])', caseSensitive: false),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final raw = m.group(1)?.replaceAll(' ', '') ?? '';
        final n = int.tryParse(raw);
        if (n != null && n > 0 && n < 999999 && raw.length <= 6) return raw;
      }
    }
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static FATCategoryResult _known(String value) =>
      FATCategoryResult(status: DisclosureStatus.known, value: value);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _OperatorInfo {
  final String display;
  final String note;
  const _OperatorInfo(this.display, this.note);
}
