import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';

// ─── Data model ────────────────────────────────────────────────────────────

class _LearnTopic {
  final String title;
  final String subtitle;
  final String body;
  const _LearnTopic({required this.title, required this.subtitle, required this.body});
}

class _LearnSection {
  final String title;
  final String? intro;
  final List<_LearnTopic> topics;
  const _LearnSection({required this.title, this.intro, required this.topics});
}

const _sections = <_LearnSection>[
  _LearnSection(
    title: 'How FAT Scores a Label',
    intro:
        'Every FAT score is the result of a three-step analysis: (1) what categories of information are disclosed on the label, (2) how credible those disclosures are, and (3) what the public record says about the entities behind the product — processors, parent companies, enforcement history, market concentration. Meat and seafood both go through these three steps; what differs is the category list and the entity-facts that apply.',
    topics: [
      _LearnTopic(
        title: 'The Three Steps of a FAT Score',
        subtitle: 'Disclosure → Credibility → Entity Facts',
        body:
            'Step 1 — What was disclosed?\nWe read the label and check which transparency categories are present. For meat, there are 15 categories (species, breed, country of origin, farm/ranch, processor, feed, animal welfare, and more). Each category gets one of three states: Disclosed (green), Partially disclosed (amber), or Not disclosed (red).\n\nStep 2 — How credible is what was disclosed?\nA claim can be Third-Party Audited, USDA-Reviewed, Producer Affidavit, or Unverified Marketing. The same disclosure can carry very different weight depending on which of those four credibility tiers applies.\n\nStep 3 — Who is behind this product?\nThe processor\'s enforcement history, parent company ownership and concentration, foreign ownership, recall history, and pathogen testing results are all relevant facts that don\'t appear on the label but do affect what the consumer is actually buying.',
      ),
      _LearnTopic(
        title: 'Step 1 — What Is Disclosed',
        subtitle: 'The 15 categories, the three lights, and the A–F grade',
        body:
            'FAT checks 15 categories on every meat or poultry label:\n\n• Species • Breed • Country of Origin • Farm / Ranch • Processor • Feed • Animal Welfare • Pasture / Outdoor Access • Quality • Dietary Attributes • Medicine / Antibiotics • Age at Slaughter • USDA / FSIS Required Language • Establishment Number\n\nEach category shows green (known), amber (partial), or red (missing). The overall disclosure score is 50 points of the 0–100 FAT score.',
      ),
      _LearnTopic(
        title: 'Step 2 — How Credible Is the Disclosure',
        subtitle:
            'Third-Party Audited · USDA-Reviewed · Producer Affidavit · Unverified Marketing',
        body:
            'Four credibility tiers, from strongest to weakest:\n\n① Third-Party Audited — independent on-farm audit by an organization that is neither the producer nor the regulator. Examples: USDA Organic, Certified Humane, AGW, AGA, MSC, ASC.\n\n② USDA-Reviewed — USDA-administered program with audit teeth: Process Verified, USDA grade marks, FSIS catfish inspection.\n\n③ Producer Affidavit — FSIS approved the label language, backed by a producer affidavit only — no on-farm audit.\n\n④ Unverified Marketing — printed on the label with no audit and no government label-language approval.',
      ),
      _LearnTopic(
        title: 'Step 3 — Who Stands Behind the Label',
        subtitle:
            'Processor enforcement · brand owner · parent company · foreign ownership · HHI',
        body:
            'The label is one source of information. The entities behind the label are another. Step 3 surfaces what the public record says about them.\n\nProcessor & enforcement record: FAT pulls the processor\'s public enforcement record — recalls, humane-handling violations, quarterly enforcement actions, Salmonella performance categories, beef pathogen sampling results, and chemical-residue findings.\n\nBrand owner & corporate parent: Many shelf brands are subsidiary product lines of much larger corporations.\n\nForeign ownership: WH Group (China) owns Smithfield. JBS and Marfrig (Brazil) own significant U.S. beef capacity.\n\nMarket concentration: Measured by the Herfindahl-Hirschman Index (HHI). Highly concentrated supply chains affect price formation and producer leverage.',
      ),
    ],
  ),
  _LearnSection(
    title: 'Meat & Poultry: Categories, Enforcement, Ownership',
    intro:
        'Everything FAT looks at on a meat, poultry, lamb, turkey, or bison label. The first set of topics explains the 15 disclosure categories that drive Step 1 (welfare, grass-fed, antibiotics, origin, breed). The second set covers the Step 3 entity-facts: USDA establishment numbers, FSIS enforcement data (recalls, humane handling, quarterly enforcement, Salmonella, residues), and the corporate-ownership picture.',
    topics: [
      _LearnTopic(
        title: 'Animal Welfare Certification Ratings',
        subtitle: 'What the color-coded ratings mean',
        body:
            'FAT rates six major third-party welfare certifiers:\n\n• Animal Welfare Approved (AGW) — Strongest standards. Pasture-based, independent annual audits, limited to family farms.\n• Certified Humane (HFAC) — Three tiers: Base, Free Range, Pasture Raised. Only Free Range and Pasture Raised tiers require outdoor access.\n• Global Animal Partnership (GAP) — 5-step program. Steps 1–2 require no outdoor access. Steps 3–5 add pasture.\n• USDA Organic — Improving; new welfare rules required by 2029.\n• American Humane Certified — Widest reach, weakest standards. No outdoor access required.\n• One Health Certified — Industry-created; standards largely reflect existing industrial practices.',
      ),
      _LearnTopic(
        title: 'Grass-Fed and Grass-Finished Claims',
        subtitle: 'What FSIS actually requires — and what it doesn\'t',
        body:
            '"Grass-fed" requires 100% forage after weaning, no grain, and continuous pasture access during the growing season. Applies to beef and lamb only.\n\n"Grass-finished" is the weaker claim — only the final finishing phase must be on grass. Grain feeding earlier in life is permitted.\n\nEnforcement: FSIS approves grass-fed labels based on a producer affidavit — no independent on-farm audit required.\n\nCredible third-party certifications:\n• American Grassfed Association (AGA) — independent inspection every 15 months\n• Certified Grassfed by A Greener World (AGW) — birth-to-slaughter traceability',
      ),
      _LearnTopic(
        title: 'Antibiotics and Meat Labels',
        subtitle: 'What antibiotic claims do and don\'t mean',
        body:
            'Antibiotics are legally permitted in most U.S. livestock production.\n\n"No Antibiotics Ever" (NAE) is the strongest FSIS-approved claim — covers the animal\'s entire life. "Raised Without Antibiotics" (RWA) is equivalent. Both are producer-affidavit claims — no independent on-farm audit is required.\n\nIn poultry, "no hormones" language reflects federal rules (hormones are banned in poultry) and does not address antibiotic use.\n\nIf antibiotic practices are not disclosed, FAT treats that as missing information — not evidence of use or non-use.',
      ),
      _LearnTopic(
        title: 'Species, Breed, and Genetics',
        subtitle: 'Why breed is rarely disclosed',
        body:
            'Most meat labels identify the species (beef, pork, chicken). Far fewer disclose breed or genetic information.\n\nBreed claims can be meaningful — Angus beef, Berkshire pork, heritage breeds — but many labels provide no breed information at all.\n\nFAT reports breed only when it is explicitly disclosed on the label.',
      ),
      _LearnTopic(
        title: 'Country of Origin Claims',
        subtitle: 'Born, raised, and processed distinctions',
        body:
            'Some labels state where animals were born, raised, or harvested. Others use general phrases such as "Product of the U.S." or provide no origin information.\n\nFAT reports origin claims as disclosed only when the label provides specific, reliable information.\n\nNote: Country of Origin Labeling (COOL) requirements for beef were weakened in 2015. Most beef sold in the U.S. no longer requires a country of origin label.',
      ),
      _LearnTopic(
        title: 'USDA Establishment Numbers',
        subtitle: 'What EST. numbers identify',
        body:
            'Every federally-inspected meat product must carry a USDA establishment number (9 CFR 317.2 for meat; 9 CFR 381.96 for poultry).\n\nMeat: "EST. XXXX"\nPoultry: "P-XXXXX"\n\nThe EST number identifies the federally inspected facility where the product was processed. It does not imply food safety, quality, or regulatory performance.\n\nFAT retrieves the processor\'s name, address, and enforcement history from public FSIS records using the EST number.',
      ),
      _LearnTopic(
        title: 'Understanding FSIS Enforcement Data',
        subtitle: 'Recalls, violations, and what they mean',
        body:
            'What the data shows:\n• Recalls — Product recalls due to contamination, mislabeling, or safety concerns\n• Administrative Actions — Enforcement actions like warnings or compliance issues\n• Humane Handling Violations — Actions for violations of humane slaughter requirements\n• Quarterly Enforcement Actions — NOIEs, suspensions, and regulatory actions\n• Chemical Residue Violations — Illegal drug residues detected in animals at slaughter\n• Salmonella Performance — Critical pathogen testing results for poultry\n• Beef Pathogen Testing — E. coli and Salmonella sampling for beef\n\nEnforcement data reflects regulatory compliance history, not current product safety.',
      ),
      _LearnTopic(
        title: 'Product Recalls',
        subtitle: 'Class I, II, and III severity levels',
        body:
            'FSIS issues recalls when meat or poultry products pose a health risk or violate federal regulations. Recalls are classified by severity:\n\n• Class I — Serious health hazard (e.g., E. coli O157:H7, Listeria)\n• Class II — May cause temporary health problems (e.g., undeclared allergens, foreign material)\n• Class III — Unlikely to cause health problems (e.g., minor labeling issues)\n\nFAT shows recall history for each establishment, including the recall class, reason, and current status (open or closed).',
      ),
      _LearnTopic(
        title: 'Salmonella Performance Categories',
        subtitle: 'Poultry establishment pathogen ratings',
        body:
            'FSIS assigns performance categories to chicken and turkey establishments based on Salmonella testing results:\n\n• Category 1 — Best performance: Low Salmonella rates\n• Category 2 — Acceptable: Meets standards but room for improvement\n• Category 3 — Fails to meet standards: Exceeds acceptable Salmonella levels\n\nSalmonella is the leading cause of bacterial foodborne illness in the United States. Category 3 establishments have failed to adequately control this pathogen.',
      ),
      _LearnTopic(
        title: 'Who Owns Your Meat?',
        subtitle: 'Consolidation in US pork, beef, chicken, and seafood',
        body:
            'The U.S. meat industry is highly consolidated:\n\n• 4 companies control ~80% of U.S. beef packing (JBS, Tyson, Cargill, National Beef)\n• 4 companies control ~60% of U.S. pork packing (WH Group/Smithfield, JBS, Tyson, Seaboard)\n• 3 companies control ~60% of U.S. broiler chicken (Tyson, Pilgrim\'s/JBS, Perdue)\n\nBrand names familiar to consumers often belong to parent corporations that are far larger. Eckrich, Nathan\'s Famous, and Farmland are all Smithfield brands. Smithfield is owned by WH Group, a Chinese corporation.',
      ),
      _LearnTopic(
        title: 'Foreign Ownership in US Meat and Seafood',
        subtitle:
            'WH Group (China), JBS and Marfrig (Brazil), and foreign-owned seafood brands',
        body:
            'WH Group (China) owns Smithfield Foods — the world\'s largest pork producer and processor. Smithfield\'s brands include Eckrich, Nathan\'s Famous, Farmland, Armour, and Healthy Ones.\n\nJBS (Brazil) is the world\'s largest meat processor. U.S. beef brands include Swift, Certified Angus Beef (processing), and more. JBS also owns Pilgrim\'s Pride (chicken).\n\nMajor seafood brands are also foreign-owned:\n• Gorton\'s — Nissui (Japan)\n• Bumble Bee — FCF (Taiwan)\n• Chicken of the Sea — Thai Union (Thailand)\n• StarKist — Dongwon (South Korea)',
      ),
    ],
  ),
  _LearnSection(
    title: 'Seafood: Categories and Factors',
    intro:
        'Seafood goes through the same three steps as meat (disclosure → credibility → entity facts). Some categories are shared with meat. Others are seafood-specific: wild-caught vs. farm-raised, the FDA/FSIS regulatory fork (catfish is regulated by USDA FSIS; every other seafood by FDA), and seafood brand lookup in place of an establishment number.',
    topics: [
      _LearnTopic(
        title: 'How FAT Scores Seafood Labels',
        subtitle: '15 categories, two-question model, FDA vs FSIS fork',
        body:
            'FAT uses the same two-question model for seafood: what does the label disclose, and how credible is the claim?\n\nThe 15 seafood categories differ from meat:\n• Species Identity (verified against FDA Seafood List)\n• Strain / Variety\n• Country / Origin + Production Method (wild or farmed)\n• Farm / Vessel / Fishery\n• Processor\n• Production Method & Feed\n• Animal Welfare\n• Quality & Handling\n• Dietary Attributes & Additives\n• Medicine / Antibiotics / Chemicals\n• Age at Harvest\n• Enforcement & Compliance\n• Environmental Impact\n• Economic Concentration\n• Regulatory Required Language',
      ),
      _LearnTopic(
        title: 'The Siluriformes Exception',
        subtitle: 'Why catfish is regulated by USDA, not FDA',
        body:
            'Catfish and all other Siluriformes (catfish, basa, swai, pangasius) are the only seafood regulated by USDA\'s Food Safety and Inspection Service rather than FDA.\n\nThis means catfish products carry USDA FSIS inspection marks, USDA establishment numbers, and are subject to the same enforcement protocols as beef, pork, and poultry — including recalls, administrative actions, humane handling enforcement, and chemical residue testing.\n\nFor all other seafood, Enforcement & Compliance scores as Not Required — no consumer-facing equivalent to the USDA EST number exists.',
      ),
      _LearnTopic(
        title: 'Wild-Caught vs. Farm-Raised',
        subtitle: 'Production method and what it means',
        body:
            'Under COOL (Country of Origin Labeling) requirements, seafood labels must disclose whether the product is wild-caught or farm-raised alongside the country of origin.\n\nWild-caught: FAT evaluates fishing gear type (pole-and-line, trawl, longline), bycatch implications, fishery of origin, and sustainability certification (MSC).\n\nFarm-raised: FAT evaluates aquaculture system type, feed composition, stocking density, and sustainability certification (ASC, BAP).\n\nCommon additives FAT checks for: STPP (phosphate glazing), carbon monoxide treatment, sodium bisulfite, and added water — a chronic underdisclosure issue in seafood.',
      ),
      _LearnTopic(
        title: 'Seafood Brand Lookup',
        subtitle: 'Why seafood needs brand search instead of an EST number',
        body:
            'Most retail seafood packaging carries no federal establishment number, so brand search is the primary way to learn about the company behind the product.\n\nBrand search returns:\n• Corporate ownership and parent-company chain\n• Processing-plant locations\n• Sourcing regions\n• Sustainability certifications (MSC, ASC, BAP)\n• Regulatory and import-alert history\n\nForeign ownership of US seafood brands is common — most of the largest tuna and frozen-fillet brands on US shelves are owned by overseas parents.',
      ),
    ],
  ),
];

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
          SliverToBoxAdapter(child: _independenceBadges()),
          SliverToBoxAdapter(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: FATTheme.primaryGreen,
            ),
          ),
          SliverToBoxAdapter(child: _tocHeader()),
          for (final section in _sections) ...[
            SliverToBoxAdapter(child: _sectionHeader(section, context)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _heroHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/hero.jpg',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Container(
          height: 200,
          width: double.infinity,
          color: Colors.black.withOpacity(0.25),
        ),
        const Text(
          'LEARN',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
          ),
        ),
      ],
    );
  }

  Widget _independenceBadges() {
    const style = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: FATTheme.scanGreen);
    const iconColor = FATTheme.scanGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: FATTheme.scanGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FATTheme.scanGreen.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.verified, size: 15, color: iconColor),
                SizedBox(width: 5),
                Text('Independent', style: style),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: FATTheme.scanGreen.withOpacity(0.3)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.block, size: 15, color: iconColor),
                SizedBox(width: 5),
                Text('No Ads', style: style),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: FATTheme.scanGreen.withOpacity(0.3)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.money_off, size: 15, color: iconColor),
                SizedBox(width: 5),
                Text('No Sponsors', style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tocHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Table of Contents',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 3),
          Text('Tap any topic to open it.',
              style: TextStyle(fontSize: 14, color: FATTheme.textSecondary)),
          SizedBox(height: 8),
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
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              section.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FATTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (section.intro != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                section.intro!,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87, height: 1.5),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: FATTheme.primaryGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(section.topics.length, (i) {
                final topic = section.topics[i];
                final isLast = i == section.topics.length - 1;
                return Column(
                  children: [
                    _tocRow(i + 1, topic, context),
                    if (!isLast)
                      const Divider(
                          height: 1, indent: 48, color: Colors.white38),
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
            builder: (_) => _LearnDetailScreen(topic: topic),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$number.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                topic.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Screen ────────────────────────────────────────────────────────────

class _LearnDetailScreen extends StatelessWidget {
  final _LearnTopic topic;
  const _LearnDetailScreen({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FATTheme.primaryGreen,
      appBar: AppBar(
        backgroundColor: FATTheme.primaryGreen,
        elevation: 0,
        title: Text(topic.title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800)),
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
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              topic.body,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'farmanimaltransparency.com',
                style: TextStyle(
                    fontSize: 13,
                    color: FATTheme.scanGreen,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
