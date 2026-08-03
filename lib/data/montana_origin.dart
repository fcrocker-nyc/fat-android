// montana_origin.dart
// Calls out whether a scanned meat/poultry product has a Montana connection.
// Mirror of iOS MontanaOrigin.swift.
//
// Two DISTINCT, separately-labeled signals — never blended:
//   1. Processed in Montana — the resolved USDA/FSIS establishment is located in
//      Montana (state == MT). A federal fact about the plant, NOT where the
//      animal was raised.
//   2. Montana producer — the brand on the label matches a producer listed in
//      the Abundant Montana local-food directory. Directory membership only.

import 'package:flutter/material.dart';
import 'montana_data.dart';

class MontanaOriginResult {
  bool processedInMontana;
  String? processorName;
  String? processorCity;
  String? establishmentNumber;
  bool isAbundantMontanaProcessor;
  AbundantMontanaProducer? producerMatch;

  MontanaOriginResult({
    this.processedInMontana = false,
    this.processorName,
    this.processorCity,
    this.establishmentNumber,
    this.isAbundantMontanaProcessor = false,
    this.producerMatch,
  });

  bool get hasSignal => processedInMontana || producerMatch != null;
}

class MontanaOrigin {
  static MontanaOriginResult detect({
    String? state,
    String? establishmentName,
    String? city,
    String? establishmentNumber,
    String ocrText = '',
  }) {
    final r = MontanaOriginResult();

    final st = (state ?? '').trim().toUpperCase();
    if (st == 'MT' || st == 'MONTANA') {
      r.processedInMontana = true;
      r.processorName = establishmentName;
      r.processorCity = (city != null && city.isNotEmpty) ? city : null;
      r.establishmentNumber = establishmentNumber;
    }

    // Directory cross-reference: only when already confirmed Montana AND the
    // resolved name overlaps the directory name — never on the bare digit alone
    // (the app strips M/P/V prefixes, so digits can collide across plants).
    if (r.processedInMontana && establishmentNumber != null) {
      final digits = establishmentNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final info = MontanaData.abundantMontanaEsts[digits];
      if (info != null && _namesOverlap(info.fsisName, establishmentName ?? '')) {
        r.isAbundantMontanaProcessor = true;
      }
    }

    r.producerMatch = _matchProducer(ocrText);
    return r;
  }

  /// Best-effort US state code from a "…, Big Timber, MT, 59011" style address.
  static String? stateFromAddress(String address) {
    final m = RegExp(r'(?:^|,)\s*([A-Za-z]{2})\s*(?:,\s*\d{5}(?:-\d{4})?)?\s*$')
        .firstMatch(address.trim());
    return m?.group(1)?.toUpperCase();
  }

  static AbundantMontanaProducer? _matchProducer(String ocrText) {
    final hay = ' ${_normalize(ocrText)} ';
    if (hay.length <= 3) return null;
    AbundantMontanaProducer? best;
    for (final p in MontanaData.abundantMontanaProducers) {
      final n = p.normalizedName;
      if (n.length < 8) continue;
      if (hay.contains(' $n ') || hay.contains(' ${n}s ')) {
        if (best == null || n.length > best.normalizedName.length) best = p;
      }
    }
    return best;
  }

  static const _stop = {
    'meat', 'meats', 'beef', 'pork', 'farm', 'farms', 'ranch', 'packing',
    'processing', 'company', 'inc', 'llc', 'co', 'the', 'montana', 'foods', 'food'
  };

  static bool _namesOverlap(String a, String b) {
    Set<String> toks(String s) => _normalize(s)
        .split(' ')
        .where((t) => t.length >= 4 && !_stop.contains(t))
        .toSet();
    return toks(a).intersection(toks(b)).isNotEmpty;
  }

  static String _normalize(String s) {
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      buf.write(RegExp(r'[a-z0-9]').hasMatch(c) ? c : ' ');
    }
    return buf.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }
}

// ── Palette (Montana "Big Sky" blue, distinct from the green disclosure system) ──
const _mtBlue = Color(0xFF1D4773);
const _mtBlueBg = Color(0xFFECF3FA);
const _mtSky = Color(0xFF3773AB);
const _mtGold = Color(0xFFB48319);

class MontanaOriginCard extends StatelessWidget {
  final MontanaOriginResult origin;
  const MontanaOriginCard(this.origin, {super.key});

  static Widget? maybeFrom(MontanaOriginResult origin) =>
      origin.hasSignal ? MontanaOriginCard(origin) : null;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Row(children: const [
        Icon(Icons.landscape, size: 20, color: _mtBlue),
        SizedBox(width: 8),
        Text('Montana Connection',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: _mtBlue)),
      ]),
      const SizedBox(height: 10),
    ];

    if (origin.processedInMontana) {
      children.addAll([
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Icon(Icons.verified, size: 18, color: _mtSky),
          SizedBox(width: 6),
          Expanded(
            child: Text('Processed in Montana',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(_processorLine(),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        if (origin.isAbundantMontanaProcessor) ...[
          const SizedBox(height: 3),
          const Text('Listed in the Abundant Montana local-food directory.',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: _mtSky)),
        ],
        const SizedBox(height: 4),
        Text(
            'This is where the product was slaughtered/processed under USDA/FSIS '
            'inspection. Where the animal was born or raised may be elsewhere — '
            'the label’s Country/State-of-origin claim, not the plant location, '
            'tells you that.',
            style: TextStyle(fontSize: 11.5, color: Colors.black.withValues(alpha: 0.7))),
      ]);
    }

    if (origin.processedInMontana && origin.producerMatch != null) {
      children.add(const Divider(height: 18));
    }

    final p = origin.producerMatch;
    if (p != null) {
      children.addAll([
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Icon(Icons.eco, size: 18, color: _mtGold),
          SizedBox(width: 6),
          Expanded(
            child: Text('Montana producer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(_producerLine(p),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
            '“${p.name}” is listed in the Abundant Montana directory of local food '
            'producers. Directory membership — confirm the specific product’s '
            'origin on the label.',
            style: TextStyle(fontSize: 11.5, color: Colors.black.withValues(alpha: 0.7))),
      ]);
    }

    children.addAll([
      const SizedBox(height: 8),
      Text('Source: USDA/FSIS establishment directory · abundantmontana.com',
          style: TextStyle(fontSize: 10, color: Colors.black.withValues(alpha: 0.5))),
    ]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _mtBlueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mtBlue.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  String _processorLine() {
    final parts = <String>[];
    if ((origin.processorName ?? '').isNotEmpty) parts.add(origin.processorName!);
    if ((origin.processorCity ?? '').isNotEmpty) {
      parts.add('${origin.processorCity}, MT');
    } else {
      parts.add('Montana');
    }
    var line = parts.join(' — ');
    if ((origin.establishmentNumber ?? '').isNotEmpty) {
      line += ' (USDA/FSIS Est. ${origin.establishmentNumber})';
    }
    return line;
  }

  String _producerLine(AbundantMontanaProducer p) {
    var loc = p.town;
    if (p.county.isNotEmpty) {
      loc += loc.isEmpty ? '${p.county} County' : ', ${p.county} County';
    }
    final prods = p.products
        .split('|')
        .map((s) => s.trim())
        .where((s) => s != 'meat' && s.isNotEmpty)
        .take(4)
        .join(', ');
    var line = loc.isEmpty ? 'Montana' : loc;
    if (prods.isNotEmpty) line += ' · $prods';
    return line;
  }
}
