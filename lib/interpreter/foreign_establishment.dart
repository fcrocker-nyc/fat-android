// Foreign (imported) establishment marks.
//
// FAT's processor lookup decodes DOMESTIC FSIS establishment numbers from the
// MPI directory. An imported FSIS-regulated product carries the producing
// country's establishment mark instead — e.g. the EU identification mark
// "IT 1937 L CE" inside an oval — and no USDA establishment number appears on
// the retail package. Treating that as a missing EST number is a false
// compliance accusation, the same class of bug the prepared-food FDA lane fixed.
//
// EU identification mark (Regulation (EC) No 853/2004, Annex II Section I):
// oval containing the country code, the establishment's approval number, and
// the Community abbreviation (CE / EC / EU / EG / WE / EY / EK / …).
// Brazil (SIF) and Mexico (TIF) marks are also recognized.
//
// Verify a foreign establishment against FSIS's eligible foreign establishment
// lists: https://www.fsis.usda.gov/inspection/import-export/import-export-library/eligible-foreign-establishments

class ForeignEstablishment {
  /// Normalized identifier used for recall matching, e.g. "IT1937L".
  final String token;

  /// Human-readable mark as FAT renders it, e.g. "IT 1937 L".
  final String display;

  /// ISO 3166-1 alpha-2 code (EU marks) or scheme code ("BR"/"MX").
  final String countryCode;

  /// Country name, e.g. "Italy".
  final String countryName;

  /// Which scheme matched: 'eu', 'sif' (Brazil) or 'tif' (Mexico).
  final String scheme;

  /// Regional block inside some marks (e.g. the "BY" in "DE BY 12345 EG").
  /// Empty when the mark carries none.
  final String region;

  const ForeignEstablishment({
    required this.token,
    required this.display,
    required this.countryCode,
    required this.countryName,
    required this.scheme,
    this.region = '',
  });

  /// Keys to try against FSIS's eligible-foreign-establishment dataset, most
  /// specific first. FSIS lists a German plant as "BW03330", so the regional
  /// block has to be part of the key — while [token] stays region-free because
  /// that is the form quoted in recall notices.
  List<String> get lookupKeys {
    final keys = <String>[];
    if (region.isNotEmpty) keys.add('$countryCode$region$numberPart');
    keys.add(token);
    if (region.isNotEmpty) keys.add('$region$numberPart');
    return keys;
  }

  /// The mark minus the country code — "1937L" for "IT 1937 L".
  String get numberPart => token.startsWith(countryCode)
      ? token.substring(countryCode.length)
      : token;
}

class ForeignEstablishmentDetector {
  ForeignEstablishmentDetector._();

  // EU / EEA country codes that appear in an identification mark, mapped to
  // country names. Restricting the prefix to this list is what keeps the
  // pattern from firing on arbitrary two-letter + digit strings.
  static const Map<String, String> _euCountries = {
    'AT': 'Austria', 'BE': 'Belgium', 'BG': 'Bulgaria', 'HR': 'Croatia',
    'CY': 'Cyprus', 'CZ': 'Czechia', 'DK': 'Denmark', 'EE': 'Estonia',
    'FI': 'Finland', 'FR': 'France', 'DE': 'Germany', 'EL': 'Greece',
    'GR': 'Greece', 'HU': 'Hungary', 'IE': 'Ireland', 'IT': 'Italy',
    'LV': 'Latvia', 'LT': 'Lithuania', 'LU': 'Luxembourg', 'MT': 'Malta',
    'NL': 'Netherlands', 'PL': 'Poland', 'PT': 'Portugal', 'RO': 'Romania',
    'SK': 'Slovakia', 'SI': 'Slovenia', 'ES': 'Spain', 'SE': 'Sweden',
    'IS': 'Iceland', 'NO': 'Norway', 'CH': 'Switzerland', 'LI': 'Liechtenstein',
    'GB': 'United Kingdom', 'UK': 'United Kingdom',
  };

  // The Community abbreviation inside the oval, in the EU languages that use
  // a distinct form. "EU" is the post-2028 replacement now phasing in.
  static const String _abbrev = r'(?:CE|EC|EU|EG|EF|EK|EO|EY|EB|EZ|WE)';

  /// Detect a foreign establishment mark in scanned label text.
  /// Returns null when the label carries no recognizable foreign mark.
  static ForeignEstablishment? detect(String scannedText) {
    final text = scannedText
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // ── EU identification mark: <CC> <number><optional letter(s)> <ABBREV> ──
    // Real marks OCR in many shapes: "IT 1937 L CE", "IT1937L CE",
    // "ES 10.05934/SE CE", "PL 14161602 WE", "DE BY 12345 EG".
    final eu = RegExp(
      r'\b([A-Z]{2})[ .\-]?(?:([A-Z]{2})[ .\-]?)?'
      r'([0-9][0-9]{0,8}(?:[ .\-/][0-9A-Z]{1,6})?)'
      r'[ .\-/]?([A-Z]{1,2})?[ .\-]?'
      '$_abbrev'
      r'\b',
    );
    for (final m in eu.allMatches(text)) {
      final cc = m.group(1)!;
      final name = _euCountries[cc];
      if (name == null) continue;
      // Region block (e.g. "DE BY") is part of the mark but not the number.
      final region = m.group(2);
      var digits = (m.group(3) ?? '').replaceAll(RegExp(r'[^0-9A-Z]'), '');
      var suffix = (m.group(4) ?? '').replaceAll(RegExp(r'[^A-Z]'), '');
      if (digits.isEmpty) continue;
      // "IT 1937 L" can capture as digits="1937L"; split the trailing letters
      // back out so the mark renders the way it is printed on the package.
      if (suffix.isEmpty) {
        final tail = RegExp(r'^([0-9]+)([A-Z]+)$').firstMatch(digits);
        if (tail != null) {
          digits = tail.group(1)!;
          suffix = tail.group(2)!;
        }
      }
      final displayParts = <String>[
        cc,
        if (region != null && region.isNotEmpty) region,
        digits,
        if (suffix.isNotEmpty) suffix,
      ];
      return ForeignEstablishment(
        token: '$cc$digits$suffix',
        display: displayParts.join(' '),
        countryCode: cc,
        countryName: name,
        scheme: 'eu',
        region: region ?? '',
      );
    }

    // ── Brazil: SIF (Serviço de Inspeção Federal) ──
    final sif = RegExp(r'\bSIF[ .\-]?(\d{1,5})\b').firstMatch(text);
    if (sif != null) {
      final n = sif.group(1)!;
      return ForeignEstablishment(
        token: 'SIF$n',
        display: 'SIF $n',
        countryCode: 'BR',
        countryName: 'Brazil',
        scheme: 'sif',
      );
    }

    // ── Mexico: TIF (Tipo Inspección Federal) ──
    final tif = RegExp(r'\bTIF[ .\-]?(\d{1,5})\b').firstMatch(text);
    if (tif != null) {
      final n = tif.group(1)!;
      return ForeignEstablishment(
        token: 'TIF$n',
        display: 'TIF $n',
        countryCode: 'MX',
        countryName: 'Mexico',
        scheme: 'tif',
      );
    }

    return null;
  }

  static const String eligibleListUrl =
      'https://www.fsis.usda.gov/inspection/import-export/import-export-library/eligible-foreign-establishments';

  /// Copy for the Processor category when only a foreign mark is present.
  static String processorNote(ForeignEstablishment f) =>
      'Imported product — the label carries ${f.countryName}’s establishment '
      'mark (${f.display}) rather than a USDA establishment number. FAT’s '
      'processor lookup decodes domestic FSIS establishment numbers from the MPI '
      'directory, so it cannot resolve this one; foreign establishments are '
      'listed by FSIS on its eligible foreign establishment lists.';
}
