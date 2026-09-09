// Ground-beef blending-operator context (roadmap Phase 3).
// Mirrors iOS GroundBeefBlendingRegistry.swift.
//
// States documented industry operating pattern about the MATCHED ESTABLISHMENT
// — never a claim about the specific package in hand. Wording throughout is
// "this plant is documented as," never "this package contains."
//
// Big Four matches reuse PorkOwnerDatabase's already-verified beef EST table.
// Independent/QSR-dedicated grinders are matched by establishment name or DBA
// substring against the real FSIS-returned name string — no EST numbers are
// fabricated for them, since the source briefing names the companies and
// plants but not their establishment numbers.
//
// Source: "Lean Beef in America" briefing v.4, Sections 3 & 6; per-company
// import postures from the FAT working paper "Purchased Silence" (Sept. 2026),
// built on public CBP vessel-manifest records. Postures are QUALITATIVE only —
// the paper's own Section 7 requires API re-verification before any shipment
// figure appears in FAT public materials, so no counts are shown here.

import 'pork_owner_database.dart';

class GroundBeefBlendingContext {
  final String operatorLabel;
  final String note;

  /// Company-level ocean-import posture from public CBP vessel manifests,
  /// when documented. Includes masking status where a lawful CBP
  /// manifest-confidentiality filing limits what the public record shows.
  final String? importPosture;

  const GroundBeefBlendingContext(this.operatorLabel, this.note,
      {this.importPosture});
}

class GroundBeefBlendingRegistry {
  GroundBeefBlendingRegistry._();

  static const Set<String> _bigFourIDs = {
    'jbs_beef', 'tyson_beef', 'cargill_beef', 'national_beef',
  };

  static const String _bigFourNote =
      'Part of the "Big Four" beef packers (Tyson, JBS, Cargill, National Beef), '
      'which together process roughly 80–85% of U.S. fed cattle and run '
      'multi-plant grinding networks. Industry sourcing documents these '
      'operators as routinely blending imported lean trim — chiefly from '
      'Australia, New Zealand, Brazil, Uruguay, and Argentina — with domestic '
      'fatty trim to hit retail lean-percentage targets.';

  /// Per-company ocean-import posture (CBP vessel manifests via the
  /// "Purchased Silence" working paper). Manifest-confidentiality filings are
  /// lawful and routine — they hide nothing from regulators; noting one states
  /// what the public record can and cannot show, nothing more.
  static const Map<String, String> _importPostures = {
    'jbs_beef':
        'CBP vessel manifests document JBS USA as the largest ocean importer of frozen boneless beef among U.S. packers, supplied chiefly by its own Australian, Brazilian, and Canadian operations — an open, unmasked record.',
    'tyson_beef':
        "Tyson's ocean-import manifests have been confidential since September 2023 under a lawful and routine CBP manifest-confidentiality filing — its current import activity is not knowable from public records, and its pre-2023 record shows minimal ocean importing. The absence of data is itself a disclosure fact.",
    'cargill_beef':
        "CBP vessel manifests name Cargill's foreign suppliers — major Australian and New Zealand packers, with a Brazilian flow from Marfrig plants appearing in August 2026. Its import record was masked by a lawful and routine CBP manifest-confidentiality filing for most of 2024–2026; the mask lapsed in May 2026.",
    'national_beef':
        "CBP vessel manifests document National Beef as a moderate ocean importer, supplied in part by its own majority owner, Brazil's Marfrig Global Foods. Its record has been open since January 2020.",
  };

  static const List<(String, String, String)> _independents = [
    ('green bay dressed beef',
     'Green Bay Dressed Beef (American Foods Group)',
     'A division of American Foods Group — one of the larger independent beef processors operating outside the Big Four. Documented as a beef fabrication/grinding operation that blends trim to hit target lean points.'),
    ('american foods group',
     'American Foods Group',
     'One of the larger independent beef processors operating outside the Big Four. Documented as running beef fabrication/grinding operations that blend trim to hit target lean points.'),
    ('greater omaha',
     'Greater Omaha Packing',
     'One of the larger independent beef processors operating outside the Big Four. Documented as running beef fabrication/grinding operations that blend trim to hit target lean points. Notably, CBP vessel manifests show no ocean import-consignee record for Greater Omaha from 2015 through 2026 — a documented (though not provable, given lawful confidentiality masking) non-importer.'),
    ('golden state foods',
     'Golden State Foods',
     "A quick-service-dedicated grinder — one of the two companies most associated with grinding and forming beef patties for chains like McDonald's, running multiple U.S. plants dedicated to that customer relationship rather than the open wholesale trim market."),
    ('osi group',
     'OSI Group',
     'A quick-service-dedicated grinder — one of the two companies most associated with grinding and forming beef patties for major chains, running multiple U.S. plants dedicated to that customer relationship rather than the open wholesale trim market.'),
  ];

  static const String sourceLine =
      'Sources: "Lean Beef in America" research briefing v.4, §§3, 6; import '
      'postures from public CBP vessel manifests (FAT working paper "Purchased '
      'Silence," Sept. 2026). Documents this plant\'s operating pattern and its '
      'operator\'s public import record — not this specific package\'s contents.';

  static GroundBeefBlendingContext? lookup({
    String? establishmentNumber,
    String? establishmentName,
    String? dba,
  }) {
    // Big Four — via the verified EST → owner table in PorkOwnerDatabase.
    if (establishmentNumber != null) {
      final owner =
          PorkOwnerDatabase.detectBeefOwnerForEstablishment(establishmentNumber);
      if (owner != null && _bigFourIDs.contains(owner.owner.id)) {
        return GroundBeefBlendingContext(owner.owner.name, _bigFourNote,
            importPosture: _importPostures[owner.owner.id]);
      }
    }

    // Independents / QSR-dedicated grinders — by establishment name/DBA match.
    final haystacks = [establishmentName, dba]
        .whereType<String>()
        .map((s) => s.toLowerCase())
        .toList();
    for (final (match, label, note) in _independents) {
      if (haystacks.any((h) => h.contains(match))) {
        return GroundBeefBlendingContext(label, note);
      }
    }
    return null;
  }
}
