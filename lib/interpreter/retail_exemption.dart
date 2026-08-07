// Retail-exemption detector — Dart port of RetailExemption.swift.
//
// The USDA retail store exemption — 21 U.S.C. 661(c)(2), elaborated at
// 9 CFR 303.1(d) (poultry parallel at 21 U.S.C. 454(c)(2) / 9 CFR 381.10(d)) —
// covers operations "traditionally and usually conducted at retail stores":
// cutting a subprimal into steaks, chops, and roasts, and grinding, when done
// behind the counter for sale in normal retail quantities. A store operating
// inside the exemption is NOT an official establishment. It has no establishment
// number of its own, and nothing obliges it to carry forward the number of the
// plant that supplied the box.
//
// Consequence for FAT scoring (see the research paper "The Retail Exemption"):
// when a package was cut/ground/packed in-store, the establishment-number-dependent
// categories — Processor identity (Cat 7), the FSIS inspection-legend/EST portion
// of the required-language check (Cat 1), and Supply-Chain Intermediaries (Cat 16)
// — become structurally unanswerable. The information was never required to travel
// to the store scale label, so its absence carries no information about the
// retailer's transparency practices. Scoring a store-packaged tray identically to
// a plant-packaged one would misattribute the failure: it belongs to the
// regulatory design, not to the store.

/// Result of retail-store-exemption detection for a scanned meat label.
class RetailExemption {
  final bool isExempt;
  final String? storeName;
  final List<String> matchedSignals;

  const RetailExemption({
    required this.isExempt,
    this.storeName,
    this.matchedSignals = const [],
  });

  static const none = RetailExemption(isExempt: false);

  /// Neutral, citation-backed explanation shown wherever an EST-dependent category
  /// is reported `notRequired` because of the exemption.
  static const String categoryNote =
      'Cut, ground, or packed in-store under the USDA retail exemption '
      '(9 CFR 303.1(d)). A store operating within the exemption is not an '
      'official establishment and has no establishment number to display, so '
      'this disclosure is structurally unanswerable at the point of sale — a '
      'gap in the regulatory design, not a failure by the store.';
}

/// Stateless detector for the retail exemption. Keyed on positive evidence of
/// in-store preparation — never on the mere absence of an establishment number,
/// which on its own is a compliance concern (and stays one).
class RetailExemptionDetector {
  RetailExemptionDetector._();

  /// Major U.S. grocery / warehouse chains that operate in-store meat departments
  /// which cut and grind under the retail exemption. `(matchToken, displayName)`,
  /// tokens lowercased to match normalized OCR. Distinctive brand tokens only —
  /// bare common words (e.g. "giant", "target") are avoided to prevent false hits.
  static const List<List<String>> _grocers = [
    ['kroger', 'Kroger'], ['ralphs', 'Ralphs'], ['king soopers', 'King Soopers'],
    ['fred meyer', 'Fred Meyer'], ['harris teeter', 'Harris Teeter'], ['smith\'s food', 'Smith\'s'],
    ['fry\'s food', 'Fry\'s'], ['qfc', 'QFC'], ['food 4 less', 'Food 4 Less'],
    ['safeway', 'Safeway'], ['albertsons', 'Albertsons'], ['vons', 'Vons'],
    ['jewel-osco', 'Jewel-Osco'], ['jewel osco', 'Jewel-Osco'], ['acme markets', 'ACME'],
    ['shaw\'s', 'Shaw\'s'], ['publix', 'Publix'], ['h-e-b', 'H-E-B'],
    ['meijer', 'Meijer'], ['wegmans', 'Wegmans'], ['giant eagle', 'Giant Eagle'],
    ['giant food', 'Giant Food'], ['stop & shop', 'Stop & Shop'], ['stop and shop', 'Stop & Shop'],
    ['food lion', 'Food Lion'], ['hannaford', 'Hannaford'], ['winn-dixie', 'Winn-Dixie'],
    ['whole foods', 'Whole Foods'], ['costco', 'Costco'], ['sam\'s club', 'Sam\'s Club'],
    ['sams club', 'Sam\'s Club'], ['walmart', 'Walmart'], ['hy-vee', 'Hy-Vee'], ['hyvee', 'Hy-Vee'],
    ['winco', 'WinCo'], ['sprouts', 'Sprouts'], ['shoprite', 'ShopRite'],
    ['piggly wiggly', 'Piggly Wiggly'], ['stater bros', 'Stater Bros'], ['raley\'s', 'Raley\'s'],
    ['schnucks', 'Schnucks'], ['price chopper', 'Price Chopper'], ['market basket', 'Market Basket'],
    ['ingles', 'Ingles'], ['save mart', 'Save Mart'], ['weis markets', 'Weis Markets'],
    ['brookshire', 'Brookshire\'s'], ['lidl', 'Lidl'], ['food city', 'Food City'],
    ['harmons', 'Harmons'],
  ];

  /// Explicit in-store preparation statements. Each is a strong, standalone signal.
  static const List<String> _storePrepPhrases = [
    'ground in store', 'ground in-store', 'store ground', 'store-ground',
    'ground fresh in store', 'freshly ground in store', 'ground in our store',
    'cut in store', 'cut in-store', 'cut & wrapped', 'cut and wrapped',
    'cut fresh in store', 'cut in our meat department', 'ground in our meat department',
    'packed in store', 'packaged in store', 'wrapped in store', 'packed in-store',
    'prepared in store', 'made in store', 'store made', 'store-made',
    'cut fresh daily', 'ground fresh daily', 'freshly ground', 'freshly cut',
    'packed in our store', 'prepared in our store', 'cut & wrapped in store',
    'our butchers', 'in-store butcher', 'store butcher', 'meat cut daily',
  ];

  /// Verbs that, in a `verb + for/by + retailer` construction, indicate the store
  /// (or its supplier) prepared the retail package rather than a branded plant.
  static const List<String> _prepVerbs = [
    'packed', 'ground', 'prepared', 'packaged', 'wrapped', 'cut', 'processed',
  ];

  /// Distinctive store-scale-label field labels. A national CPG package does not
  /// print per-pound pricing or a scale "PACKED ON" date — these are the in-store
  /// weigh-and-price scale.
  static const List<String> _scaleFields = [
    'total price', '\$/lb', 'price per lb', 'price/lb', 'per lb.', 'unit price',
    'packed on', 'sell by', 'sell-by', 'use or freeze by', 'pkg date',
    'packaged on', 'net wt price', 'wt/price',
  ];

  static final RegExp _randomWeightUpc =
      RegExp(r'(?<![0-9])0?2[0-9]{11}(?![0-9])');

  /// - [text]: normalized (lowercased, whitespace-collapsed) OCR label text.
  /// - [estFound]: whether an establishment number was already extracted.
  /// - [isMeat]: whether a meat/poultry species was recognized.
  static RetailExemption detect(
    String text, {
    required bool estFound,
    required bool isMeat,
  }) {
    // The exemption is only meaningful for a real meat product that carries no
    // establishment number. If an EST number is present, the plant is identified
    // and normal scoring applies.
    if (!isMeat || estFound) return RetailExemption.none;

    final signals = <String>[];

    // Retailer name present?
    String? store;
    for (final g in _grocers) {
      if (text.contains(g[0])) {
        store = g[1];
        break;
      }
    }

    final hasStorePrep = _storePrepPhrases.any(text.contains);
    if (hasStorePrep) signals.add('in-store preparation statement');

    var packedForRetailer = false;
    for (final v in _prepVerbs) {
      if (text.contains('$v for ') ||
          text.contains('$v by ') ||
          text.contains('$v fresh for ')) {
        packedForRetailer = true;
        break;
      }
    }
    if (packedForRetailer) signals.add('packed/ground-for-retailer statement');

    final fieldHits = _scaleFields.where(text.contains).toList();
    if (fieldHits.isNotEmpty) {
      signals.add('store scale-label fields (${fieldHits.length})');
    }

    final hasRandomWeightUpc = _randomWeightUpc.hasMatch(text);
    if (hasRandomWeightUpc) signals.add('random-weight barcode (UPC 2-prefix)');

    if (store != null) signals.add('retailer: $store');

    // Decision. Require positive evidence of in-store handling — a lone grocer
    // name or a lone generic field is not enough (national brands sell here too).
    final exempt = hasStorePrep ||
        packedForRetailer ||
        hasRandomWeightUpc ||
        (store != null && fieldHits.isNotEmpty) ||
        fieldHits.length >= 2;

    if (!exempt) return RetailExemption.none;
    return RetailExemption(
      isExempt: true,
      storeName: store,
      matchedSignals: signals,
    );
  }
}
