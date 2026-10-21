// Market-concentration summary shown directly under the top of a meat result
// (mirrors iOS MarketConcentrationSummary.swift).
//
// Rules (informational only — never a count, score or status input):
//   • Numbers come ONLY from existing app data: the PorkOwnerDatabase share
//     tables and the full-market HHI estimates (pork = PorkMarketHHI; beef /
//     chicken / turkey = the same estimates iOS MarketHHI and the Learn tab use).
//   • Species is the LABEL's species. A beef label never gets pork figures.
//   • No species, or a parent with no share entry for it → null (show nothing).

import '../services/big_four_ownership.dart';
import 'pork_owner_database.dart';

class MarketHHI {
  /// Full-market HHI estimates (iOS Markethhi.swift; Learn tab HHI table).
  static double estimatedFull(MeatSpecies s) {
    switch (s) {
      case MeatSpecies.beef:
        return 2000;
      case MeatSpecies.chicken:
        return 1300;
      case MeatSpecies.pork:
        return PorkMarketHHI.estimatedFull;
      case MeatSpecies.turkey:
        return 1050;
      case MeatSpecies.unknown:
        return 0;
    }
  }

  static String classification(MeatSpecies s) =>
      PorkMarketHHI.classification(estimatedFull(s));

  static List<PorkCorporateOwner> processors(MeatSpecies s) {
    switch (s) {
      case MeatSpecies.beef:
        return PorkOwnerDatabase.beefOwners;
      case MeatSpecies.chicken:
        return PorkOwnerDatabase.chickenOwners;
      case MeatSpecies.pork:
        return PorkOwnerDatabase.owners;
      case MeatSpecies.turkey:
        return PorkOwnerDatabase.turkeyOwners;
      case MeatSpecies.unknown:
        return const [];
    }
  }

  static String marketShareLabel(MeatSpecies s) {
    switch (s) {
      case MeatSpecies.beef:
        return 'US beef processing';
      case MeatSpecies.chicken:
        return 'US broiler processing';
      case MeatSpecies.pork:
        return 'US pork processing';
      case MeatSpecies.turkey:
        return 'US turkey processing';
      case MeatSpecies.unknown:
        return 'US meat processing';
    }
  }
}

enum ConcentrationBasis { brand, establishment }

class MarketConcentrationSummary {
  final MeatSpecies species;
  final String ownerId;
  final String ownerName;
  final ConcentrationBasis basis;
  final String marketLine;
  final String companyLine;
  final String? foreignLine;

  const MarketConcentrationSummary({
    required this.species,
    required this.ownerId,
    required this.ownerName,
    required this.basis,
    required this.marketLine,
    required this.companyLine,
    this.foreignLine,
  });

  static const title = 'Market concentration';
  static const sourceLine =
      'Approximate. Based on USDA GIPSA data, industry reports, and public company filings as of 2024–2026.';

  String get basisLine => basis == ConcentrationBasis.brand
      ? 'Company identified from the brand on the label.'
      : "Company identified from the plant's USDA establishment number.";

  static MeatSpecies speciesFromLabelValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'pork':
        return MeatSpecies.pork;
      case 'beef':
        return MeatSpecies.beef;
      case 'chicken':
        return MeatSpecies.chicken;
      case 'turkey':
        return MeatSpecies.turkey;
      default:
        return MeatSpecies.unknown;
    }
  }

  /// N the app's concentration text uses per species (CR4 beef, CR5 broilers,
  /// three pork firms, CR3 turkey).
  static int topFirmCount(MeatSpecies s) {
    switch (s) {
      case MeatSpecies.beef:
        return 4;
      case MeatSpecies.chicken:
        return 5;
      case MeatSpecies.pork:
      case MeatSpecies.turkey:
        return 3;
      case MeatSpecies.unknown:
        return 0;
    }
  }

  static String _grouped(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String? marketLineFor(MeatSpecies s) {
    final procs = [...MarketHHI.processors(s)]
      ..sort((a, b) => b.marketSharePct.compareTo(a.marketSharePct));
    final k = topFirmCount(s);
    if (k == 0 || procs.length < k) return null;
    final top = procs.take(k).fold(0.0, (sum, o) => sum + o.marketSharePct).toInt();
    final label = MarketHHI.marketShareLabel(s);
    final market = label[0].toUpperCase() + label.substring(1);
    var line = '$market: the top $k firms handle about $top% of production';
    if (s == MeatSpecies.pork && procs.length > k) {
      final all = procs.fold(0.0, (sum, o) => sum + o.marketSharePct).toInt();
      line += ' (top ${procs.length} ≈ $all%)';
    }
    line += '.';
    final hhi = MarketHHI.estimatedFull(s);
    if (hhi > 0) {
      line +=
          ' HHI ≈ ${_grouped(hhi.toInt())} — ${MarketHHI.classification(s).toLowerCase()}.';
    }
    return line;
  }

  static MarketConcentrationSummary? make(
      MeatSpecies s, PorkCorporateOwner owner, ConcentrationBasis basis) {
    if (s == MeatSpecies.unknown) return null;
    if (!MarketHHI.processors(s).any((o) => o.id == owner.id)) return null;
    final market = marketLineFor(s);
    if (market == null) return null;
    return MarketConcentrationSummary(
      species: s,
      ownerId: owner.id,
      ownerName: owner.name,
      basis: basis,
      marketLine: market,
      companyLine:
          '${owner.name}: about ${owner.marketSharePct.toInt()}% of ${MarketHHI.marketShareLabel(s)}.',
      foreignLine: owner.country == 'United States'
          ? null
          : 'Foreign-owned: ultimately owned by a company headquartered in ${owner.country}.',
    );
  }

  static PorkCorporateOwner? ownerForCompanyName(String name, MeatSpecies s) {
    final group = BigFourOwnership.groupForParentName(name);
    final o = group?.owner(s);
    if (o != null) return o;
    return PorkOwnerDatabase.detectOwnerForSpeciesInText(s, name)?.owner;
  }

  /// Order: brand's responsible company, the plant's parent (EST), the bundled
  /// brand-keyword table on the label text, the bundled EST table. Always the
  /// LABEL species' table.
  static MarketConcentrationSummary? resolve({
    required String? labelSpecies,
    String? brandCompany,
    String? estParentName,
    String scannedText = '',
    String? establishmentNumber,
  }) {
    final s = speciesFromLabelValue(labelSpecies);
    if (s == MeatSpecies.unknown) return null;
    final company = brandCompany?.trim() ?? '';
    if (company.isNotEmpty) {
      final o = ownerForCompanyName(company, s);
      if (o != null) return make(s, o, ConcentrationBasis.brand);
    }
    final parent = estParentName?.trim() ?? '';
    if (parent.isNotEmpty) {
      final o = ownerForCompanyName(parent, s);
      if (o != null) return make(s, o, ConcentrationBasis.establishment);
    }
    final hit = PorkOwnerDatabase.detectOwnerForSpeciesInText(s, scannedText);
    if (hit != null) return make(s, hit.owner, ConcentrationBasis.brand);
    final est = establishmentNumber ?? '';
    if (est.isNotEmpty) {
      final h = PorkOwnerDatabase.detectOwnerForSpeciesEstablishment(s, est);
      if (h != null) return make(s, h.owner, ConcentrationBasis.establishment);
    }
    return null;
  }
}
