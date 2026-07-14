import 'package:flutter/material.dart';
import '../models/service_case_schema.dart';

/// In-app companion to the FAT Engineering Note "Service-Case Seafood Capture
/// Schema" (companion to Seafood Paper No. 5). Verbatim Flutter port of the iOS
/// `FATServiceCaseSchemaView`. Renders the schema's design principles, field
/// clusters, confidence vocabulary, resolution flow, and a worked record — the
/// last computed live from `ServiceCaseRecord` so the installed model and this
/// explainer can never drift apart.
///
/// Reached from LearnView → Seafood section → "Service-Case Capture Schema".
class ServiceCaseSchemaScreen extends StatelessWidget {
  const ServiceCaseSchemaScreen({super.key});

  static const Color _green = Color(0xFF248A5A); // 36,138,90
  static const Color _amber = Color(0xFFDC9A1E); // 220,154,30
  static const Color _red = Color(0xFFC83C3C); //   200,60,60
  static const Color _blue = Color(0xFF2E6EAF); //   46,110,175
  static const Color _ink = Colors.black;
  static const Color _muted = Color(0xFF505050); // 80,80,80
  static const Color _cream = Color(0xFFF6F4E8); // 246,244,232

  ServiceCaseRecord get _example => ServiceCaseRecord.snapperWorkedExample;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Service-Case Capture Schema',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lede(),
            const SizedBox(height: 22),
            _principlesSection(),
            const SizedBox(height: 22),
            _gateSection(),
            const SizedBox(height: 22),
            _clusterASection(),
            const SizedBox(height: 22),
            _clusterBSection(),
            const SizedBox(height: 22),
            _clusterCSection(),
            const SizedBox(height: 22),
            _confidenceVocabSection(),
            const SizedBox(height: 22),
            _resolutionSection(),
            const SizedBox(height: 22),
            _workedRecordSection(),
            const SizedBox(height: 22),
            _integrationSection(),
            const SizedBox(height: 22),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ── Lede ──────────────────────────────────────────────────────────────────

  Widget _lede() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Service-Case Seafood Capture Schema',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Spec v$serviceCaseSchemaVersion · Companion to Seafood Paper No. 5',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: _green),
        ),
        const SizedBox(height: 8),
        const Text(
          'Loose seafood at the full-service counter is governed by a USDA AMS placard, not an FDA package label — and whether any disclosure exists depends on the venue. This is the field schema that operationalizes that finding: the fields to capture, how each is normalized, and how confidence is assigned so the App never confirms more than a photo can prove.',
          style: TextStyle(fontSize: 16, height: 1.35, color: _ink),
        ),
      ],
    );
  }

  Widget _principlesSection() {
    return _calloutCard(
      color: _blue,
      title: 'Design principles',
      icon: Icons.straighten,
      children: [
        _bullet('Capture the sign, not the fish.',
            'Species identity carries a dedicated unverified state that no image input can upgrade.'),
        const SizedBox(height: 8),
        _bullet('The venue gate runs first.',
            'Establishment type decides whether a missing placard is a compliance finding or a non-event.'),
        const SizedBox(height: 8),
        _bullet('One displayed name, captured verbatim.',
            'The market name is stored exactly as shown, then resolved against the FDA Seafood List.'),
        const SizedBox(height: 8),
        _bullet('Two facts are mandated, one is not.',
            'Origin and method can reach known; species identity cannot — the schema encodes that asymmetry.'),
      ],
    );
  }

  // ── Gate ──────────────────────────────────────────────────────────────────

  Widget _gateSection() {
    return _section(
      number: '0',
      title: 'The gate: establishment classification',
      children: [
        const Text(
          'COOL binds PACA-licensed retailers and exempts fish markets, butcher shops, and food-service establishments. The gate derives two values used everywhere downstream: whether a COOL placard is owed here, and which enforcement lane applies. A processed or value-added item (breaded, marinated, crab cakes) is excluded from COOL entirely.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        _fieldCard([
          _fieldRow('establishment_type',
              'covered_retailer · exempt_fishmonger · exempt_butcher · exempt_foodservice · unknown'),
          _fieldRow('disclosure_required',
              'boolean (derived) — gates Cluster A scoring'),
          _fieldRow('processed_value_added',
              'boolean — if true, COOL not applicable'),
          _fieldRow(
              'category_lane', 'fda · fsis_siluriformes · shellfish_icssl'),
        ]),
      ],
    );
  }

  // ── Clusters ──────────────────────────────────────────────────────────────

  Widget _clusterASection() {
    return _section(
      number: '1',
      title: 'Cluster A — mandated disclosure (COOL)',
      children: [
        const Text(
          'The two facts a covered retailer must post for non-processed fish: country of origin and method of production. Legally required, so a legible capture is the App\'s strongest service-case signal — eligible for known. Required but absent resolves to missing; exempt venues resolve to not_applicable.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        _fieldCard([
          _fieldRow('country_of_origin',
              'array — "USA/Domestic" → US; "Product of X and Y" → list; multi-origin preserved'),
          _fieldRow('method_of_production',
              '"wild/wild-caught" → WILD; "farmed/aquaculture" → FARMED; mixed → MIXED'),
        ]),
      ],
    );
  }

  Widget _clusterBSection() {
    return _section(
      number: '2',
      title: 'Cluster B — identity fields',
      children: [
        const Text(
          'The market name is captured verbatim, then resolved through the FDA Seafood List. Three values come out of one sign at three confidence levels — and keeping them separate is the core integrity discipline.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        _fieldCard([
          _fieldRowChip('market_name_displayed',
              'exactly what the placard says', ConfidenceState.known),
          _fieldRowChip(
              'seafood_list_match',
              'acceptable + scientific name; the name maps, the fish doesn\'t',
              ConfidenceState.partial),
          _fieldRowChip(
              'species_identity',
              'what the animal actually is — never upgraded without a lab/DNA input',
              ConfidenceState.unverified),
          _fieldRow('substitution_risk',
              'category fraud prior (snapper/tuna/sea bass = high) — advisory only'),
          _fieldRow('product_form', 'fillet · steak · whole · loin · portion'),
        ]),
        const SizedBox(height: 10),
        const Text(
          'Lane routing: Siluriformes names (catfish, basa, swai, tra) → FSIS lane; molluscan shellfish → shellfish/ICSSL lane; everything else stays FDA.',
          style: TextStyle(fontSize: 14, height: 1.35, color: _muted),
        ),
      ],
    );
  }

  Widget _clusterCSection() {
    return _section(
      number: '3',
      title: 'Cluster C — context & hard keys',
      children: [
        const Text(
          'Most loose fish offers no hard identifier. The exception is molluscan shellfish: oysters, clams, and mussels keep a dealer/shellstock tag whose state-issued certification number resolves to a firm on FDA\'s ICSSL — a genuine Tier 1 direct match at the counter.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        _fieldCard([
          _fieldRowChip('shellfish_cert_number', 'dealer/shellstock tag → ICSSL',
              ConfidenceState.known),
          _fieldRowChip('fsis_establishment_number',
              'inspection legend (Siluriformes, rare)', ConfidenceState.known),
          _fieldRow('previously_frozen',
              'labeled_previously_frozen · presented_fresh · unknown — FDA misbranding datum'),
          _fieldRow('price_per_lb', 'soft substitution signal only'),
        ]),
      ],
    );
  }

  // ── Confidence vocabulary (rendered from the model) ───────────────────────

  Widget _confidenceVocabSection() {
    return _section(
      number: '4',
      title: 'Confidence vocabulary',
      children: [
        const Text(
          'The schema reuses the FAT disclosure vocabulary (known / partial / missing) and adds two states the service case requires.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < ConfidenceState.values.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chip(ConfidenceState.values[i]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ConfidenceState.values[i].definition,
                            style: const TextStyle(
                                fontSize: 13, height: 1.35, color: _ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Applies to: ${ConfidenceState.values[i].appliesTo}',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _calloutCard(
          color: _green,
          title: 'The one rule that protects the model',
          icon: Icons.verified_user,
          children: const [
            Text(
              'A record may state "this counter discloses farm-raised, Product of Chile" with confidence — but it may never state "this is Atlantic salmon" as fact. The displayed name is reported as displayed; species stays unverified with a substitution-risk note.',
              style: TextStyle(fontSize: 14, height: 1.35, color: _ink),
            ),
          ],
        ),
      ],
    );
  }

  // ── Resolution ────────────────────────────────────────────────────────────

  Widget _resolutionSection() {
    return _section(
      number: '5',
      title: 'Resolution flow',
      children: [
        const Text(
          'The captured record resolves to a single tier. Resolution stops at the highest tier that fires; lanes attach to the final record. Identity for any covered case without a hard key terminates at the Tier 3 advisory, because species can never be photo-confirmed.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        _fieldCard([
          _tierRow('Gate',
              'exempt or processed → not_applicable (capture name + advisory, no finding)'),
          _tierRow('Tier 1 — Direct',
              'hard key (shellfish cert → ICSSL, or FSIS estab.) → known direct match'),
          _tierRow('Tier 1 — Disclosure',
              'origin + method posted → known; required but absent → missing'),
          _tierRow('Tier 2 — Species name',
              'Seafood List match → partial (name maps, fish unverified)'),
          _tierRow('Tier 3 — Advisory',
              'species = unverified + substitution-risk note'),
          _tierRow('Lanes',
              'AMS COOL · FDA integrity · (NOAA SIMP if imported)'),
        ]),
      ],
    );
  }

  // ── Worked record (computed from the model) ───────────────────────────────

  Widget _workedRecordSection() {
    final example = _example;
    return _section(
      number: '6',
      title: 'Worked record',
      children: [
        const Text(
          'A snapper fillet at a covered supermarket counter — the highest-risk common case. Computed live from the installed ServiceCaseRecord:',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 10),
        _fieldCard([
          _resultRow('market name', example.marketNameDisplayed ?? '—',
              ConfidenceState.known),
          _resultRow('country of origin', example.countryOfOrigin.join(', '),
              example.originConfidence),
          _resultRow('method of production',
              example.methodOfProduction?.raw ?? '—', example.methodConfidence),
          _resultRow(
              'seafood-list name',
              example.seafoodListMatch?.acceptableMarketName ?? '—',
              example.seafoodListMatch?.confidence ?? ConfidenceState.missing),
          _resultRow('species identity', 'held open',
              example.speciesIdentityConfidence),
          _divider(),
          Row(
            children: [
              const Text('resolves to',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _muted)),
              const Spacer(),
              Text(example.resolve().raw,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900, color: _green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('enforcement lanes',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _muted)),
              const Spacer(),
              Flexible(
                child: Text(
                  example.enforcementLanes().join(' · '),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          'The low price (\$${example.pricePerLb != null ? example.pricePerLb!.toStringAsFixed(2) : '—'}/lb against the norm for true red snapper) does not change the tier, but it strengthens the Tier 3 advisory: of 120 nationwide "red snapper" samples DNA-tested by Oceana, only 7 actually were.',
          style: const TextStyle(fontSize: 14, height: 1.35, color: _muted),
        ),
      ],
    );
  }

  Widget _integrationSection() {
    return _section(
      number: '7',
      title: 'Category 13 integration',
      children: [
        const Text(
          'This schema is the operational detail inside Category 13 (Enforcement & Compliance) for the service-case lane, mirroring how the brand-search ladder sits inside Category 13 for packaged labels. Origin and method move on the same missing → partial → known track; the difference is the added unverified species state and the venue gate that precedes scoring.',
          style: TextStyle(fontSize: 15, height: 1.35, color: _ink),
        ),
      ],
    );
  }

  Widget _footer() {
    return const Text(
      'Source: FAT Engineering Note — Service-Case Seafood Capture Schema (companion to Seafood Research Series, Paper No. 5). farmanimaltransparency.com/fat-research/',
      style: TextStyle(
          fontSize: 12,
          color: _muted,
          fontStyle: FontStyle.italic,
          height: 1.35),
    );
  }

  // ── Building blocks ───────────────────────────────────────────────────────

  Widget _section({
    required String number,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                  color: _green, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(number,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _ink)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _fieldCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _fieldRow(String name, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: _green)),
        const SizedBox(height: 2),
        Text(desc,
            style: const TextStyle(fontSize: 13, height: 1.35, color: _ink)),
      ],
    );
  }

  Widget _fieldRowChip(String name, String desc, ConfidenceState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: _green)),
            ),
            const SizedBox(width: 8),
            _chip(state),
          ],
        ),
        const SizedBox(height: 3),
        Text(desc,
            style: const TextStyle(fontSize: 13, height: 1.35, color: _ink)),
      ],
    );
  }

  Widget _tierRow(String name, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: _green)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(desc,
              style: const TextStyle(fontSize: 13, height: 1.35, color: _ink)),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value, ConfidenceState state) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: _muted)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
        ),
        const SizedBox(width: 8),
        _chip(state),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _bullet(String bold, String rest) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: _blue)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: _ink, height: 1.35),
              children: [
                TextSpan(
                    text: bold,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                TextSpan(
                    text: ' $rest',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _calloutCard({
    required Color color,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _chip(ConfidenceState state) {
    final c = _chipColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          color: c,
        ),
      ),
    );
  }

  Color _chipColor(ConfidenceState state) {
    switch (state) {
      case ConfidenceState.known:
        return _green;
      case ConfidenceState.partial:
        return _amber;
      case ConfidenceState.unverified:
        return _red;
      case ConfidenceState.missing:
        return _muted;
      case ConfidenceState.notApplicable:
        return _blue;
    }
  }
}
