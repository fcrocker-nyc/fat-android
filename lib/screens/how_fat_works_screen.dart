import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';

/// Dedicated "How FAT works" page — Flutter port of iOS HowFATWorksView.
///
/// The full methodology explainer that used to live inline on the Home screen.
/// Split out so Home leads with the action (scan / look up) and the at-a-glance
/// read, with the method one tap away. Opens on a disclosure-first frame: FAT
/// reports what a label discloses across 16 categories and how well each claim
/// is backed — it is not a verdict on the food.
class HowFATWorksScreen extends StatelessWidget {
  const HowFATWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('How FAT Works',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _introCard(),
              const SizedBox(height: 20),

              _sectionHeader('How FAT Reads a Label'),
              const SizedBox(height: 10),
              const Text(
                'Every FAT read is the result of a three-step analysis. Each step asks a different question about the label.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _stepCard(1, 'What is disclosed?',
                  'We read the label and check which of 16 transparency categories are addressed — species, brand, processor, feed, welfare, hormones, organic, age at slaughter, country of origin, supply-chain intermediaries, and so on. Each category is marked Disclosed, Partially disclosed, or Not disclosed.'),
              const SizedBox(height: 16),
              _stepCard(2, 'How credible is the disclosure?',
                  'A claim can be Third-Party Audited (independent on-farm audit), USDA-Reviewed (Process Verified, USDA grade marks, FSIS catfish inspection), Producer Affidavit (FSIS approved the label language but only an affidavit backs it — no on-farm audit), or Unverified Marketing (no audit and no government label-language approval). The same disclosure can carry very different weight depending on which tier applies.'),
              const SizedBox(height: 16),
              _stepCard(3, 'Who stands behind the label?',
                  'The processor and its FSIS / FDA enforcement record (recalls, residue violations, humane-handling actions, FDA import alerts), the brand owner and the corporate parent, foreign-ownership status, and economic concentration / HHI for the supply chain. The label is one source of information; the public record is another.'),
              const SizedBox(height: 16),
              Text(
                'Same model documented at farmanimaltransparency.com/learn-how-to-read-meat-labels/.',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withAlpha(165),
                    fontStyle: FontStyle.italic),
              ),

              const SizedBox(height: 20),
              _sectionHeader('How to Read a FAT Card'),
              const SizedBox(height: 10),
              _readRow(Icons.bar_chart,
                  'The meter shows how many of 16 transparency categories the brand discloses. Fuller means more open — not "better."'),
              _readRow(Icons.shield_outlined,
                  'The USDA FSIS-minimum line rides on every card, so a low count is never read as a safety flag.'),
              _readRow(Icons.verified,
                  'The last line shows how the disclosed claims are backed — from unverified marketing to independently audited.'),
              const SizedBox(height: 6),
              const Text(
                'A count, not a grade. FAT rates the disclosure — never the food.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: FATTheme.scanGreen),
              ),

              const SizedBox(height: 20),
              _sectionHeader('The Three Lights'),
              const SizedBox(height: 10),
              const Text(
                'Every category on the results screen carries one of three colors. The same color always means the same thing.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              _lightRow(const Color(0xFF34A853), 'Green',
                  'Disclosed and either independently verified or backed by a federal program with audit teeth.'),
              _lightRow(const Color(0xFFFBC02D), 'Amber',
                  'Partially disclosed, or disclosed but backed only by a producer affidavit or a USDA label-language review.'),
              _lightRow(Colors.red, 'Red',
                  'Not disclosed at all — or, for required FSIS / FDA language (the establishment number on meat, the regulatory inspection mark on seafood), the required content is missing entirely.'),

              const SizedBox(height: 20),
              _sectionHeader('More About FAT'),
              const SizedBox(height: 12),
              _paragraphView(1, 'How It Works',
                  'Scan a meat, poultry, or seafood label with your phone. FAT runs the three steps automatically and reports what the label discloses across 16 categories and how well each claim is backed.'),
              const SizedBox(height: 12),
              _paragraphView(2, 'Transparency Categories',
                  'FAT evaluates species, breed, origin, feed, grazing practices, living conditions, outdoor access, animal welfare, antibiotics, hormones, slaughter practices, and processor information.'),
              const SizedBox(height: 12),
              _paragraphView(3, 'Processor & Enforcement Data',
                  'When a USDA establishment number is found on the label, FAT retrieves public FSIS data including recalls, administrative actions, humane handling violations, quarterly enforcement reports, chemical residue violations, and pathogen testing results.'),
              const SizedBox(height: 12),
              _paragraphView(4, 'Lookup',
                  'Can\'t scan a label? The Lookup tab lets you search three ways: enter a USDA establishment number to view processor details and enforcement history, search by meat brand to see corporate ownership and market concentration for companies like Tyson, Smithfield, JBS, and Perdue, or search by seafood brand to see corporate ownership, sourcing regions, plant locations, fleet information, and sustainability certifications for brands like Gorton\'s, StarKist, and Bumble Bee.'),
              const SizedBox(height: 12),
              _paragraphView(5, 'Questions?',
                  'Have a question about a scan result? Tap the Questions button on any results page to send the details directly to FAT for review.'),
              const SizedBox(height: 12),
              _paragraphView(6, 'History & Saved Scans',
                  'Access your saved evaluations anytime in the History tab. For seafood-specific topics — how FAT scores seafood labels, the FSIS-vs-FDA regulatory fork, wild-caught vs farmed, and the parent-company brand database — see the Learn tab.'),
            ],
          ),
        ),
      ),
    );
  }

  // ── Intro card (disclosure-first frame + independence) ────────────────────

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: FATTheme.scanGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meets USDA FSIS minimums — as is required of all federally inspected meat and catfish.',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'FAT reports what a label discloses across 16 transparency categories, and how well each claim is backed. It is not a rating of the food — a low disclosure count is not a safety flag. It tells you how much the brand chose to tell you.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Independent · No ads · No sponsors. FAT scores disclosure, not the product — so there is nothing for a brand to buy its way out of.',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FATTheme.scanGreen),
          ),
        ],
      ),
    );
  }

  // ── Reused card builders (moved from HomeScreen) ──────────────────────────

  Widget _sectionHeader(String text) => Text(text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));

  Widget _stepCard(int number, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: FATTheme.scanGreen, shape: BoxShape.circle),
            child: Text('$number',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: FATTheme.scanGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _lightRow(Color color, String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: CircleAvatar(radius: 9, backgroundColor: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(text, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraphView(int number, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number. ',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
