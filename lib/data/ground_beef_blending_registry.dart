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
// Source: "Lean Beef in America" briefing v.4, Sections 3 & 6.

import 'pork_owner_database.dart';

class GroundBeefBlendingContext {
  final String operatorLabel;
  final String note;
  const GroundBeefBlendingContext(this.operatorLabel, this.note);
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

  static const List<(String, String, String)> _independents = [
    ('green bay dressed beef',
     'Green Bay Dressed Beef (American Foods Group)',
     'A division of American Foods Group — one of the larger independent beef processors operating outside the Big Four. Documented as a beef fabrication/grinding operation that blends trim to hit target lean points.'),
    ('american foods group',
     'American Foods Group',
     'One of the larger independent beef processors operating outside the Big Four. Documented as running beef fabrication/grinding operations that blend trim to hit target lean points.'),
    ('greater omaha',
     'Greater Omaha Packing',
     'One of the larger independent beef processors operating outside the Big Four. Documented as running beef fabrication/grinding operations that blend trim to hit target lean points.'),
    ('golden state foods',
     'Golden State Foods',
     "A quick-service-dedicated grinder — one of the two companies most associated with grinding and forming beef patties for chains like McDonald's, running multiple U.S. plants dedicated to that customer relationship rather than the open wholesale trim market."),
    ('osi group',
     'OSI Group',
     'A quick-service-dedicated grinder — one of the two companies most associated with grinding and forming beef patties for major chains, running multiple U.S. plants dedicated to that customer relationship rather than the open wholesale trim market.'),
  ];

  static const String sourceLine =
      'Source: "Lean Beef in America" research briefing v.4, §§3, 6 — '
      'documents this plant\'s operating pattern, not this specific package\'s contents.';

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
        return GroundBeefBlendingContext(owner.owner.name, _bigFourNote);
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
