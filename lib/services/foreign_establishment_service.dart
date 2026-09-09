// Resolve a foreign establishment mark to the plant FSIS lists as eligible to
// export to the United States.
//
// FSIS publishes eligible foreign establishments only as ~39 per-country PDFs
// (Import & Export Library), so the dataset is parsed offline and served from
// the FAT site — /wp-json/fat/v1/foreign-establishment, backed by a JSON media
// attachment that rolls forward. This is the import-side counterpart to the
// domestic MPI-directory processor lookup.

import 'dart:convert';
import 'package:http/http.dart' as http;

class ForeignEstablishmentRecord {
  /// Plant name as FSIS lists it, e.g. "Bome SRL".
  final String name;
  final String country;
  final String iso;

  /// Establishment number as FSIS prints it, e.g. "1937L".
  final String est;

  /// Product scope of the country list: Meat/Poultry, Egg Products, Siluriformes.
  final String scope;

  /// False when FSIS has delisted the plant and not relisted it — it is not
  /// currently eligible to export to the U.S.
  final bool eligible;

  final String dateListed;
  final String dateDelisted;
  final String dateRelisted;

  /// Dataset version (the date the EFE lists were parsed).
  final String version;

  const ForeignEstablishmentRecord({
    required this.name,
    required this.country,
    required this.iso,
    required this.est,
    required this.scope,
    required this.eligible,
    required this.dateListed,
    required this.dateDelisted,
    required this.dateRelisted,
    required this.version,
  });

  factory ForeignEstablishmentRecord.fromJson(Map<String, dynamic> j) =>
      ForeignEstablishmentRecord(
        name: (j['name'] ?? '').toString(),
        country: (j['country'] ?? '').toString(),
        iso: (j['iso'] ?? '').toString(),
        est: (j['est'] ?? '').toString(),
        scope: (j['scope'] ?? '').toString(),
        eligible: j['eligible'] != false,
        dateListed: (j['date_listed'] ?? '').toString(),
        dateDelisted: (j['date_delisted'] ?? '').toString(),
        dateRelisted: (j['date_relisted'] ?? '').toString(),
        version: (j['version'] ?? '').toString(),
      );
}

class ForeignEstablishmentService {
  ForeignEstablishmentService._();
  static final ForeignEstablishmentService instance =
      ForeignEstablishmentService._();

  static const String _base =
      'https://farmanimaltransparency.com/wp-json/fat/v1/foreign-establishment';

  final Map<String, ForeignEstablishmentRecord?> _cache = {};

  /// Try each key in order (most specific first). Returns null when the mark
  /// does not resolve — a lookup miss or outage never blocks a scan result.
  Future<ForeignEstablishmentRecord?> resolve(List<String> keys) async {
    for (final key in keys) {
      final k = key.trim().toUpperCase();
      if (k.isEmpty) continue;
      if (_cache.containsKey(k)) {
        final hit = _cache[k];
        if (hit != null) return hit;
        continue;
      }
      try {
        final res = await http
            .get(Uri.parse('$_base?token=${Uri.encodeQueryComponent(k)}'))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) {
          _cache[k] = null;
          continue;
        }
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['found'] == true) {
          final rec = ForeignEstablishmentRecord.fromJson(body);
          _cache[k] = rec;
          return rec;
        }
        _cache[k] = null;
      } catch (_) {
        _cache[k] = null;
      }
    }
    return null;
  }
}
