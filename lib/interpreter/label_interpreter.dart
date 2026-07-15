// Label Interpreter — Dart port of LabelInterpreter.swift (v1.1)
import '../models/fat_models.dart';
import '../data/brand_resolver.dart';

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
    final processor       = const FATCategoryResult(status: DisclosureStatus.missing);
    var feed              = _applyFeedSpeciesGate(_detectFeed(normalized), species.value);
    // Fold pasture / regenerative sub-claims into Feed (mirrors iOS): a
    // "pasture raised" or "regenerative" label still credits the Feed category.
    if (feed.status == DisclosureStatus.missing) {
      final pasture = _detectPasture(normalized);
      final regen = _detectRegenerative(normalized);
      if (pasture.status == DisclosureStatus.known ||
          pasture.status == DisclosureStatus.partial) {
        feed = pasture;
      } else if (regen.status == DisclosureStatus.known ||
          regen.status == DisclosureStatus.partial) {
        feed = regen;
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

    return {
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
  }

  // ── Species ──────────────────────────────────────────────────────────────

  static FATCategoryResult _detectSpecies(String text) {
    // Product-type keywords (highest priority)
    const porkKeywords = ['ham', 'bacon', 'prosciutto', 'pancetta', 'sow', 'pork loin',
      'pork chop', 'pork belly', 'spare rib', 'bratwurst', 'chorizo', 'kielbasa',
      'andouille', 'mortadella', 'salami', 'pepperoni', 'pulled pork', 'carnitas'];
    for (final k in porkKeywords) {
      if (text.contains(k)) return _known('Pork');
    }

    const beefKeywords = ['brisket', 'ribeye', 'rib eye', 'sirloin', 'filet mignon',
      'tenderloin', 'flank steak', 'chuck roast', 'ground beef', 'beef patty',
      'beef short rib', 'corned beef', 'pastrami', 'beef jerky', 'veal', 't-bone',
      'porterhouse', 'new york strip', 'tri tip'];
    for (final k in beefKeywords) {
      if (text.contains(k)) return _known('Beef');
    }

    const chickenKeywords = ['chicken breast', 'chicken thigh', 'chicken wing',
      'chicken leg', 'chicken drumstick', 'chicken nugget', 'chicken tender',
      'whole chicken', 'rotisserie chicken', 'broiler chicken', 'chicken fillet'];
    for (final k in chickenKeywords) {
      if (text.contains(k)) return _known('Chicken');
    }

    const turkeyKeywords = ['turkey breast', 'turkey thigh', 'turkey wing', 'turkey leg',
      'turkey burger', 'turkey bacon', 'turkey sausage', 'whole turkey'];
    for (final k in turkeyKeywords) {
      if (text.contains(k)) return _known('Turkey');
    }

    const lambKeywords = ['lamb chop', 'lamb rack', 'lamb shank', 'lamb loin',
      'leg of lamb', 'mutton chop'];
    for (final k in lambKeywords) {
      if (text.contains(k)) return _known('Lamb');
    }

    // Catfish — 4th FSIS-regulated species per FAT DSA v1.1
    const catfishKeywords = ['channel catfish', 'blue catfish', 'flathead catfish',
      'catfish fillet', 'catfish nugget', 'pangasius', 'swai', 'basa', 'tra'];
    for (final k in catfishKeywords) {
      if (text.contains(k)) return _known('Catfish (Siluriformes)');
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
        if (text.contains(k)) return _known(entry.value);
      }
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
    return FATCategoryResult.missing;
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

  static FATCategoryResult _detectFeed(String text) {
    const patterns = <String, (String, ClaimCredibility, String)>{
      'grass fed':      ('Grass Fed',      ClaimCredibility.labelClaimOnly,   'May require FSIS approval; verify documentation'),
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
    if (feed.status != DisclosureStatus.known) return feed;
    final v = feed.value?.toLowerCase() ?? '';
    if (!v.contains('grass')) return feed;
    final s = species?.toLowerCase() ?? '';
    if (['pork', 'chicken', 'turkey'].contains(s)) {
      return FATCategoryResult(
        status: DisclosureStatus.known,
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
      return FATCategoryResult.missing;
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
