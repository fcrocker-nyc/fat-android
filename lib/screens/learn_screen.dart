import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';
import 'service_case_schema_screen.dart';

// ─── Content block model ─────────────────────────────────────────────────────
//
// A topic's detail body is a list of [_Block]s rendered in order. Plain-text
// topics are a single _Para per paragraph; custom topics use the richer blocks
// (headings, bullets, cards, tier rows, tables, etc.) to reproduce the iOS
// custom content views verbatim.

abstract class _Block {
  const _Block();
  Widget build();
}

/// A body paragraph (size 16, fixed wrapping).
class _Para extends _Block {
  final String text;
  final double size;
  final double opacity;
  final bool italic;
  const _Para(this.text, {this.size = 16, this.opacity = 1, this.italic = false});

  @override
  Widget build() => Text(
        text,
        style: TextStyle(
          fontSize: size,
          height: 1.45,
          color: Colors.black.withValues(alpha: opacity),
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      );
}

/// A bold heading (size 18, weight .black by default).
class _Head extends _Block {
  final String text;
  const _Head(this.text);

  @override
  Widget build() => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      );
}

/// A secondary label (size 14, bold, secondary color) — e.g. "Source".
class _Label extends _Block {
  final String text;
  const _Label(this.text);

  @override
  Widget build() => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: FATTheme.textSecondary,
        ),
      );
}

/// A horizontal divider (black 0.2).
class _Rule extends _Block {
  const _Rule();

  @override
  Widget build() => Container(
        height: 1,
        color: const Color(0x33000000),
        margin: const EdgeInsets.symmetric(vertical: 2),
      );
}

/// A bulleted list. Each entry renders "• text".
class _Bullets extends _Block {
  final List<String> items;
  final double size;
  const _Bullets(this.items, {this.size = 15});

  @override
  Widget build() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 15, height: 1.4)),
                    Expanded(
                      child: Text(t,
                          style: TextStyle(fontSize: size, height: 1.4)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
}

/// A white callout box (white 0.75) containing a heading + child blocks.
class _Box extends _Block {
  final String? heading;
  final double headingSize;
  final List<_Block> children;
  const _Box({this.heading, this.headingSize = 18, required this.children});

  @override
  Widget build() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heading != null) ...[
              Text(heading!,
                  style: TextStyle(
                      fontSize: headingSize, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
            ],
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i].build(),
            ],
          ],
        ),
      );
}

/// A credibility / seafood-credibility tier row: icon, title, description.
class _TierRow extends _Block {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _TierRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        ],
      );
}

/// A welfare-rating tier row: colored circle, title, programs, description.
class _WelfareRatingRow extends _Block {
  final Color color;
  final String title;
  final String programs;
  final String description;
  const _WelfareRatingRow({
    required this.color,
    required this.title,
    required this.programs,
    required this.description,
  });

  @override
  Widget build() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(programs,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: FATTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        ],
      );
}

/// A welfare certifier card: name, verdict capsule, detail box.
class _CertifierCard extends _Block {
  final String name;
  final String verdict;
  final String detail;
  const _CertifierCard({
    required this.name,
    required this.verdict,
    required this.detail,
  });

  @override
  Widget build() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: FATTheme.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(verdict,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FATTheme.primaryGreen.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(detail,
                style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
        ],
      );
}

/// An ownership table section: title, HHI label, company rows.
class _OwnershipTable extends _Block {
  final String title;
  final String hhi;
  final List<String> rows; // "🇨🇳 Company | Country | ~27%"
  const _OwnershipTable(
      {required this.title, required this.hhi, required this.rows});

  @override
  Widget build() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(hhi,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FATTheme.textSecondary)),
          const SizedBox(height: 8),
          ...rows.map((r) {
            final parts = r.split('|').map((e) => e.trim()).toList();
            final nameFlag = parts.isNotEmpty ? parts[0] : '';
            final origin = parts.length > 1 ? parts[1] : '';
            final share = parts.length > 2 ? parts[2] : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(nameFlag,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(origin,
                        style: const TextStyle(
                            fontSize: 13, color: FATTheme.textSecondary)),
                  ),
                  Text(share,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      );
}

/// A foreign-owner card: flag + name + country header, detail.
class _OwnerCard extends _Block {
  final String flag;
  final String owner;
  final String country;
  final String detail;
  const _OwnerCard({
    required this.flag,
    required this.owner,
    required this.country,
    required this.detail,
  });

  @override
  Widget build() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(owner,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(country,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FATTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(detail, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
        ),
      );
}

/// An HHI threshold row: range chip, label, color dot, description.
class _HhiThresholdRow extends _Block {
  final String range;
  final String label;
  final Color color;
  final String description;
  const _HhiThresholdRow({
    required this.range,
    required this.label,
    required this.color,
    required this.description,
  });

  @override
  Widget build() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(range,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        ],
      );
}

/// An HHI industry row: industry | score | status (with color).
class _HhiIndustryRow extends _Block {
  final String industry;
  final String score;
  final String status;
  final Color color;
  const _HhiIndustryRow({
    required this.industry,
    required this.score,
    required this.status,
    required this.color,
  });

  @override
  Widget build() => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(industry,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 2,
              child: Text(score,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              flex: 3,
              child: Text(status,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ],
        ),
      );
}

/// A brand row: "Brand — Parent / Origin" with distinct styling.
class _BrandRow extends _Block {
  final String brand;
  final String parent;
  const _BrandRow({required this.brand, required this.parent});

  @override
  Widget build() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ', style: TextStyle(fontSize: 15)),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, height: 1.35),
                  children: [
                    TextSpan(
                        text: '$brand — ',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: parent,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withValues(alpha: 0.75))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _LearnTopic {
  final String title;
  final String subtitle;
  final List<_Block> body;

  /// When set, tapping this topic opens a dedicated custom screen instead of
  /// the generic block-rendered [_LearnDetailScreen]. Used by the Service-Case
  /// Capture Schema topic to reach its verbatim iOS-ported explainer.
  final WidgetBuilder? screenBuilder;
  const _LearnTopic({
    required this.title,
    required this.subtitle,
    required this.body,
    this.screenBuilder,
  });
}

class _LearnSection {
  final String title;
  final List<_LearnTopic> topics;
  const _LearnSection({required this.title, required this.topics});
}

// Convenience: turn a multi-paragraph verbatim string into _Para blocks.
List<_Block> _text(String s) => s
    .split('\n\n')
    .where((p) => p.trim().isNotEmpty)
    .map<_Block>((p) => _Para(p))
    .toList();

// ─── Sections & Topics ───────────────────────────────────────────────────────

final List<_LearnSection> _sections = <_LearnSection>[
  // ════════════ SECTION 1 ════════════
  _LearnSection(
    title: 'How FAT Reads a Label',
    topics: [
      // 1.1
      _LearnTopic(
        title: 'The Three Steps of a FAT Read',
        subtitle: 'Disclosure → Credibility → Entity Facts',
        body: _text(
            'A FAT read is built in three steps. Each step asks a different question.\n\n'
            'Step 1 — What was disclosed?\n'
            'We read the label and check which transparency categories are present. For meat, there are 16 categories (species, breed, country of origin, farm/ranch, processor, feed, animal welfare, pasture/outdoor access, regenerative/land use, quality, dietary attributes, medicine, age at slaughter, USDA/FSIS required language, the establishment number, and supply-chain intermediaries). For seafood, there is a partly overlapping set of 16 categories with seafood-specific additions. Each category gets one of three states: Disclosed (green), Partially disclosed (amber), or Not disclosed (red).\n\n'
            'Step 2 — How credible is what was disclosed?\n'
            'Disclosure alone isn\'t proof. A claim can be Third-Party Audited (independently audited on-farm by an organization that is neither the producer nor the regulator), USDA-Reviewed (USDA-administered program with audit teeth — Process Verified, USDA grade marks, FSIS catfish inspection), Producer Affidavit (FSIS approved the label language but only a producer affidavit backs it — no on-farm audit), or Unverified Marketing (the words are on the package with no audit and no government label-language approval). The same disclosure can carry very different weight depending on which of those four credibility tiers applies.\n\n'
            'Step 3 — Who is behind this product, and what does the public record say?\n'
            'The label is one source of information. The processor\'s enforcement history, the parent company\'s ownership and concentration in the category, foreign ownership status, recall history, humane-handling violations, pathogen testing results, and HHI for the relevant supply chain are all relevant facts that don\'t appear on the label but do affect what the consumer is actually buying. FAT surfaces these facts when they are available in public records.\n\n'
            'FAT reports how many of the 16 categories a label discloses (Step 1) and how credible those disclosures are (Step 2). Step 3 sits alongside as public-record context — not part of the count. It is a count of what the label tells you, not a grade of the food. Step 3 can flag a product even when its label discloses a lot: a well-disclosed label whose processor has a recent recall, or whose parent corporation holds an HHI-flagged share of the market, is a different consumer story than the same label without that history.'),
      ),
      // 1.2 — custom("scoring") → FATScoringExplanationView (not detailed in spec)
      _LearnTopic(
        title: 'Step 1 — What Is Disclosed',
        subtitle:
            'The 16 categories and the three lights · meat & poultry deep-dive',
        body: [
          const _Para(
              'Step 1 of a FAT read asks a single question: what did the label actually disclose? FAT reads a meat or poultry label against 16 transparency categories and assigns each a status light.'),
          const _Head('The 16 meat & poultry categories'),
          const _Bullets([
            'Species',
            'Breed / genetics',
            'Country of origin',
            'Farm / ranch',
            'Processor (establishment number)',
            'Feed',
            'Animal welfare',
            'Pasture / outdoor access',
            'Regenerative / land use',
            'Quality',
            'Dietary attributes',
            'Medicine / antibiotics',
            'Age at slaughter',
            'USDA / FSIS required language',
            'Establishment number',
            'Supply-chain intermediaries',
          ]),
          const _Head('The three lights'),
          const _Bullets([
            'Disclosed (green) — the category is clearly and specifically addressed on the label.',
            'Partially disclosed (amber) — the label touches the category but leaves it incomplete or ambiguous.',
            'Not disclosed (red) — the label says nothing about the category.',
          ]),
          const _Head('From lights to the disclosure read'),
          const _Para(
              'The mix of green, amber, and red lights across the 16 categories is the disclosure read — how many of the 16 the label discloses, and how specifically. Combined with the Step 2 credibility of those claims, it tells you how open the brand chose to be. A label that discloses many categories but backs them only with marketing language is a weaker story than a sparser label whose few disclosures are all third-party audited. FAT reports the count and the backing — it does not grade the food.'),
        ],
      ),
      // 1.3 — custom("credibility")
      _LearnTopic(
        title: 'Step 2 — How Credible Is the Disclosure',
        subtitle:
            'Third-Party Audited · USDA-Reviewed · Producer Affidavit · Unverified Marketing',
        body: [
          const _Para(
              'Step 2 of a FAT read asks how credible the disclosed claim is. Disclosure (Step 1) tells you whether the label addressed a topic at all. Credibility tells you how much weight that claim carries.'),
          const _Para(
              'FAT places every disclosed claim into one of four credibility tiers, mirroring the canonical model at farmanimaltransparency.com/learn-how-to-read-meat-labels/. Higher tiers carry more score weight.'),
          const _Rule(),
          const _TierRow(
            icon: Icons.verified_user,
            color: FATTheme.successGreen,
            title: 'Third-Party Audited',
            description:
                'Independent on-farm audit by an organization that is neither the producer nor the regulator. Examples: USDA Organic (NOP-accredited annual audit), A Greener World (AGW), Certified Humane, Global Animal Partnership, American Grassfed Association, Regenerative Organic Certified. For seafood: MSC, ASC, BAP. Highest score weight.',
          ),
          const _TierRow(
            icon: Icons.verified,
            color: FATTheme.usdaApprovedBlue,
            title: 'USDA-Reviewed',
            description:
                'USDA-administered program with audit teeth — broader than just label-language approval. Examples: USDA AMS Process-Verified Program (PVP, the producer\'s own standard audited by USDA), USDA quality-grade shields (Prime, Choice, Select) determined by USDA graders, and FSIS catfish (and other Siluriformes) inspection. Strong score weight.',
          ),
          const _TierRow(
            icon: Icons.description_outlined,
            color: FATTheme.fatOrange,
            title: 'Producer Affidavit',
            description:
                'FSIS reviewed and approved the wording on the label, backed by the producer\'s affidavit and internal records — no independent on-farm audit. Examples: "Grass Fed" or "No Antibiotics Ever" without a third-party cert mark, "No Hormones Administered" (beef), "Raised using Regenerative Agriculture Practices." Government oversight exists at the label-approval stage only. Moderate score weight.',
          ),
          const _TierRow(
            icon: Icons.info_outline,
            color: FATTheme.fatRed,
            title: 'Unverified Marketing',
            description:
                'Printed on the label with no third-party audit and no government label-language approval. The claim may still be true, but the consumer has no external confirmation. Examples: "Family Farm," "Humanely Raised" (without a certification logo), "All Natural," "Farm Fresh," "Sustainably Sourced." Lowest score weight.',
          ),
          const _Rule(),
          const _Head('What FAT Does Not Do'),
          const _Para(
              'FAT does not rate products, endorse brands, or certify claims. It reports what the label says and how that claim is supported. A label with all "Unverified Marketing" badges is not necessarily worse than one with all "Third-Party Audited" badges — it simply means the consumer has less external evidence to rely on.'),
        ],
      ),
      // 1.4
      _LearnTopic(
        title: 'Step 3 — Who Stands Behind the Label',
        subtitle:
            'Processor enforcement · brand owner · parent company · foreign ownership · HHI',
        body: _text(
            'The label is one source of information. The entities behind the label are another. Step 3 surfaces what the public record says about them — a separate panel on the results screen, not part of the disclosure count. Step 3 can flag a product even when its label discloses a lot.\n\n'
            'Processor & enforcement record\n'
            'The processor is identified on the label by establishment number (FSIS for meat, poultry, and catfish; FDA for other seafood). FAT pulls the processor\'s public enforcement record from the relevant regulator\'s files: recalls, humane-handling violations, quarterly enforcement actions, Salmonella performance categories, beef pathogen sampling results, chemical-residue findings, and FDA import alerts. A clean record looks different from a record with multiple recent recalls — same brand on the package either way.\n\n'
            'Brand owner & corporate parent\n'
            'Many shelf brands are subsidiary product lines of much larger corporations. Eckrich and Nathan\'s Famous are Smithfield brands. Hillshire Farm and Jimmy Dean are Tyson brands. The brand on the package is what the consumer sees first; the parent corporation is what governs procurement, contract terms, and corporate policy. FAT discloses both.\n\n'
            'Beneficial & foreign ownership\n'
            'WH Group (China) owns Smithfield. JBS and Marfrig (Brazil) own significant U.S. beef capacity. Several leading U.S. seafood brands are foreign-owned. FAT flags foreign ownership when present — neutrally, as a fact, not a verdict.\n\n'
            'Economic concentration & HHI\n'
            'Market concentration in the relevant supply chain is measured by the Herfindahl-Hirschman Index. Highly concentrated supply chains affect price formation, contract terms, and producer leverage even when the label says nothing about them. FAT also surfaces any DOJ or FTC antitrust history involving the parent company.\n\n'
            'Why Step 3 sits alongside the score, not inside it\n'
            'Steps 1 and 2 score the label itself — what it says and how well it\'s backed. Step 3 tells you who\'s making the claim and what their record is. A high A on the label can still come with a problematic Step 3 panel, and a low D can still come from a small, clean operation with a perfect record. Treating these as separate signals is more useful than averaging them into a single number.'),
      ),
    ],
  ),

  // ════════════ SECTION 2 ════════════
  _LearnSection(
    title: 'Meat & Poultry: Categories, Enforcement, Ownership',
    topics: [
      // 2.1 — custom("welfare")
      _LearnTopic(
        title: 'Animal Welfare Certification Ratings',
        subtitle: 'What the color-coded ratings mean',
        body: [
          const _Head('The Six Major Third-Party Animal Welfare Certifiers'),
          const _Para(
              'Six organizations dominate third-party animal welfare certification in the United States. Their standards vary enormously — from the most rigorous welfare requirements available to programs that are little better than standard industry practice.'),
          const _CertifierCard(
            name: '1. A Greener World (AGW) — Animal Welfare Approved',
            verdict: 'Strongest standards available',
            detail:
                'Requires continuous outdoor access on pasture or range. No cages, crates, or tethers. Limited exclusively to independent family farms. Prohibits growth hormones and subtherapeutic antibiotics. Physical alterations (beak trimming, tail docking) prohibited or strictly limited. Slaughter facilities audited. Covers the animal\'s entire life from birth through slaughter, including transport. ISO/IEC Guide 17065 accredited. The ASPCA\'s Shop With Your Heart program gives AWA its highest recommendation.',
          ),
          const _CertifierCard(
            name: '2. Certified Humane (HFAC)',
            verdict: 'Strong — but tier matters',
            detail:
                'Three tiers: Base (no cages/crates, enrichments required, but no outdoor access for most species), Free Range (meaningful outdoor access), and Pasture Raised (108 sq ft outdoor space per bird, minimum 6 hours daily). No growth hormones. Antibiotics only for illness. One of only two major certifiers that audit slaughter facilities. Recommended by the ASPCA\'s Shop With Your Heart program. Key gap: consumers who see "Certified Humane" without a tier modifier should not assume the birds ever went outside.',
          ),
          const _CertifierCard(
            name: '3. Global Animal Partnership (GAP)',
            verdict: 'Tiered — Step 1 dominates retail',
            detail:
                'Five-step program used at Whole Foods. Steps 1–2 require no outdoor access and offer only marginal improvement over industry practice — the ASPCA\'s Shop With Your Heart program excludes Step 1 from its recommendations. Steps 3–4 add outdoor and pasture access. Step 5/5+ approaches AWA-level welfare but is virtually unavailable at retail. GAP requires use of audited slaughter facilities but does not conduct its own slaughter audits. Farm Forward resigned from GAP\'s board in 2020, citing concerns that GAP had become "increasingly a marketing scheme functioning to benefit massive corporations." Most products at Whole Foods carry Step 1 or Step 2.',
          ),
          const _CertifierCard(
            name: '4. USDA Certified Organic',
            verdict: 'Improving — new rules by 2029',
            detail:
                'Historically had vague welfare standards that large producers exploited. The 2023 Organic Livestock and Poultry Standards (OLPS) rule adds specific stocking densities, prohibits gestation crates, requires enrichment, and closes the "porch as outdoor space" loophole — but full compliance is not required until 2029. The ASPCA\'s Shop With Your Heart program recommends seeking additional welfare certifications even when buying organic.',
          ),
          const _CertifierCard(
            name: '5. American Humane Certified (AHC)',
            verdict: 'Widely considered weakest major certifier',
            detail:
                'Certifies over 1 billion animals on 8,000+ farms, including Butterball, Foster Farms, and Eggland\'s Best. No outdoor access required for any species. Enrichments "encouraged" but not required. Broiler space requirements only slightly exceed industry standards. Farrowing crates permitted for pigs. Farms can pass at 85% of criteria — consumers do not know which 15% were unmet. The ASPCA\'s Shop With Your Heart program does not recommend AHC. AHC relies on certification fees from its largest customers, creating a structural disincentive to raise standards.',
          ),
          const _CertifierCard(
            name: '6. One Health Certified (OHC)',
            verdict: 'Industry-created — widely criticized',
            detail:
                'Created by Mountaire Farms, the sixth-largest U.S. poultry producer. Not affiliated with the One Health Commission despite the similar name. Standards largely reflect existing industrial practices. No slaughter auditing required. Farm Forward characterizes it as humanewashing.',
          ),
          const _Para(
              'Also notable: the American Grassfed Association certifies ruminants only (beef, sheep, goats, bison) for 100% grass/forage diet with continuous pasture access and no feedlot confinement. Its welfare scope is narrower than AWA or Certified Humane, but it is a credible standard for the specific claims it makes.',
              size: 15),
          const _Rule(),
          const _Head('How FAT Rates These Programs'),
          const _Para(
              'When FAT detects a welfare certification on a label, it evaluates the program against specific criteria: Does it require outdoor access? Are cages prohibited? Is slaughter audited? Is the certifier independent of the meat industry? Based on these criteria, FAT assigns one of six tiers:'),
          const _WelfareRatingRow(
            color: FATTheme.tierHighest,
            title: 'Highest Welfare',
            programs: 'Animal Welfare Approved (AGW), GAP Step 5/5+',
            description:
                'The strongest standards available. Independently verified, pasture-based, typically limited to family farms. Covers the animal\'s entire life including transport and slaughter.',
          ),
          const _WelfareRatingRow(
            color: FATTheme.tierHigh,
            title: 'High Welfare',
            programs: 'Certified Humane Pasture Raised, GAP Step 4',
            description:
                'Meaningful pasture access with strong oversight. Animals spend significant time outdoors on real vegetation.',
          ),
          const _WelfareRatingRow(
            color: FATTheme.tierMeaningful,
            title: 'Meaningful',
            programs:
                'Certified Humane Free Range, GAP Step 3, USDA Organic, American Grassfed',
            description:
                'Real improvements over industry practice, including outdoor access requirements. Some limitations remain, but these programs deliver on core consumer expectations.',
          ),
          const _WelfareRatingRow(
            color: FATTheme.tierModerate,
            title: 'Moderate',
            programs: 'Certified Humane (base), GAP Step 2',
            description:
                'Prohibits cages and crates, which is a genuine improvement. However, outdoor access is not required. Animals may be raised entirely indoors.',
          ),
          const _WelfareRatingRow(
            color: FATTheme.tierMarginal,
            title: 'Marginal',
            programs:
                'American Humane Certified, GAP Step 1, One Health Certified',
            description:
                'Conditions only marginally better than standard industry practice. Space requirements barely exceed industry norms. The ASPCA\'s Shop With Your Heart program does not recommend these programs.',
          ),
          const _WelfareRatingRow(
            color: FATTheme.tierMisleading,
            title: 'Potentially Misleading',
            programs:
                '"Natural," "Humanely Raised" (no cert), "Cage-Free," "Free-Range" (no cert)',
            description:
                'Marketing language with no independent verification. These terms are either undefined by USDA, defined but not verified, or technically true of all products in the category.',
          ),
          const _Rule(),
          const _Head('Key Takeaways for Consumers'),
          const _Bullets([
            'Only two certifiers — AWA and Certified Humane — audit slaughter facilities.',
            'In tiered programs (GAP, Certified Humane), the tier available at retail is almost always the lowest one. Most GAP products at Whole Foods are Step 1 or 2, which do not require outdoor access.',
            '"Certified Humane" without a tier modifier (Free Range or Pasture Raised) does not guarantee the animal went outside.',
            'American Humane Certified covers the most animals but has the weakest standards among major certifiers.',
            'Labels that say "humanely raised" or "cage-free" without an accompanying certification seal have no independent verification behind them.',
          ]),
          const _Rule(),
          const _Head('How to Read the Welfare Claims Section'),
          const _Para(
              'After scanning a label, FAT shows a "Welfare Claims Detected" section with each certification or marketing claim found on the package. Tap any card to expand it and see:'),
          const _Bullets([
            'What the certification actually requires (outdoor access, cage prohibitions, antibiotic restrictions, slaughter auditing)',
            'Whether the ASPCA\'s Shop With Your Heart program recommends the certification',
            'Key facts about the specific tier or program',
            'What consumers should know — honest context that the label itself does not provide',
          ]),
          const _Rule(),
          const _Head('Why This Matters'),
          const _Para(
              'Consumers consistently report that animal welfare influences their purchasing decisions, but research shows most people cannot distinguish between certifications. A 2024 ASPCA survey found that over 80% of consumers expect "humanely raised" products to come from farms with outdoor access — yet several certified programs do not require it.'),
          const _Para(
              'FAT bridges this gap by showing you what each certification actually delivers, not just what the label implies.'),
          const _Rule(),
          const _Label('Source'),
          const _Para(
              'Welfare certification ratings are based on FAT Research Paper No. 7: Third-Party Animal Welfare Certification Programs — A Comparative Analysis. Full methodology and detailed comparison available at farmanimaltransparency.com.',
              size: 14,
              opacity: 0.6),
        ],
      ),
      // 2.2
      _LearnTopic(
        title: 'Grass-Fed and Grass-Finished Claims',
        subtitle: 'What FSIS actually requires — and what it doesn\'t',
        body: _text(
            '"Grass-fed" and "grass-finished" sound similar, but under FSIS rules they mean very different things — and the difference is the opposite of what most consumers expect.\n\n'
            'Grass-Fed (the stronger claim):\n'
            'Under current FSIS guidance, "grass-fed" requires that cattle were fed 100% forage after weaning. No grain or grain by-products are permitted. Animals must have continuous access to pasture during the growing season and cannot be confined to a feedlot. FSIS treats "Grassfed," "Grass Fed," and "Grass-Fed" as synonymous.\n\n'
            'Grass-Finished (the weaker claim):\n'
            '"Grass-finished" permits grain feeding earlier in the animal\'s life. Only the final finishing phase must be on grass or forage. A label stating "Grain Fed, Grass Finished" is considered truthful and compliant by FSIS.\n\n'
            'Partial Claims:\n'
            'FSIS also permits partial grass-fed claims such as "75% grass-fed" or "90% grass-fed" as long as the percentage is disclosed on the label. These products appear alongside 100% grass-fed products on store shelves with no standardized visual distinction.\n\n'
            'How enforcement works:\n'
            'FSIS approves grass-fed labels based on a producer affidavit — a written statement that the feeding practices meet the standard. Most operations are never independently audited. Without a third-party certification, there is no on-farm verification.\n\n'
            'Third-party certifications:\n'
            'Two independent programs audit grass-fed claims on farms:\n\n'
            '• American Grassfed Association (AGA) — Requires 100% forage diet, no feedlot confinement, no antibiotics or hormones, born and raised in the USA. Independent inspection every 15 months.\n\n'
            '• Certified Grassfed by A Greener World (AGW) — Requires 100% forage diet with birth-to-slaughter traceability. Can only be awarded to farms that also hold Animal Welfare Approved certification.\n\n'
            'A third option, USDA Process Verified, is not a standard — the producer defines their own grass-fed protocol and USDA audits compliance with that self-defined standard. Two Process Verified operations may have materially different practices.\n\n'
            'How FAT interprets grass-fed claims:\n'
            'When FAT detects a grass-fed or grass-finished claim on a scanned label, it assesses the credibility of that claim:\n\n'
            '• Claims backed by AGA or AGW certification are flagged as third-party audited\n'
            '• Claims with USDA Process Verified are flagged as producer-defined standards\n'
            '• Claims with no certification are flagged as affidavit only — no independent audit\n'
            '• "Grass-finished" claims trigger a warning explaining that this is the weaker claim under FSIS rules\n'
            '• Partial claims display the disclosed percentage\n\n'
            'Source: FAT Research Paper No. 6 — Grass-Fed vs. Grass-Finished: What FSIS Actually Recognizes, and What Consumers Don\'t Know. Full paper available at farmanimaltransparency.org.'),
      ),
      // 2.3
      _LearnTopic(
        title: 'Antibiotics and Meat Labels',
        subtitle: 'What antibiotic claims do and don\'t mean',
        body: _text(
            'Antibiotics are legally permitted in most U.S. livestock production.\n\n'
            'In 2024, antibiotic use increased in several livestock sectors due to disease pressure, supply chain disruptions, and biosecurity challenges.\n\n'
            'What labels usually say:\n'
            'Some labels include claims such as "no antibiotics ever" or "raised without antibiotics." Other labels include no antibiotic information at all. In poultry, "no hormones" language reflects federal rules and does not address antibiotic use.\n\n'
            'How FAT interprets antibiotics:\n'
            'FAT reports only what is disclosed on the label. If antibiotic practices are not disclosed, FAT treats that as missing information — not evidence of use or non-use.'),
      ),
      // 2.4
      _LearnTopic(
        title: 'Species, Breed, and Genetics',
        subtitle: 'Why breed is rarely disclosed',
        body: _text(
            'Most meat labels identify the species (such as beef, pork, or chicken).\n\n'
            'Far fewer disclose breed or genetic information. Breed claims may be meaningful, but many labels provide no breed information at all.\n\n'
            'FAT reports breed only when it is explicitly disclosed on the label.'),
      ),
      // 2.5
      _LearnTopic(
        title: 'Chicken Age at Slaughter: What the Label Actually Tells You',
        subtitle: 'USDA poultry class names, 9 CFR 381.170, and the 47-day reality',
        body: _text(
            'The class name on a chicken label — Broiler, Fryer, Roaster, Cornish Game Hen — is the only age-linked fact on most packages that is backed by a federal standard of identity. But it sets a ceiling, not a floor.\n\n'
            'USDA 9 CFR 381.170 defines each class:\n\n'
            '• Cornish Game Hen — less than 5 weeks old, or less than 2 lb ready-to-cook weight\n'
            '• Broiler or Fryer — less than 10 weeks old\n'
            '• Roaster — less than 12 weeks old (weight standard removed, 2016)\n'
            '• Capon — less than 4 months old; surgically unsexed male\n'
            '• Stewing Hen, Fowl, or Baking Hen — 10 months or older (a spent laying hen)\n\n'
            'The ceiling is real federal law. The actual slaughter age is not disclosed.\n\n'
            'In practice, the gap matters a lot. The National Chicken Council\'s annual Broiler Performance Report shows that average commercial slaughter age has fallen from 112 days in 1925 to 47.4 days in 2024. A label saying "Broiler" legally means "under 70 days" — the typical bird is closer to 47. The compression is driven by selective breeding for growth rate, not feed or management alone: a 2014 University of Alberta study (Zuidhof et al., Poultry Science 93:12) found that the modern broiler strain grows to market weight more than 400% faster than the 1957 strain raised under identical conditions.\n\n'
            'The Stewing Hen class is a different supply chain entirely. These birds are not raised for meat — they are egg-production hens removed from laying flocks when output declines, typically at 12 to 18 months.\n\n'
            'How FAT reads it:\n'
            'FAT scores a class-name disclosure as Known under the USDA-Reviewed credibility tier. The term is a standard of identity enforced by FSIS — the ceiling is legally binding. But the result card states explicitly that the class name is a ceiling, not the actual age, and displays the NCC 47-day industry benchmark. A label bearing only "chicken breast" or "chicken thighs" with no class term scores Missing on Category 6.\n\n'
            'Source: 9 CFR 381.170; 76 FR 68064 (final rule, eff. Jan 1, 2014); 81 FR 21709 (2016 amendment); NCC 2024 Broiler Performance Report; Zuidhof et al. 2014, Poultry Science 93(12):2970–2982.'),
      ),
      // 2.6 (was 2.5)
      _LearnTopic(
        title: 'Country of Origin Claims',
        subtitle: 'Born, raised, and processed distinctions',
        body: _text(
            'Some labels state where animals were born, raised, or harvested. Others use general phrases such as "Product of the U.S." or provide no origin information.\n\n'
            'FAT reports origin claims as disclosed only when the label provides specific, reliable information.'),
      ),
      // 2.6
      _LearnTopic(
        title: 'Supply-Chain Intermediaries',
        subtitle:
            'The custodians between the farm and the slaughter plant — and who owns them',
        body: _text(
            'Most of an animal\'s life happens between the farm where it was born (Category 5) and the plant where it was slaughtered (Category 7). The operations in that gap — backgrounders, stockers, contract grow-out farms, and finishing feedlots — rarely appear on a retail label, yet they determine how the animal was fed, housed, and handled for most of its life. Category 16 makes that middle of the supply chain visible.\n\n'
            'What FAT looks for:\n'
            '• Whether any intermediate custodian is named or referenced on the label — a feedlot, backgrounder, stocker operation, or contract grower\n'
            '• The captivity status of each operation: packer-owned, packer-contracted (captive supply), independent, or undisclosed\n'
            '• Whether the relationship between the brand and those intermediaries is stated at all\n\n'
            'Why captivity status matters:\n'
            '"Captive supply" describes livestock a packer owns or controls through contracts before slaughter. High captive-supply concentration affects price formation, producer leverage, and how much of the chain a single corporation controls — facts that shape what a label really represents even when the package says nothing about them.\n\n'
            'How FAT scores it:\n'
            'Intermediaries are almost never disclosed on retail packaging, so Missing is the expected outcome — a gap, not an accusation. When an intermediary is named but its ownership relationship is not stated, FAT records the disclosure as Partial. Deeper analysis — including the Captive Feedlot Map and Captivity Tiers Map — lives on the FAT website.\n\n'
            'Source: farmanimaltransparency.com/understanding-16-fat-categories/.'),
      ),
      // 2.7
      _LearnTopic(
        title: 'Animal Welfare and Husbandry Claims',
        subtitle:
            'What welfare and husbandry claims actually mean on labels',
        body: _text(
            '"Animal welfare" and "animal husbandry" describe how animals are housed, handled, fed, and slaughtered. The two terms are often used interchangeably on labels, but neither has a single federal definition that applies across species.\n\n'
            'What labels usually say:\n'
            'Common claims include "humanely raised," "humanely handled," "responsibly raised," "animal-welfare certified," "pasture-raised," "free-range," and "cage-free." Some terms have USDA-reviewed definitions; most do not. Claims vary widely in what they actually require on the farm.\n\n'
            'How FSIS handles welfare claims:\n'
            'The Humane Methods of Slaughter Act (HMSA) covers livestock slaughter but does not cover poultry. FSIS inspects humane handling at slaughter and publishes enforcement actions when violations occur — this is the only on-site federal welfare oversight. On-farm practices (space, outdoor access, handling, most of the animal\'s life) are outside FSIS\'s direct reach. FSIS typically approves welfare-related label language on the basis of a producer affidavit rather than an independent on-farm audit.\n\n'
            'Third-party welfare certifications:\n'
            'A small number of independent programs audit on-farm welfare. They differ materially in what they require:\n\n'
            '• Animal Welfare Approved (A Greener World) — among the most rigorous; pasture-based requirements, independent annual audits, birth-to-slaughter traceability\n\n'
            '• Certified Humane (Humane Farm Animal Care) — tiered standards; some programs require pasture access, others permit confinement-based systems\n\n'
            '• Global Animal Partnership (GAP) — 5-step program used by some major retailers; higher steps require outdoor access and pasture\n\n'
            '• American Humane Certified — the most widely used program and generally less stringent than those above\n\n'
            'A label that says "humane" or "welfare" with no certifier logo has not been independently audited.\n\n'
            'How FAT interprets welfare and husbandry claims:\n'
            '• Claims backed by independent welfare certification are treated as third-party verified\n'
            '• "Humanely raised" or "animal welfare" language without certification is flagged as label claim only\n'
            '• FSIS humane-handling enforcement data for the processing establishment is shown when available\n'
            '• "Cage-free," "free-range," and "pasture-raised" are scored separately based on the specific term used and whether a certifier is identified\n'
            '• Missing welfare disclosure is flagged as missing information — not evidence of poor welfare or good welfare\n\n'
            'Source: FAT Animal Welfare Research Series. Full papers available at farmanimaltransparency.com/fat-research/#fat-topic-animal-welfare-research-series.'),
      ),
      // 2.8
      _LearnTopic(
        title: 'USDA Establishment Numbers',
        subtitle: 'What EST. numbers identify',
        body: _text(
            'Some meat and poultry labels include a USDA establishment number, often shown as "EST. ####."\n\n'
            'This number identifies the federally inspected facility where the product was processed.\n\n'
            'An establishment number indicates federal inspection status only. It does not imply food safety, quality, or regulatory performance.'),
      ),
      // 2.9
      _LearnTopic(
        title: 'Looking Up Establishments Directly',
        subtitle: 'Using the Lookup tab without scanning',
        body: _text(
            'You can look up any USDA establishment number without scanning a label.\n\n'
            'The Lookup tab lets you enter an establishment number manually to view:\n'
            '• Processor name, location, and contact information\n'
            '• Processing activities and HACCP size category\n'
            '• Complete enforcement history (recalls, violations, actions)\n'
            '• Pathogen testing results\n'
            '• Links to full processor profiles on the FAT website\n\n'
            'This is useful when:\n'
            '• You have an establishment number but not the physical label\n'
            '• You\'re researching processors before shopping\n'
            '• You want to compare different establishments\n'
            '• A label is difficult to scan due to lighting or damage\n\n'
            'All the same transparency data is available whether you scan or lookup manually.'),
      ),
      // 2.10
      _LearnTopic(
        title: 'Understanding FSIS Enforcement Data',
        subtitle: 'Recalls, violations, and what they mean',
        body: _text(
            'When you scan a label, FAT may show enforcement and safety information about the processing establishment. This data comes from USDA\'s Food Safety and Inspection Service (FSIS) public records.\n\n'
            'What the data shows:\n'
            '• Recalls — Product recalls due to contamination, mislabeling, or safety concerns\n'
            '• Administrative Actions — Enforcement actions like warnings or compliance issues\n'
            '• Humane Handling Violations — Actions taken for violations of humane slaughter requirements\n'
            '• Quarterly Enforcement Actions — NOIEs, suspensions, and regulatory actions\n'
            '• Chemical Residue Violations — Illegal drug residues detected in animals at slaughter\n'
            '• Salmonella Performance — Critical pathogen testing results for poultry\n'
            '• Beef Pathogen Testing — E. coli and Salmonella sampling for beef\n\n'
            'What this means:\n'
            'Enforcement data reflects regulatory compliance history, not current product safety. An establishment with enforcement actions on record may have fully resolved those issues. Conversely, the absence of enforcement data does not guarantee perfect performance — it simply means no public enforcement actions were taken during the reporting period.\n\n'
            'FAT presents this information for transparency. You decide how it factors into your purchasing decisions.'),
      ),
      _LearnTopic(
        title: 'OSHA Worker-Safety Enforcement',
        subtitle: 'The plant\'s record for the people who work there',
        body: _text(
            'Meat and poultry plants are among the most dangerous workplaces in U.S. manufacturing — injury and illness rates run well above the manufacturing average, driven by fast line speeds, sharp equipment, cold and wet conditions, and repetitive motion.\n\n'
            'The Occupational Safety and Health Administration (OSHA), part of the U.S. Department of Labor, inspects these plants and issues citations when it finds hazards. Common ones in slaughter and processing include lockout/tagout (hazardous-energy) failures, unguarded machinery, and process-safety violations on the anhydrous-ammonia refrigeration systems these plants rely on.\n\n'
            'What FAT shows for a plant\'s OSHA record:\n'
            '• Inspections — how many times OSHA has been on site\n'
            '• Citations classified Serious, Willful, Repeat, or Other-than-serious\n'
            '• Initial and current penalties (these often differ after employer contests and settlements)\n'
            '• Any fatality or severe-injury event on record\n\n'
            'A separate axis from food safety:\n'
            'Worker safety is kept deliberately distinct from the food-safety record above (recalls, residue, humane handling) and is never blended into one number. An OSHA citation says nothing about whether the meat is safe to eat, and a food-safety recall says nothing about how the plant treats its workers — they are two different questions.\n\n'
            'How the match works:\n'
            'OSHA records carry no FSIS establishment number, so FAT matches them to the plant by name and address. A name-and-address (or ZIP) confirmed match is shown as the plant\'s record; a name-only match is labeled a "possible" match, not confirmed. Worker injury or illness reports are not violations unless OSHA issued a citation, and figures can change after employer contests or settlements.\n\n'
            'Source: OSHA Enforcement data, U.S. Department of Labor.'),
      ),
      _LearnTopic(
        title: 'EPA Environmental Enforcement',
        subtitle: 'The plant\'s water- and air-pollution record',
        body: _text(
            'Slaughter and processing plants use enormous volumes of water and generate heavily loaded wastewater — blood, fats, nitrogen, and phosphorus — plus air emissions from rendering, boilers, and the ammonia refrigeration systems that keep product cold. Federal law regulates those discharges.\n\n'
            'The Environmental Protection Agency (EPA), with state agencies, oversees the plant under the Clean Water Act (wastewater-discharge permits — the NPDES program, 40 CFR 432 for meat and poultry) and the Clean Air Act. A plant that exceeds its permit limits, fails to monitor or report, or otherwise breaks the rules can be placed in noncompliance and penalized.\n\n'
            'What FAT shows for a plant\'s EPA record (from EPA\'s ECHO database):\n'
            '• Whether the facility is a Significant Non-Complier\n'
            '• How many of the last twelve quarters it spent in noncompliance — Clean Water Act (wastewater) violations are the most common issue at these plants\n'
            '• Whether formal enforcement actions or penalties are on record\n\n'
            'How it affects the score:\n'
            'An EPA record of current noncompliance or penalties applies a penalty to the Processor category — the same category that carries the plant\'s OSHA worker-safety record. Environmental enforcement is kept separate from food safety: a wastewater violation says nothing about whether the meat is safe to eat.\n\n'
            'How the match works:\n'
            'FAT matches EPA facilities to the plant by name, city, and ZIP, and applies the penalty only on a high-confidence match with violations on record. Compliance status changes slowly and is refreshed periodically.\n\n'
            'Source: EPA Enforcement and Compliance History Online (ECHO), U.S. Environmental Protection Agency.'),
      ),
      // 2.11
      _LearnTopic(
        title: 'Product Recalls',
        subtitle: 'Class I, II, and III severity levels',
        body: _text(
            'FSIS issues recalls when meat or poultry products pose a health risk or violate federal regulations. Recalls are classified by severity:\n\n'
            '• Class I — Serious health hazard (e.g., deadly pathogens like E. coli O157:H7, Listeria)\n'
            '• Class II — May cause temporary health problems (e.g., undeclared allergens, foreign material)\n'
            '• Class III — Unlikely to cause health problems (e.g., minor labeling issues)\n\n'
            'FAT shows recall history for each establishment, including the recall class, reason, and current status (open or closed). This helps you understand an establishment\'s track record, but remember: recalls often reflect responsible action when problems are discovered, not necessarily ongoing issues.'),
      ),
      // 2.12 — custom("humane_handling")
      _LearnTopic(
        title: 'Humane Handling Enforcement',
        subtitle: 'FSIS humane slaughter compliance actions',
        body: [
          const _Para(
              'The Humane Methods of Slaughter Act (HMSA) requires that livestock be rendered insensible to pain before slaughter. FSIS enforces this requirement through in-plant inspection and takes enforcement action when violations are identified.'),
          const _Rule(),
          _Box(
            heading: 'What FSIS Enforces',
            children: [
              const _Para(
                  'FSIS inspectors are present during slaughter operations and monitor compliance with humane handling requirements. The key areas of enforcement include:',
                  size: 15),
              const _Bullets([
                'Stunning effectiveness — Animals must be rendered unconscious with a single application of the stunning device before shackling, hoisting, or cutting',
                'Handling during movement — Animals must not be dragged, beaten, or subjected to excessive force while being moved through the facility',
                'Holding pen conditions — Animals in holding pens must have access to water and must not be held in conditions that cause injury or distress',
                'Non-ambulatory (downer) animals — Animals that cannot walk must be handled according to specific FSIS requirements; in cattle, non-ambulatory animals are condemned and may not enter the food supply',
              ]),
            ],
          ),
          _Box(
            heading: 'Types of Enforcement Actions',
            children: [
              const _Para(
                  'When FSIS identifies a humane handling violation, it can take several types of action:',
                  size: 15),
              const _Bullets([
                'Regulatory Control Action (RCA) — Immediate suspension of slaughter operations. This is the most severe on-the-spot response and is used when an inspector witnesses an egregious violation or imminent animal suffering.',
                'Noncompliance Record (NR) — A documented finding that the establishment failed to meet humane handling requirements. NRs accumulate in the establishment\'s compliance record.',
                'Notice of Intended Enforcement (NOIE) — A formal notice that FSIS may suspend or withdraw inspection, effectively shutting the plant down. NOIEs related to humane handling are among the most serious enforcement signals.',
                'Suspension — Temporary withdrawal of FSIS inspection, halting all operations until corrective actions are verified.',
              ]),
            ],
          ),
          _Box(
            heading: 'Which Species Are Covered',
            children: const [
              _Para(
                  'The Humane Methods of Slaughter Act applies to cattle, pigs, sheep, goats, horses, and other livestock slaughtered in federally inspected establishments.',
                  size: 15),
              _Para(
                  'Poultry (chickens, turkeys, ducks) are not covered by the HMSA. There is no federal humane slaughter law for poultry. FSIS does have a policy requiring that poultry be treated humanely, but this is a regulatory policy rather than a statutory requirement, and enforcement is less rigorous than for livestock.',
                  size: 15),
              _Para(
                  'This means that humane handling enforcement data in the FAT App primarily reflects beef and pork establishments. The absence of humane handling violations at a poultry plant does not indicate good welfare practices — it reflects the lack of a legal standard.',
                  size: 15),
            ],
          ),
          _Box(
            heading: 'How FAT Displays Humane Handling Data',
            children: [
              const _Para(
                  'When you scan a label or look up an establishment, FAT shows humane handling enforcement history if any actions exist in the FSIS public record. This includes:',
                  size: 15),
              const _Bullets([
                'The type of enforcement action (RCA, NR, NOIE, suspension)',
                'The date and basis of the action',
                'Whether the action is open or resolved',
                'The regulatory citation (typically 9 CFR 313 for livestock stunning and handling)',
              ]),
              const _Para(
                  'An establishment with humane handling violations on record may have corrected its practices. Conversely, the absence of violations does not guarantee exemplary animal welfare — it means FSIS did not document a violation during the reporting period.',
                  size: 15),
            ],
          ),
          _Box(
            heading: 'Sources',
            headingSize: 15,
            children: const [
              _Bullets([
                'Humane Methods of Slaughter Act (7 U.S.C. § 1901–1907)',
                '9 CFR Part 313 — Humane Slaughter of Livestock',
                'FSIS Directive 6900.2 — Humane Handling and Slaughter of Livestock',
                'FSIS Quarterly Enforcement Reports',
              ], size: 13),
            ],
          ),
        ],
      ),
      // 2.13
      _LearnTopic(
        title: 'Quarterly Enforcement Reports',
        subtitle: 'NOIEs, suspensions, and closures',
        body: _text(
            'Every quarter, FSIS publishes enforcement actions taken against establishments. These include:\n\n'
            '• NOIEs (Notices of Intended Enforcement) — Formal notices that FSIS may suspend operations\n'
            '• Suspensions — Temporary shutdown of operations due to serious violations\n'
            '• Suspensions Held in Abeyance — Suspensions deferred while the establishment corrects problems\n'
            '• Closures — Permanent termination of operations\n\n'
            'The Quarterly Enforcement Report breaks down actions by establishment size (large, small, very small) and includes the regulatory basis for each action (e.g., HACCP violations, sanitation issues, humane handling failures).\n\n'
            'When FAT shows quarterly enforcement data, it includes the quarter, action type, basis codes, and whether actions remain open or have been closed.'),
      ),
      // 2.14
      _LearnTopic(
        title: 'Salmonella Performance Categories',
        subtitle: 'Poultry establishment pathogen ratings',
        body: _text(
            'Salmonella is one of the most important food safety concerns in poultry. FSIS assigns performance categories to chicken and turkey establishments based on Salmonella testing results.\n\n'
            'The Categories:\n'
            '• Category 1 — Best performance: Low Salmonella rates\n'
            '• Category 2 — Acceptable: Meets standards but room for improvement\n'
            '• Category 3 — Fails to meet standards: Exceeds acceptable Salmonella levels\n\n'
            'Why This Matters:\n'
            'Salmonella is the leading cause of bacterial foodborne illness in the United States. Category 3 establishments have failed to adequately control this pathogen. While proper cooking kills Salmonella, cross-contamination in the kitchen remains a serious risk.\n\n'
            'FSIS updates these categories regularly. An establishment in Category 3 may improve over time, or it may indicate persistent process control problems.\n\n'
            'When FAT shows a Category 3 rating, this is a significant food safety signal. Category 1 establishments demonstrate better pathogen control, though no poultry is risk-free without proper handling and cooking.'),
      ),
      // 2.15
      _LearnTopic(
        title: 'Beef E. coli & Salmonella Sampling',
        subtitle: 'Pathogen testing for beef establishments',
        body: _text(
            'For beef slaughter establishments, FSIS conducts routine microbiological testing for:\n\n'
            '• E. coli STEC (Shiga toxin-producing E. coli) — Including the deadly O157:H7 strain\n'
            '• Salmonella — A common bacterial pathogen\n\n'
            'FAT may show sampling data including:\n'
            '• Total samples collected\n'
            '• Number of positive samples\n'
            '• Positive rates (percentage)\n'
            '• Both routine sampling (regular monitoring) and follow-up sampling (after positive results)\n\n'
            'This data helps you understand an establishment\'s pathogen control performance. Lower positive rates indicate better process control, but remember that any beef can harbor pathogens — proper cooking is essential regardless of sampling results.'),
      ),
      // 2.16
      _LearnTopic(
        title: 'Chemical Residue Violations',
        subtitle: 'Drug residues detected at slaughter',
        body: _text(
            'Chemical residue violations occur when illegal levels of veterinary drugs, pesticides, or other compounds are found in meat at slaughter.\n\n'
            'Key points:\n'
            '• Producer Responsibility — The violation reflects on the farm or ranch that raised the animal, not necessarily the slaughter plant\n'
            '• Drug Withdrawal Periods — Most violations happen when animals are sent to slaughter before drugs have cleared their system\n'
            '• Zero Tolerance Compounds — Some drugs are completely banned; any detection is a violation\n'
            '• Severity Levels — FAT shows how far residue levels exceeded legal limits (2x, 5x, etc.)\n\n'
            'When FAT shows residue data, the producer names are displayed prominently because they are primarily responsible for the violation. The establishment is where the violation was detected, but the producer caused it.'),
      ),
      // 2.17 — custom("ownership_overview")
      _LearnTopic(
        title: 'Who Owns Your Meat and Seafood?',
        subtitle: 'Consolidation in US pork, beef, chicken, and seafood',
        body: [
          const _Para(
              'A small number of companies — many of them foreign-owned — now control the majority of US pork, beef, and chicken processing. This consolidation has taken place largely through acquisitions over the past 20 years.'),
          const _OwnershipTable(
            title: 'Pork Processing',
            hhi: '~1,620 (Moderately Concentrated)',
            rows: [
              '🇨🇳 WH Group (Smithfield) | China | ~27%',
              '🇺🇸 Tyson Foods | United States | ~18%',
              '🇧🇷 JBS USA | Brazil | ~16%',
              '🇺🇸 Hormel Foods | United States | ~10%',
            ],
          ),
          const _OwnershipTable(
            title: 'Beef Packing',
            hhi: '~2,000 (Moderately Concentrated)',
            rows: [
              '🇧🇷 JBS USA | Brazil | ~25%',
              '🇺🇸 Tyson Fresh Meats | United States | ~23%',
              '🇺🇸 Cargill Meat Solutions | United States | ~21%',
              '🇧🇷 National Beef (Marfrig) | Brazil | ~11%',
            ],
          ),
          const _OwnershipTable(
            title: 'Chicken Processing',
            hhi: '~1,300 (Unconcentrated)',
            rows: [
              '🇺🇸 Tyson Foods | United States | ~20%',
              '🇧🇷 Pilgrim\'s Pride (JBS) | Brazil | ~18%',
              '🇺🇸 Wayne-Sanderson Farms | United States | ~15%',
              '🇺🇸 Koch Foods | United States | ~9%',
              '🇺🇸 Perdue Farms | United States | ~8%',
            ],
          ),
          const _Para(
              'Market share estimates are based on USDA GIPSA data, industry reports, and public company filings as of 2024–2026. Figures are approximate and may vary by year and data source.',
              size: 13,
              opacity: 0.6,
              italic: true),
        ],
      ),
      // 2.18 — custom("foreign_ownership")
      _LearnTopic(
        title: 'Foreign Ownership in US Meat and Seafood',
        subtitle:
            'WH Group (China), JBS and Marfrig (Brazil), and foreign-owned seafood brands',
        body: [
          const _Para(
              'Two foreign-headquartered conglomerates — one Chinese and one Brazilian — together control a majority of US pork processing and a large share of US beef processing.'),
          const _OwnerCard(
            flag: '🇨🇳',
            owner: 'WH Group (Shuanghui International)',
            country: 'China',
            detail:
                'WH Group, headquartered in Hong Kong and Henan province, acquired Smithfield Foods in 2013 for \$7.1 billion — the largest Chinese acquisition of a US company at the time.\n\n'
                'Smithfield Foods is the world\'s largest pork producer. Through this acquisition, WH Group controls approximately 27% of US pork processing capacity, along with a large portfolio of consumer brands: Smithfield, Farmland, Eckrich, Gwaltney, John Morrell, Armour, Kretschmar, Nathan\'s Famous, and others.\n\n'
                'Regulatory context: The acquisition was reviewed by CFIUS (Committee on Foreign Investment in the United States) and approved without conditions.',
          ),
          const _OwnerCard(
            flag: '🇧🇷',
            owner: 'JBS S.A.',
            country: 'Brazil',
            detail:
                'JBS S.A., headquartered in São Paulo, Brazil, is the world\'s largest meat processing company. It is majority-owned by the Batista family through J&F Investimentos.\n\n'
                'In the US, JBS controls:\n'
                '• ~16% of pork processing (JBS USA, Swift pork)\n'
                '• ~25% of beef packing (JBS USA, Swift beef)\n'
                '• ~18% of broiler chicken (Pilgrim\'s Pride, acquired 2009)\n\n'
                'JBS has been involved in significant legal and regulatory controversies in Brazil, including a major corruption scandal in 2017 in which company executives admitted to bribing hundreds of Brazilian officials.',
          ),
          const _OwnerCard(
            flag: '🇧🇷',
            owner: 'Marfrig Global Foods',
            country: 'Brazil',
            detail:
                'Marfrig Global Foods S.A., headquartered in São Paulo, Brazil, is the second-largest beef processor in the world.\n\n'
                'In the US, Marfrig holds a controlling stake in National Beef Packing Company, headquartered in Kansas City, Missouri. National Beef controls approximately 11% of US fed cattle slaughter capacity.\n\n'
                'National Beef brands include: National Beef and the Kansas City Steak Company.',
          ),
          const _Para(
              'Foreign ownership is legal and subject to USDA, CFIUS, and antitrust review. The FAT App does not take a position on whether foreign ownership is good or bad — it presents ownership information as part of full transparency.',
              size: 14,
              opacity: 0.6,
              italic: true),
        ],
      ),
      // 2.19 — custom("hhi_explainer")
      _LearnTopic(
        title: 'Market Concentration & the HHI',
        subtitle: 'What the Herfindahl-Hirschman Index means',
        body: [
          const _Para(
              'The Herfindahl-Hirschman Index (HHI) is the standard measure of market concentration used by the US Department of Justice and the Federal Trade Commission to evaluate whether markets are competitively healthy.'),
          const _Box(
            heading: 'How it\'s calculated',
            children: [
              _Para(
                  'HHI = the sum of each firm\'s market share squared. A market with four equal firms (each at 25%) would have an HHI of 25² + 25² + 25² + 25² = 2,500.',
                  size: 15),
            ],
          ),
          const _Box(
            heading: 'DOJ/FTC thresholds',
            children: [
              _HhiThresholdRow(
                range: '< 1,500',
                label: 'Unconcentrated',
                color: FATTheme.successGreen,
                description:
                    'Competitive market. Mergers are generally approved without conditions.',
              ),
              _HhiThresholdRow(
                range: '1,500–2,500',
                label: 'Moderately Concentrated',
                color: FATTheme.fatOrange,
                description:
                    'Mergers raising HHI by 100+ points receive heightened scrutiny. Remedies (divestitures) may be required.',
              ),
              _HhiThresholdRow(
                range: '> 2,500',
                label: 'Highly Concentrated',
                color: FATTheme.fatRed,
                description:
                    'Mergers raising HHI by 200+ points are presumed anticompetitive. Blocking or substantial divestitures typical.',
              ),
            ],
          ),
          const _Box(
            heading: 'US meat industry scores',
            children: [
              _HhiIndustryRow(
                  industry: 'Pork',
                  score: '~1,620',
                  status: 'Moderate',
                  color: FATTheme.fatOrange),
              _HhiIndustryRow(
                  industry: 'Beef',
                  score: '~2,000',
                  status: 'Moderate',
                  color: FATTheme.fatOrange),
              _HhiIndustryRow(
                  industry: 'Chicken',
                  score: '~1,300',
                  status: 'Unconcentrated',
                  color: FATTheme.porkSmall),
            ],
          ),
          const _Para(
              'These estimates are based on available market share data as of 2024–2026. The beef industry is the most concentrated, approaching the upper boundary of the moderate range. The chicken industry is unconcentrated at the national level, though regional concentration — particularly for contract growers with access to only one or two buyers — is significantly higher.',
              size: 14),
          const _Box(
            heading: 'Why it matters for consumers',
            children: [
              _Para(
                  'High concentration in meat packing has been associated with:',
                  size: 15),
              _Bullets([
                'Reduced competition for livestock, meaning lower prices paid to farmers',
                'Higher retail meat prices for consumers during supply disruptions',
                'Reduced resilience — when one large plant shuts down, a large share of national supply is affected',
                'Less diversity of practices (animal welfare, feed, antibiotic use) across the supply chain',
              ]),
              _Para(
                  'The COVID-19 pandemic exposed the fragility of this structure: when several large packing plants closed or reduced capacity in 2020, US meat prices spiked sharply.',
                  size: 15),
            ],
          ),
          const _Box(
            heading: 'Sources',
            headingSize: 15,
            children: [
              _Bullets([
                'DOJ/FTC Horizontal Merger Guidelines (2010, revised 2023)',
                'USDA GIPSA Packers and Stockyards Program annual reports',
                'USDA Economic Research Service: Consolidation in US Meatpacking',
                'Institute for Agriculture and Trade Policy (IATP) market share analysis',
                'FAT Research Papers: Beef, Chicken, and Pork Industry Overviews (2026)',
              ], size: 13),
            ],
          ),
        ],
      ),
    ],
  ),

  // ════════════ SECTION 3 ════════════
  _LearnSection(
    title: 'Seafood: Shared & New Categories + Other Factors',
    topics: [
      // 3.1 — custom("seafood_scoring") → FATSeafoodScoringExplanationView (not detailed in spec)
      _LearnTopic(
        title: 'How FAT Reads Seafood Labels',
        subtitle: '16 categories, two-question model, FDA vs FSIS regulatory fork',
        body: [
          const _Para(
              'FAT reads a seafood label with the same two-question model used for meat: what did the label disclose (Step 1), and how credible is that claim (Step 2)? The disclosure statuses — Disclosed, Partial, Not disclosed — and the four credibility tiers work identically. What changes is the category list and one structural fact: the regulatory agency itself.'),
          const _Head('The FDA vs FSIS regulatory fork'),
          const _Para(
              'Almost all seafood is regulated by the FDA, which does not put an inspection mark or establishment number on consumer packaging. The single exception is Siluriformes (catfish, basa, swai, pangasius), regulated by USDA\'s FSIS exactly like meat — with an EST. number, inspection mark, and full enforcement pipeline. This fork determines which categories can be scored as Disclosed and which score as Not Required.'),
          const _Head('The 16 seafood transparency categories'),
          const _Bullets([
            'Regulatory Required Language — FSIS inspection mark for catfish; Not Required for all other seafood',
            'Species Identity — verified against the FDA Seafood List',
            'Strain / Variety',
            'Country / Origin — country of harvest plus production method (wild or farmed)',
            'Farm / Vessel / Fishery',
            'Processor — FSIS establishment number for catfish; Not Required for other seafood',
            'Production Method & Feed',
            'Animal Welfare',
            'Quality & Handling — fresh, frozen, previously frozen, glaze, added water',
            'Dietary Attributes & Additives — STPP, phosphate glazing, preservatives, colorants',
            'Medicine / Antibiotics / Chemicals',
            'Age at Harvest',
            'Enforcement & Compliance — full FSIS pipeline for catfish; Not Required for most other seafood',
            'Supply-Chain Intermediaries',
            'Environmental Impact — MSC, ASC, BAP; bycatch; gear impact (website only)',
            'Economic Concentration — corporate ownership and foreign control (website only)',
          ]),
          const _Para(
              'Where a category scores as Not Required, that reflects a regulatory gap — there is no consumer-facing federal record for it — rather than a failure by the producer. Full scoring methodology is available at farmanimaltransparency.com/how-fat-scores-meat-labels/.'),
        ],
      ),
      // 3.2 — custom("seafood_overview")
      _LearnTopic(
        title: 'How FAT Evaluates Seafood Labels',
        subtitle: 'Same model, adapted for seafood',
        body: [
          const _Para(
              'FAT evaluates seafood labels using the same two-question model used for meat: what does the label disclose, and how credible is the claim?'),
          const _Para(
              'The disclosure statuses (Known, Partial, Missing) and the four credibility tiers (Third-Party Audited, USDA-Reviewed, Producer Affidavit, Unverified Marketing) work identically. What changes are the 16 categories themselves, adapted for the regulatory, supply-chain, and species-identification realities of seafood.'),
          const _Rule(),
          _Box(
            heading: '16 Seafood Transparency Categories',
            children: const [
              _Bullets([
                'Regulatory Required Language — FSIS inspection mark (catfish); Not Required for all other seafood — FDA facility registration is an internal record and does not appear on consumer packaging',
                'Species Identity — Common and scientific name verified against the FDA Seafood List',
                'Strain / Variety — Specific strain (channel catfish, Atlantic salmon) or wild stock',
                'Country / Origin — Country of harvest plus production method (wild or farmed)',
                'Farm / Vessel / Fishery — Named source: farm (aquaculture) or vessel and fishery (wild)',
                'Processor — FSIS establishment number (catfish); Not Required for all other seafood — no consumer-label equivalent to the USDA EST number exists for non-catfish seafood',
                'Production Method & Feed — Wild-caught gear type or farmed system and feed',
                'Animal Welfare — Stocking density, slaughter method, third-party standards',
                'Quality & Handling — Fresh, frozen, previously frozen, glaze, added water',
                'Dietary Attributes & Additives — STPP, phosphate glazing, preservatives, colorants',
                'Medicine / Antibiotics / Chemicals — Antibiotic claims and banned import residues',
                'Age at Harvest — Grow-out period (farmed) or harvest season (wild)',
                'Enforcement & Compliance — Full FSIS pipeline for catfish (recalls, admin actions, humane handling, residue testing); Not Required for most other seafood — SIMP (Seafood Import Monitoring Program) covers only 13 specific high-risk imported species and domestic non-catfish seafood has no equivalent federal program',
                'Supply-Chain Intermediaries — Aquaculture grow-out farms, importers, aggregators, and distributors between the farm/vessel and the processor, plus each operation\'s captivity status (integrated, contracted, independent, or undisclosed)',
                'Environmental Impact — MSC, ASC, BAP certifications; bycatch; gear impact (website only)',
                'Economic Concentration — Corporate ownership and foreign control (website only)',
              ]),
            ],
          ),
          const _Rule(),
          _Box(
            heading: 'Seafood Credibility Tiers',
            children: const [
              _TierRow(
                icon: Icons.verified_user,
                color: FATTheme.successGreen,
                title: 'Third-Party Audited',
                description:
                    'MSC (Marine Stewardship Council) for wild-caught. ASC (Aquaculture Stewardship Council) or BAP (Best Aquaculture Practices) for farmed. Global GAP, Friend of the Sea, Ocean Wise. Independent on-farm / on-vessel audit by an organization that is neither the producer nor the regulator.',
              ),
              _TierRow(
                icon: Icons.verified,
                color: FATTheme.usdaApprovedBlue,
                title: 'USDA-Reviewed',
                description:
                    'USDA-administered program with audit teeth — primarily the FSIS catfish (and other Siluriformes) inspection mark. USDA Process-Verified Program where it applies to seafood operations.',
              ),
              _TierRow(
                icon: Icons.description_outlined,
                color: FATTheme.fatOrange,
                title: 'Producer Affidavit',
                description:
                    'FDA or FSIS approved the label language, backed by producer-maintained records and affidavits. No independent audit. Examples: COOL-compliant country of origin with production method, FSIS-approved species name claims.',
              ),
              _TierRow(
                icon: Icons.info_outline,
                color: FATTheme.fatRed,
                title: 'Unverified Marketing',
                description:
                    '"Sustainably sourced," "ocean-fresh," "responsibly farmed," "natural," "sushi grade" — no certifier logo and no government label-language approval identified.',
              ),
            ],
          ),
          const _Rule(),
          _Box(
            heading: 'Key Differences from Meat Scoring',
            children: const [
              _Bullets([
                'Species identity is verified against the FDA Seafood List — species mislabeling is a documented fraud vector in seafood but not in meat',
                'Seafood COOL requires disclosure of production method (wild or farmed) alongside country of origin — meat COOL does not',
                'Quality scoring includes fresh/frozen/previously-frozen status — labeling previously frozen product as fresh is a regulated violation',
                'Additives scoring includes phosphate glazing (STPP) and added water — chronic underdisclosure issues specific to seafood',
                'The regulatory agency itself is a scored disclosure — catfish uses FSIS with full enforcement data; all other seafood scores Processor and Regulatory Language as Not Required because no consumer-facing equivalent exists',
              ]),
            ],
          ),
          const _Para(
              'Full scoring methodology available at farmanimaltransparency.com/how-fat-scores-meat-labels/',
              size: 13,
              opacity: 0.6,
              italic: true),
        ],
      ),
      // 3.3 — custom("siluriformes")
      _LearnTopic(
        title: 'The Siluriformes Exception',
        subtitle: 'Why catfish is regulated by USDA, not FDA',
        body: [
          const _Para(
              'Catfish and all other Siluriformes (the biological order that includes catfish, basa, swai, and pangasius) are the only seafood regulated by USDA\'s Food Safety and Inspection Service rather than FDA.'),
          const _Para(
              'This means catfish products carry USDA FSIS inspection marks, USDA establishment numbers, and are subject to the same enforcement protocols as beef, pork, and poultry — including recalls, administrative actions, humane handling enforcement, quarterly enforcement reports, and chemical residue testing.'),
          const _Rule(),
          _Box(
            heading: 'Why This Matters',
            children: const [
              _Bullets([
                'When FAT detects a catfish or Siluriformes product, it routes to the FSIS enforcement data pipeline — the same data used for meat',
                'For all other seafood, Enforcement & Compliance scores as Not Required — SIMP traceability covers only 13 specific high-risk imported species and has no domestic equivalent; FDA facility registration numbers are internal records not printed on consumer labels',
                'The establishment number on a catfish label is a USDA EST. number; on other seafood, it is an FDA facility registration',
                'This regulatory split affects which inspection mark to look for, which enforcement database to query, and which banned-substance testing regime applies',
              ]),
            ],
          ),
          _Box(
            heading: 'Which Species Are Siluriformes?',
            children: const [
              _Bullets([
                'Channel catfish (Ictalurus punctatus) — U.S. farm-raised',
                'Blue catfish (Ictalurus furcatus) — U.S. farm-raised and wild',
                'Swai (Pangasianodon hypophthalmus) — primarily imported from Vietnam',
                'Basa (Pangasius bocourti) — primarily imported from Vietnam',
                'Pangasius — generic market name for Vietnamese catfish',
              ]),
              _Para(
                  'Important: Under U.S. law, only Ictalurus species can be labeled "catfish." Vietnamese tra and basa cannot carry the "catfish" label even though they are Siluriformes.',
                  size: 15),
            ],
          ),
          _Box(
            heading: 'Import Enforcement',
            children: const [
              _Para(
                  'FSIS conducts residue testing on imported Siluriformes for banned substances including malachite green, nitrofurans, and other compounds prohibited in U.S. aquaculture but documented in Southeast Asian imports. Imported catfish products must pass FSIS reinspection before entering U.S. commerce.',
                  size: 15),
            ],
          ),
          const _Para(
              'Source: FAT Seafood Research Series. Full papers available at farmanimaltransparency.com/fat-research/',
              size: 13,
              opacity: 0.6,
              italic: true),
        ],
      ),
      // 3.4 — custom("production_method")
      _LearnTopic(
        title: 'Wild-Caught vs. Farm-Raised',
        subtitle: 'Production method and what it means',
        body: [
          const _Para(
              'Under COOL (Country of Origin Labeling) requirements, seafood labels must disclose whether the product is wild-caught or farm-raised alongside the country of origin. This is a combined disclosure not required for meat.'),
          const _Rule(),
          _Box(
            heading: 'Wild-Caught Seafood',
            children: const [
              _Para(
                  'Wild-caught seafood is harvested from oceans, rivers, or lakes. FAT evaluates:',
                  size: 15),
              _Bullets([
                'Fishing gear type — pole-and-line, trawl, longline, purse seine, gillnet, trap, dredge, harpoon, diver harvest',
                'Bycatch implications — Some gear types (bottom trawl, gillnet) have high bycatch and habitat impact; others (pole-and-line, harpoon) are highly selective',
                'Fishery of origin — Whether the specific fishing area or stock is disclosed',
                'Sustainability certification — MSC certification is the gold standard for wild-caught',
              ]),
              _Para(
                  'Feed is scored as N/A for wild-caught products (the animal fed itself in the wild).',
                  size: 15),
            ],
          ),
          _Box(
            heading: 'Farm-Raised Seafood',
            children: const [
              _Para(
                  'Farm-raised (aquaculture) seafood is produced in controlled environments. FAT evaluates:',
                  size: 15),
              _Bullets([
                'Aquaculture system type — pond, recirculating (RAS), cage, open-net pen, flow-through',
                'Feed composition — What the fish are fed (fishmeal, soy-based, insect-based, etc.)',
                'Stocking density — How crowded the growing conditions are',
                'Sustainability certification — ASC, BAP, or Global GAP for farmed operations',
              ]),
              _Para('Fishing gear is scored as N/A for farmed products.',
                  size: 15),
            ],
          ),
          _Box(
            heading: 'Common Seafood Additives',
            children: const [
              _Para(
                  'Seafood labels frequently fail to disclose additives. FAT specifically checks for:',
                  size: 15),
              _Bullets([
                'STPP (sodium tripolyphosphate) — Phosphate glazing that retains water and inflates net weight. Must be declared but frequently is not.',
                'Carbon monoxide (CO) treatment — Maintains red color in tuna; may mask age and freshness.',
                'Sodium bisulfite / sulfites — Preservatives used on shrimp to prevent melanosis (black spot). Allergen concern.',
                'Added water — Water injected or absorbed during processing that increases product weight.',
              ]),
              _Para(
                  'These additives are a chronic underdisclosure issue in seafood. FAT flags their presence — or suspicious absence — as part of the Dietary Attributes & Additives category.',
                  size: 15),
            ],
          ),
        ],
      ),
      // 3.5 — custom("seafood_brand_lookup")
      _LearnTopic(
        title: 'Seafood Brand Lookup',
        subtitle:
            'Why seafood needs brand search instead of an establishment number',
        body: [
          const _Para(
              'Seafood does not surface in scan results the way meat does — most retail seafood packaging carries no federal establishment number, so brand search becomes the primary way to learn about the company behind the box of fillets.'),
          const _Para(
              'FDA facility registration numbers exist, but they are internal records and do not appear on consumer packaging. The Lookup tab fills the gap.',
              size: 15,
              opacity: 0.85),
          const _Rule(),
          _Box(
            heading: 'What brand search returns',
            children: const [
              _Bullets([
                'Corporate ownership and parent-company chain',
                'Processing-plant locations',
                'Fleet and vessel information for wild-caught operations',
                'Sourcing regions for both wild and farmed',
                'Aquaculture details (system, species, grow-out)',
                'Sustainability certifications: MSC, ASC, BAP, Friend of the Sea, Ocean Wise',
                'Regulatory and import-alert history where available',
              ]),
            ],
          ),
          _Box(
            heading: 'Major US retail brands in the database',
            children: const [
              _BrandRow(brand: 'Gorton\'s', parent: 'Nissui (Japan)'),
              _BrandRow(
                  brand: 'Mrs. Paul\'s', parent: 'Pinnacle Foods / Conagra'),
              _BrandRow(brand: 'SeaPak', parent: 'Rich Products'),
              _BrandRow(
                  brand: 'Sea Cuisine', parent: 'High Liner Foods (Canada)'),
              _BrandRow(brand: 'Bumble Bee', parent: 'FCF (Taiwan)'),
              _BrandRow(
                  brand: 'Chicken of the Sea',
                  parent: 'Thai Union (Thailand)'),
              _BrandRow(brand: 'StarKist', parent: 'Dongwon (South Korea)'),
              _BrandRow(
                  brand: 'Trident Seafoods', parent: 'Privately held (US)'),
            ],
          ),
          const _Para(
              'Foreign ownership of US seafood brands is common — most of the largest tuna and frozen-fillet brands on US shelves are owned by overseas parents. Brand search makes that ownership visible.',
              size: 14,
              opacity: 0.75,
              italic: true),
        ],
      ),
      // 3.6 — Service-Case Capture Schema (companion to Seafood Paper No. 5)
      _LearnTopic(
        title: 'Service-Case Capture Schema',
        subtitle:
            'Loose seafood at the counter — placard, identity, confidence, and tiered resolution',
        screenBuilder: (_) => const ServiceCaseSchemaScreen(),
        body: [
          const _Para(
              'Loose seafood at the full-service counter has no package to scan — it is governed by a USDA AMS placard, not an FDA package label, and whether any disclosure exists depends on the venue. This is the field schema FAT uses to capture it: what to read off the sign, how each field is normalized, and how confidence is assigned so the App never confirms more than a photo can prove.'),
          const _Para(
              'Try it: on the Scan tab, tap "Loose seafood at a counter?" to photograph a placard and see it resolved live.',
              size: 14,
              italic: true),
          const _Head('Design principles'),
          const _Bullets([
            'Capture the sign, not the fish — species identity carries an unverified state no image can upgrade.',
            'The venue gate runs first — establishment type decides whether a missing placard is a compliance finding or a non-event.',
            'One displayed name, captured verbatim, then resolved against the FDA Seafood List.',
            'Two facts are mandated (origin, method), one is not (species) — the schema encodes that asymmetry.',
          ]),
          const _Rule(),
          _Box(
            heading: 'Confidence vocabulary',
            children: const [
              _TierRow(
                  icon: Icons.check_circle,
                  color: FATTheme.successGreen,
                  title: 'known',
                  description:
                      'A legally mandated fact captured legibly from the placard, or a hard key resolved to a record. Applies to origin, method, shellfish cert.'),
              _TierRow(
                  icon: Icons.adjust,
                  color: FATTheme.fatAmber,
                  title: 'partial',
                  description:
                      'Captured but ambiguous, or a named value that cannot be verified beyond the sign. Applies to the Seafood List name match.'),
              _TierRow(
                  icon: Icons.help_outline,
                  color: FATTheme.fatRed,
                  title: 'unverified',
                  description:
                      'A claim a photo categorically cannot confirm; distinct from partial, never auto-upgraded. Applies to species identity.'),
              _TierRow(
                  icon: Icons.report_gmailerrorred,
                  color: FATTheme.textSecondary,
                  title: 'missing',
                  description:
                      'A fact required in this venue but absent — a compliance signal. Applies to origin/method at a covered retailer.'),
              _TierRow(
                  icon: Icons.do_not_disturb_on,
                  color: FATTheme.usdaApprovedBlue,
                  title: 'not_applicable',
                  description:
                      'The venue (or a processed item) is exempt, so absence is not a finding. Applies to fish markets, butcher shops, food service, and value-added items.'),
            ],
          ),
          const _Rule(),
          _Box(
            heading: 'Resolution flow',
            children: const [
              _Bullets([
                'Gate — exempt venue or processed item → not_applicable (capture name + advisory, no finding).',
                'Tier 1 Direct — a hard key (shellfish cert → ICSSL, or FSIS estab. # for Siluriformes) → known direct match.',
                'Tier 1 Disclosure — origin + method posted → known; required but absent → missing.',
                'Tier 2 Species name — Seafood List match → partial (name maps, fish unverified).',
                'Tier 3 Advisory — species = unverified + substitution-risk note.',
                'Lanes — AMS COOL · FDA integrity · (NOAA SIMP if imported).',
              ]),
            ],
          ),
          const _Para(
              'The one rule that protects the model: a record may state "this counter discloses farm-raised, Product of Chile" with confidence — but it may never state "this is Atlantic salmon" as fact. The displayed name is reported as displayed; species stays unverified with a substitution-risk note.'),
          const _Label('Source'),
          const _Para(
              'FAT Engineering Note — Service-Case Seafood Capture Schema (companion to Seafood Research Series, Paper No. 5). farmanimaltransparency.com/fat-research/',
              size: 13,
              opacity: 0.6,
              italic: true),
        ],
      ),
    ],
  ),
];

// ─── Deep links ──────────────────────────────────────────────────────────────

/// Opens the Learn "Service-Case Capture Schema" topic (loose seafood at a
/// counter) directly. Used by the Home loose-fish scan pill's "Learn more" link.
void openServiceCaseLearnTopic(BuildContext context) {
  final topic = _sections
      .expand((s) => s.topics)
      .firstWhere((t) => t.title == 'Service-Case Capture Schema');
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: topic.screenBuilder ?? (_) => _LearnDetailScreen(topic: topic),
    ),
  );
}

// ─── Main Learn Screen ───────────────────────────────────────────────────────

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _heroHeader()),
          SliverToBoxAdapter(
            child: Container(
              height: 2,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              color: FATTheme.primaryGreen,
            ),
          ),
          SliverToBoxAdapter(child: _tocHeader()),
          for (final section in _sections)
            SliverToBoxAdapter(child: _sectionHeader(section, context)),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _heroHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/hero.jpg',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
            const Text(
              'LEARN',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
                shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tocHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Table of Contents',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Tap any topic to open it.',
            style: TextStyle(fontSize: 14, color: FATTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(_LearnSection section, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              section.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: FATTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: FATTheme.primaryGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              children: List.generate(section.topics.length, (i) {
                final topic = section.topics[i];
                final isLast = i == section.topics.length - 1;
                return Column(
                  children: [
                    _tocRow(i + 1, topic, context),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 48,
                        color: Color(0x40FFFFFF),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tocRow(int number, _LearnTopic topic, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                topic.screenBuilder ?? (_) => _LearnDetailScreen(topic: topic),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$number',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0x8C000000),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.black.withValues(alpha: 0.6),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right,
                  size: 18, color: Color(0x66000000)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Screen ───────────────────────────────────────────────────────────

class _LearnDetailScreen extends StatelessWidget {
  final _LearnTopic topic;
  const _LearnDetailScreen({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FATTheme.primaryGreen,
      appBar: AppBar(
        backgroundColor: FATTheme.primaryGreen,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          topic.title,
          style: const TextStyle(
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
            Text(
              topic.subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: FATTheme.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < topic.body.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              topic.body[i].build(),
            ],
            const SizedBox(height: 28),
            const Center(
              child: Text(
                'farmanimaltransparency.com',
                style: TextStyle(
                  fontSize: 13,
                  color: FATTheme.scanGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
