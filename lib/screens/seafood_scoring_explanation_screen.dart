import 'package:flutter/material.dart';

/// Single source of truth for the in-app explanation of the FAT Score (seafood).
/// Verbatim port of iOS FATSeafoodScoringExplanationView.
/// Mirrors the canonical page at:
/// https://farmanimaltransparency.com/how-fat-scores-labels/how-fat-scores-seafood-labels/
class SeafoodScoringExplanationScreen extends StatelessWidget {
  const SeafoodScoringExplanationScreen({super.key});

  static const Color _green = Color.fromRGBO(36, 138, 90, 1);
  static const Color _amber = Color.fromRGBO(220, 154, 30, 1);
  static const Color _red = Color.fromRGBO(200, 60, 60, 1);
  static const Color _blue = Color.fromRGBO(46, 110, 175, 1);
  static const Color _ink = Colors.black;
  static const Color _muted = Color.fromRGBO(80, 80, 80, 1);
  static const Color _pageBG = Color.fromRGBO(246, 244, 232, 1);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _pageBG,
        appBar: AppBar(
          backgroundColor: _pageBG,
          foregroundColor: _ink,
          elevation: 0,
          title: const Text('How FAT Scores Seafood Labels',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _ink)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _intersperse(
              <Widget>[
                _lede(),
                _regulatoryForkCallout(),
                _threeStepsSection(),
                _disclosureStatusSection(),
                _credibilitySection(),
                _whoStandsBehindSection(),
                _categoriesSection(),
                _colorSystemSection(),
                _gradeScaleSection(),
                _doesNotMeasureSection(),
                _websiteFooter(),
              ],
              const SizedBox(height: 22),
            ),
          ),
        ),
      ),
    );
  }

  static List<Widget> _intersperse(List<Widget> children, Widget gap) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(gap);
      out.add(children[i]);
    }
    return out;
  }

  // ─── Sections ──────────────────────────────────────────────────────────────

  Widget _lede() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('The FAT Score — Seafood',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: _ink)),
        SizedBox(height: 8),
        Text(
          'FAT evaluates seafood labels using the same three-step model that drives every meat score: what information is disclosed, how credible the claim is, and what the public record says about the entities behind the product. The 16-category framework is structurally identical — what changes are the categories themselves, adapted to the regulatory, supply-chain, and species-identification realities of seafood.',
          style: TextStyle(fontSize: 16, color: _ink, height: 1.35),
        ),
      ],
    );
  }

  Widget _regulatoryForkCallout() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blue.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_rounded, color: _blue, size: 18),
              SizedBox(width: 8),
              Text('Critical regulatory fork',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _blue)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Catfish and all other Siluriformes are regulated by USDA FSIS — not FDA. Every other seafood product falls under FDA. This split affects which inspection mark to look for, which establishment number unlocks enforcement data, which banned-substance testing regime applies, and which species-naming rules govern the label. FAT scores this fork explicitly in Categories 1, 2, 6, 11, and 13.',
            style: TextStyle(fontSize: 14, color: _ink, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _threeStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('The Three-Step Model'),
        const SizedBox(height: 10),
        const Text(
          'FAT runs every label through the same three questions. Each step asks something different about the label.',
          style: TextStyle(fontSize: 15, color: _ink, height: 1.35),
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('1. What is disclosed?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('2. How credible is the disclosure?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('3. Who stands behind the label?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Steps 1 and 2 score the label itself. Step 3 surfaces the processor\'s FDA or FSIS enforcement record (catfish/Siluriformes is FSIS — see the regulatory fork above), the brand owner and corporate parent, foreign-ownership status, and economic-concentration / HHI context for the seafood supply chain. Same model as meat.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        const Text(
          'Same model documented at farmanimaltransparency.com/learn-how-to-read-meat-labels/',
          style: TextStyle(
              fontSize: 12,
              color: _muted,
              fontStyle: FontStyle.italic,
              height: 1.35),
        ),
      ],
    );
  }

  Widget _disclosureStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Step 1 — Information Disclosed'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '✔',
            color: _green,
            title: 'Known',
            detail:
                'The label clearly discloses this information. Example: "Wild-caught, MSC Certified, North Pacific Alaskan Pollock." Full credit.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '◑',
            color: _amber,
            title: 'Partial',
            detail:
                'Some information is present but details are limited. Example: "Wild-caught" with no fishery, vessel, or certification named. Partial credit.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '✕',
            color: _red,
            title: 'Missing',
            detail:
                'The label does not address this category. A lack of disclosure is information — not an accusation of misconduct. No credit.'),
      ],
    );
  }

  Widget _credibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Step 2 — Credibility'),
        const SizedBox(height: 10),
        const Text(
          'FAT places every disclosed claim into one of four credibility tiers. Higher tiers carry more score weight.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '✔',
            color: _green,
            title: 'Third-Party Audited',
            detail:
                'Independent audit by an organization that is neither the producer nor the regulator. Wild-caught: MSC. Farmed: ASC or BAP. The seafood equivalents of USDA Organic or Certified Humane.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🏛',
            color: _amber,
            title: 'USDA-Reviewed',
            detail:
                'USDA-administered program with audit teeth — primarily relevant for catfish and other Siluriformes under FSIS inspection, plus USDA Process-Verified Program where applied to seafood operations.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '📄',
            color: _amber,
            title: 'Producer Affidavit',
            detail:
                'FDA or FSIS approved the label language, backed by producer-maintained records and affidavits. No independent on-site audit. Examples: COOL-compliant country of origin, FSIS-approved species name claims.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '⚠',
            color: _red,
            title: 'Unverified Marketing',
            detail:
                'Printed on the label with no known third-party audit and no government label-language approval. Examples: "sustainably sourced," "ocean-fresh," "responsibly farmed," "natural."'),
      ],
    );
  }

  Widget _whoStandsBehindSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Step 3 — Who Stands Behind the Label?'),
        const SizedBox(height: 10),
        const Text(
          'The label is one source of information. The entities behind the label are another. FAT surfaces what the public record says about them.',
          style: TextStyle(fontSize: 15, color: _ink, height: 1.35),
        ),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🏭',
            color: _green,
            title: 'Processor & Enforcement Record',
            detail:
                'The processor or facility is identified on the label (FSIS establishment number for catfish/Siluriformes, FDA registration elsewhere). Its public record — recalls, import alerts, HACCP enforcement, and processor warning letters — is tied to that identifier.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🏢',
            color: _amber,
            title: 'Brand Owner & Corporate Parent',
            detail:
                'Many seafood brands are subsidiaries of much larger corporations. FAT discloses both the brand on the package and the corporate parent.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🌐',
            color: _amber,
            title: 'Beneficial & Foreign Ownership',
            detail:
                'Seafood is one of the most globally consolidated U.S. food categories. Several leading shelf brands are foreign-owned. FAT flags foreign ownership when present — neutrally, as a fact, not a verdict.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '📊',
            color: _amber,
            title: 'Economic Concentration — HHI & Market Structure',
            detail:
                'Market concentration in the relevant seafood supply chain — measured by the Herfindahl-Hirschman Index — and any DOJ or FTC antitrust history involving the parent company. Affects price formation, contract terms, and producer leverage even when the label says nothing about them.'),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Step 3 doesn\'t change whether a label is honest about what it claims — that\'s Step 1 and Step 2. Step 3 says who actually stands behind the label and what their record looks like.',
            style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _categoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('The 16 Seafood Categories'),
        const SizedBox(height: 10),
        const Text(
          'Same 16-slot framework as meat, with seafood-specific definitions. Categories 1–14 are scored in the app; 15 and 16 live on the website for now.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _intersperse(
            <Widget>[
              _categoryRow(1, 'Regulatory Required Language',
                  appScored: true, passFail: true),
              _categoryRow(2, 'Species Identity',
                  appScored: true, passFail: true),
              _categoryRow(3, 'Strain / Variety', appScored: true),
              _categoryRow(4, 'Country / Origin', appScored: true),
              _categoryRow(5, 'Farm / Vessel / Fishery', appScored: true),
              _categoryRow(6, 'Harvest Timing / Age', appScored: true),
              _categoryRow(7, 'Processor', appScored: true, passFail: true),
              _categoryRow(8, 'Who (Owner / Parent)', appScored: true),
              _categoryRow(9, 'Brand', appScored: true),
              _categoryRow(10, 'Feed / Production Method', appScored: true),
              _categoryRow(11, 'Fish Welfare', appScored: true),
              _categoryRow(12, 'Medicine / Antibiotics / Chemicals',
                  appScored: true),
              _categoryRow(13, 'Hormones', appScored: true),
              _categoryRow(14, 'Quality & Handling', appScored: true),
              _categoryRow(15, 'Organic / Certification', appScored: true),
              _categoryRow(16, 'Supply-Chain Intermediaries', appScored: true),
            ],
            const SizedBox(height: 6),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '“Mandatory · pass/fail” marks the legally required disclosures — the Required Basics, Species (the statement of identity / acceptable market name), and the Processor identifier. Those three score present-or-absent, with no partial credit.',
            style: TextStyle(fontSize: 13, color: _muted, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _colorSystemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('The Color System'),
        const SizedBox(height: 10),
        const Text(
          'The same three colors used for meat. Same color, same meaning — across every category and every product type.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        _colorRow(
            color: _green,
            label: 'Green',
            detail:
                'Fully disclosed and independently verified by an accredited third-party certifier (e.g. MSC, ASC, or BAP certification with a documented audit).'),
        const SizedBox(height: 10),
        _colorRow(
            color: _amber,
            label: 'Amber',
            detail:
                'Partially disclosed, or government-reviewed but not independently audited — including a USDA Process Verified Program, the USDA FSIS catfish inspection mark, or COOL-compliant origin without farm or vessel named.'),
        const SizedBox(height: 10),
        _colorRow(
            color: _red,
            label: 'Red',
            detail:
                'Not disclosed on this label. No fishery, no vessel, no farm, no processor, no certification — recorded as a gap, not a violation.'),
      ],
    );
  }

  Widget _gradeScaleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Grade Scale'),
        const SizedBox(height: 10),
        _gradeRow('A',
            range: '80–100',
            desc: 'Comprehensive disclosure, strongly backed claims',
            color: const Color.fromRGBO(52, 168, 83, 1)),
        const SizedBox(height: 10),
        _gradeRow('B',
            range: '65–79',
            desc: 'Good disclosure with solid credibility',
            color: const Color.fromRGBO(100, 180, 70, 1)),
        const SizedBox(height: 10),
        _gradeRow('C',
            range: '50–64',
            desc: 'Moderate disclosure or mixed credibility',
            color: const Color.fromRGBO(251, 192, 45, 1)),
        const SizedBox(height: 10),
        _gradeRow('D',
            range: '35–49',
            desc: 'Limited disclosure or weakly backed claims',
            color: const Color.fromRGBO(234, 134, 0, 1)),
        const SizedBox(height: 10),
        _gradeRow('F',
            range: '0–34',
            desc: 'Minimal disclosure, little or no verification',
            color: _red),
      ],
    );
  }

  Widget _doesNotMeasureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('What the FAT Score Does Not Measure'),
        const SizedBox(height: 8),
        _bullet('Product quality, taste, or freshness'),
        const SizedBox(height: 8),
        _bullet('Nutritional value, mercury level, or health benefits'),
        const SizedBox(height: 8),
        _bullet('Price, value, or purchasing recommendation'),
        const SizedBox(height: 8),
        _bullet(
            'Environmental impact (Category 15) and economic concentration (Category 16) — website only at this time'),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'A high FAT Score means the producer told you more about the fish and backed it up better. What you do with that information is your decision.',
            style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _websiteFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Divider(),
          SizedBox(height: 6),
          Text('Full reference, including category-by-category seafood definitions, lives at:',
              style: TextStyle(fontSize: 13, color: _muted, height: 1.35)),
          SizedBox(height: 6),
          Text('farmanimaltransparency.com / how-fat-scores-seafood-labels',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color.fromRGBO(36, 138, 90, 1))),
        ],
      ),
    );
  }

  // ─── Reusable row helpers ──────────────────────────────────────────────────

  Widget _sectionHeader(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900));
  }

  Widget _statusRow({
    required String symbol,
    required Color color,
    required String title,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(symbol,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(detail,
                  style:
                      const TextStyle(fontSize: 14, color: _ink, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryRow(int n, String name,
      {required bool appScored, bool passFail = false}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: appScored
                ? _green.withValues(alpha: 0.15)
                : _muted.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text('$n',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: appScored ? _green : _muted)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500, color: _ink)),
        ),
        const SizedBox(width: 4),
        if (passFail)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Mandatory · pass/fail',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          ),
        if (!appScored)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _muted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Web only',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted)),
          ),
      ],
    );
  }

  Widget _colorRow({
    required Color color,
    required String label,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color)),
              const SizedBox(height: 2),
              Text(detail,
                  style:
                      const TextStyle(fontSize: 14, color: _ink, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradeRow(String grade,
      {required String range, required String desc, required Color color}) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(grade,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(range,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc,
                  style:
                      const TextStyle(fontSize: 14, color: _ink, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _muted)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 15, color: _ink, height: 1.35)),
        ),
      ],
    );
  }
}
