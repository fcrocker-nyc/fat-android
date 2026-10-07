// North Carolina hog lagoons — INFORMATIONAL card for pork processed at a
// North Carolina plant. Never a score input: it changes no category status,
// the disclosure count, the index, or any penalty.
//
// Trigger: meat lane (not the prepared-food FDA lane, not seafood), species
// Pork, and the processing plant is in NC:
//   - single resolved plant → its state (fat/v1/establishments, else the
//     processor record's state, else the bundled FSIS plant-name map);
//   - ambiguous shared number → only when EVERY candidate plant is in NC;
//   - offline (no processor record, no endpoint) → the bundled FSIS map's
//     state for the label's mark;
//   - no plant / no state → never shown.
// Mirrors iOS FATAppMVP2/NCHogLagoonNotice.swift.
import '../models/fat_models.dart';
import 'establishments_service.dart';
import 'fsis_plant_names.dart';
import 'processor_service.dart';

class NcHogLagoonNotice {
  static const title = 'North Carolina hog farms and waste lagoons';
  static const body =
      "This pork was processed at a plant in North Carolina. Many of the state's hog farms store manure in open-air anaerobic lagoons and apply the liquid to nearby fields. North Carolina placed a moratorium on new and expanded hog farms in 1997 and made it permanent in 2007 for farms that use anaerobic lagoons as their primary waste treatment, so existing lagoon farms continue to operate. NC DEQ's April 2026 permit list shows 1,880 current swine permits, 1,866 of them with at least one lagoon, permitted for about 8.5 million hogs at a time.";
  static const caveat =
      "The package doesn't say which farm raised this pork. The plant's location is only a clue: hogs can travel long distances to slaughter.";
  static const sourceLabel =
      'Source: NC Department of Environmental Quality — Animal Feeding Operations';
  static const sourceUrl =
      'https://www.deq.nc.gov/about/divisions/water-resources/water-quality-permitting/animal-feeding-operations/program-summary';

  static const permitListLabel =
      'NC DEQ — List of Permitted Animal Facilities (April 23, 2026)';
  static const permitListUrl =
      'https://www.deq.nc.gov/listpermittedanimalfacilities20260423xlsx/open';

  /// One compact paragraph for the share / email summary.
  static String get shareParagraph =>
      '${title.toUpperCase()}:\n$body $caveat';

  static bool _isNC(String? s) {
    final t = (s ?? '').trim().toUpperCase();
    return t == 'NC' || t == 'NORTH CAROLINA';
  }

  static String? _nonBlank(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// State of the processing plant, or null when unknown. [offlineMark] (the
  /// label's EST mark) is used against the bundled FSIS map ONLY when there is
  /// neither a processor record nor shared candidates.
  static String? plantState(ProcessorRecord? processor, String? offlineMark) {
    final pd = processor;
    if (pd != null) {
      final s = _nonBlank(pd.resolvedPlant?.state) ?? _nonBlank(pd.state);
      if (s != null) return s;
      final number = pd.fullEstNumber?.split('+').first ?? pd.estNumber;
      return _nonBlank(
          FsisPlantNames.lookup(prefix: pd.estPrefix, digits: number)?.state);
    }
    final mark = _nonBlank(offlineMark);
    if (mark == null) return null;
    return _nonBlank(FsisPlantNames.lookup(digits: mark)?.state);
  }

  static bool applies(
    FATResult result, {
    ProcessorRecord? processor,
    List<FatEstablishment> shared = const [],
    String? offlineMark,
  }) {
    if (result.productType != ProductType.meat ||
        result.isPreparedFood ||
        result.categories[FATCategory.species]?.value != 'Pork') {
      return false;
    }
    if (shared.isNotEmpty) return shared.every((p) => _isNC(p.state));
    return _isNC(plantState(processor, offlineMark));
  }
}
