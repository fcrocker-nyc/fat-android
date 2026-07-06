import 'package:flutter/material.dart';

/// Single source of truth for the in-app explanation of the FAT Score (meat).
/// Verbatim port of iOS FATScoringExplanationView.
/// Mirrors the canonical page at:
/// https://farmanimaltransparency.com/how-fat-scores-labels/how-fat-scores-meat-labels/
class ScoringExplanationScreen extends StatelessWidget {
  const ScoringExplanationScreen({super.key});

  // Color helpers (match the website's three-color system)
  static const Color _green = Color.fromRGBO(36, 138, 90, 1);
  static const Color _amber = Color.fromRGBO(220, 154, 30, 1);
  static const Color _red = Color.fromRGBO(200, 60, 60, 1);
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
          title: const Text('How FAT Scores Meat Labels',
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
                _threeStepsSection(),
                _scoreWeightingSection(),
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

  // Insert [gap] between every pair of [children].
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
      children: [
        const Text('The FAT Score — Meat & Poultry',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        const Text(
          'A 0–100 transparency index for meat, poultry, lamb, and turkey labels. Not a quality rating, not a nutrition score, not a recommendation. A measure of how much a label actually tells you about the animal and the supply chain, how well it backs those claims up, and what the public record says about the entities behind the product.',
          style: TextStyle(fontSize: 16, color: _ink, height: 1.35),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            'Seafood uses a separate but parallel framework — see "How FAT Scores Seafood Labels."',
            style: TextStyle(
                fontSize: 13,
                color: _muted,
                fontStyle: FontStyle.italic,
                height: 1.35),
          ),
        ),
      ],
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
          'Steps 1 and 2 score the label itself. Step 3 surfaces FSIS / FDA enforcement history, the brand owner and corporate parent, foreign-ownership status, and economic-concentration / HHI context for the supply chain. Together they produce the 0–100 FAT Score.',
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

  Widget _scoreWeightingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('How the 0–100 Score Splits'),
        const SizedBox(height: 10),
        const Text(
          'The 0–100 FAT Score is a weighted sum of the two pillars below. Disclosure carries the heavier weight because the most common label failure is silence — categories left blank altogether.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _pillarBox(
                  title: 'Disclosure',
                  pts: '70 pts',
                  color: _green,
                  detail:
                      'Pillar 1 — what each of the 16 scored categories actually says on the label.'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _pillarBox(
                  title: 'Credibility',
                  pts: '30 pts',
                  color: _amber,
                  detail:
                      'Pillar 2 — for the categories that did say something, how well that claim is backed.'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Each scored disclosure category contributes up to 5 pts when fully Known, 2 pts when Partial, 0 when Missing — with two weight exceptions: Breed is worth 3 pts and Farm / Ranch 6 pts. Credibility is averaged across the categories the label actually addressed.',
            style: TextStyle(fontSize: 14, color: _ink, height: 1.35),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Seven categories are all-or-nothing — full credit if disclosed, 0 if not, with no partial credit. Three are legally mandatory (pass/fail): the Required Basics, Species (the common or usual product name), and the Processor identifier (the FSIS establishment number, or for FDA seafood the name and place of business). Four more are inherently binary: Breed (3 pts), Country of Origin (5 pts), Farm / Ranch (6 pts), and Age at Slaughter (5 pts) — a specific disclosure earns full credit, while a vague marketing term (a generic “family farm”, an unspecified “young”) earns 0. Separately, a plant\'s environmental and worker-safety enforcement record applies as a penalty against the Processor category\'s disclosure score, and the two penalties stack: EPA violations −3, OSHA violations −2 (no record = 0).',
            style: TextStyle(fontSize: 14, color: _ink, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _pillarBox({
    required String title,
    required String pts,
    required Color color,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const Spacer(),
              Text(pts,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail,
              style: const TextStyle(fontSize: 13, color: _ink, height: 1.35)),
        ],
      ),
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
                'The label clearly discloses this information. Full credit.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '◑',
            color: _amber,
            title: 'Partial',
            detail:
                'Some information is present but details are limited or non-specific. Partial credit.'),
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
                'Independent on-farm audit by an organization that is neither the producer nor the regulator. Examples: USDA Organic (NOP-accredited annual audit), Certified Humane, AWA, GAP, American Grassfed Association, MSC / ASC / BAP for seafood. Highest weight.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🏛',
            color: _amber,
            title: 'USDA-Reviewed',
            detail:
                'USDA-administered program with audit teeth — broader than just label-language approval. Examples: USDA AMS Process-Verified Program (PVP), USDA quality-grade shields (Prime / Choice / Select), FSIS catfish inspection. Strong weight.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '📄',
            color: _amber,
            title: 'Producer Affidavit',
            detail:
                'FSIS approved the wording on the label, backed by the producer\'s own affidavit and internal records. No independent on-farm audit. Examples: "Grass Fed" or "No Antibiotics Ever" without a third-party cert mark, "Raised using Regenerative Agriculture Practices." Government oversight exists at the label-approval stage only. Moderate weight.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '⚠',
            color: _red,
            title: 'Unverified Marketing',
            detail:
                'Printed on the label with no third-party audit and no government label-language approval. Examples: "humanely raised" without a certifier, "farm fresh," "all natural," "sustainably sourced." Low weight.'),
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
                'The processor is identified by FSIS establishment number on the label (or, for FDA seafood, by name and place of business). Its public enforcement record — recalls, residue violations, humane-handling actions, FDA import alerts, plus EPA environmental violations and OSHA worker-safety citations — is tied to that establishment. EPA (−3) and OSHA (−2) violations apply as stacking penalties against the Processor category\'s disclosure score.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🏢',
            color: _amber,
            title: 'Brand Owner & Corporate Parent',
            detail:
                'The brand on the package is often a subsidiary product line of a much larger corporation (e.g., Eckrich and Nathan\'s Famous are Smithfield brands; Hillshire Farm and Jimmy Dean are Tyson brands). FAT discloses both the brand and the corporate parent.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '🌐',
            color: _amber,
            title: 'Beneficial & Foreign Ownership',
            detail:
                'WH Group (China) owns Smithfield. JBS and Marfrig (Brazil) own significant U.S. beef capacity. Several leading seafood brands are foreign-owned. FAT flags foreign ownership when present — neutrally, as a fact, not a verdict.'),
        const SizedBox(height: 10),
        _statusRow(
            symbol: '📊',
            color: _amber,
            title: 'Economic Concentration — HHI & Market Structure',
            detail:
                'Market concentration in the relevant supply chain — measured by the Herfindahl-Hirschman Index — and any DOJ or FTC antitrust history involving the parent company. Highly concentrated supply chains affect price formation, contract terms, and producer leverage even when the label itself says nothing about them.'),
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
        _sectionHeader('The 16 Meat & Poultry Categories'),
        const SizedBox(height: 10),
        const Text(
          'FAT evaluates every meat, poultry, lamb, and turkey label across the same 16 categories — no cherry-picking, no hiding gaps. All 16 are scored in the app.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _intersperse(
            <Widget>[
              _categoryRow(1, 'USDA / FSIS Required Language',
                  appScored: true, passFail: true),
              _categoryRow(2, 'Species', appScored: true, passFail: true),
              _categoryRow(3, 'Breed', appScored: true),
              _categoryRow(4, 'Country / Origin', appScored: true),
              _categoryRow(5, 'Farm / Ranch', appScored: true),
              _categoryRow(6, 'Supply-Chain Intermediaries', appScored: true),
              _categoryRow(7, 'Processor', appScored: true, passFail: true),
              _categoryRow(8, 'Feed', appScored: true),
              _categoryRow(9, 'Animal Welfare', appScored: true),
              _categoryRow(10, 'Quality / Palatability', appScored: true),
              _categoryRow(11, 'Dietary Attributes', appScored: true),
              _categoryRow(12, 'Medicine / Antibiotics', appScored: true),
              _categoryRow(13, 'Hormones', appScored: true),
              _categoryRow(14, 'Age at Slaughter', appScored: true),
              _categoryRow(15, 'Organic (USDA NOP)', appScored: true),
              _categoryRow(16, 'FSIS Enforcement Protocols', appScored: true),
            ],
            const SizedBox(height: 6),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '“Mandatory · pass/fail” marks the legally required disclosures — the Required Basics, Species (the common or usual product name), and the Processor identifier. Those three score present-or-absent, with no partial credit.',
            style: TextStyle(fontSize: 13, color: _muted, height: 1.35),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Environmental impact and economic concentration / foreign ownership receive deeper analysis on the FAT website and are not scored in the app.',
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
          'Every result in the app uses the same three colors. The same color always means the same thing.',
          style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        _colorRow(
            color: _green,
            label: 'Green',
            detail:
                'Fully disclosed and independently verified by an accredited third-party certifier (USDA Organic, GAP, Certified Humane, AWA).'),
        const SizedBox(height: 10),
        _colorRow(
            color: _amber,
            label: 'Amber',
            detail:
                'Partially disclosed, or government-reviewed but not independently audited — including a USDA Process Verified Program (PVP).'),
        const SizedBox(height: 10),
        _colorRow(
            color: _red,
            label: 'Red',
            detail:
                'Not disclosed on this label. Recorded as a gap, not a violation.'),
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
        _bullet('Product quality, taste, or palatability'),
        const SizedBox(height: 8),
        _bullet('Nutritional value or health benefits'),
        const SizedBox(height: 8),
        _bullet('Price, value, or purchasing recommendation'),
        const SizedBox(height: 8),
        _bullet(
            'Environmental impact and economic concentration / foreign ownership — deeper analysis on the FAT website, not scored in the app'),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'A high FAT Score means the producer told you more and backed it up better. What you do with that information is your decision.',
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
          Text('Full reference, including category-by-category definitions, lives at:',
              style: TextStyle(fontSize: 13, color: _muted, height: 1.35)),
          SizedBox(height: 6),
          Text('farmanimaltransparency.com / how-fat-scores-labels',
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
