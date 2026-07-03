import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';
import '../data/lookup_router.dart';
import 'about_screen.dart';
import 'learn_screen.dart';
import 'service_case_capture_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onScanTap;
  final void Function(int tab, String query) onQuickLookup;
  const HomeScreen({
    super.key,
    required this.onScanTap,
    required this.onQuickLookup,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMore = false;
  final TextEditingController _qlController = TextEditingController();

  @override
  void dispose() {
    _qlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heroImage(context),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _independenceBadge(),
                    const SizedBox(height: 20),
                    _scanCTA(),
                    const SizedBox(height: 12),
                    // LOOSE FISH — service-case scan, directly under the main
                    // scan pill and styled with the same forest-green fill.
                    _looseFishCTA(context),
                    const SizedBox(height: 20),
                    // QUICK LOOKUP — compact, directly under the scan CTA so a
                    // lookup can be started from Home without opening the tab.
                    _quickLookupCard(),
                    const SizedBox(height: 20),
                    const Divider(
                      color: FATTheme.primaryGreen,
                      thickness: 2,
                      indent: 16,
                      endIndent: 16,
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How FAT Scores a Label',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Every FAT score is the result of a three-step analysis. Each step asks a different question about the label.',
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
                          _sectionHeader('How the Score Is Calculated'),
                          const SizedBox(height: 10),
                          const Text(
                            'The 0–100 FAT Score is split 70% Disclosure / 30% Credibility. Step 3 sits alongside the score as public-record context, not as added points.',
                            style: TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 14),
                          _pillarCard('Pillar 1 — Disclosure (70 pts)',
                              'Each transparency category contributes up to 5 pts when fully Known, 2 pts when Partial, 0 when Missing. Breed is intentionally capped at 5 pts so a single-attribute disclosure cannot dominate the score. Categories share the 70-pt pillar.'),
                          const SizedBox(height: 10),
                          _pillarCard('Pillar 2 — Credibility (30 pts)',
                              'Among the categories that disclosed something, FAT averages the credibility weight: Third-Party Audited 1.0 · USDA-Reviewed 0.7 · Producer Affidavit 0.4 · Unverified Marketing 0.1. The average is multiplied by 30.'),
                          const SizedBox(height: 10),
                          _pillarCard(
                              'Step 3 — Who Stands Behind the Label (context)',
                              'FSIS / FDA enforcement history, brand owner and corporate parent, foreign-ownership status, and economic concentration / HHI for the supply chain. Surfaced on the results screen as a separate panel — flags a product even when its own label scores high. Not added to the 0–100 number.'),
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
                          _sectionHeader('How the A–F Grade Works'),
                          const SizedBox(height: 10),
                          _gradeRow('A', '80–100', const Color(0xFF34A853),
                              'Comprehensive disclosure, strongly backed claims.'),
                          _gradeRow('B', '65–79', const Color(0xFF64B446),
                              'Good disclosure with solid credibility.'),
                          _gradeRow('C', '50–64', const Color(0xFFFBC02D),
                              'Moderate disclosure or mixed credibility.'),
                          _gradeRow('D', '35–49', const Color(0xFFEA8600),
                              'Limited disclosure or weakly backed claims.'),
                          _gradeRow('F', '0–34', Colors.red,
                              'Minimal disclosure, little or no verification.'),
                          const SizedBox(height: 8),
                          Text(
                            "A high A means the label tells a complete story and that story is well-backed. An F doesn't mean the product is bad — it means the consumer has very little to go on. Step 3 (above) can flag a product even at high grades.",
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withAlpha(165),
                                fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => setState(() => _showMore = !_showMore),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _showMore ? 'Show Less' : 'More About FAT',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: FATTheme.scanGreen),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _showMore
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                    color: FATTheme.scanGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showMore) ...[
                            _paragraphView(1, 'How It Works',
                                'Scan a meat, poultry, or seafood label with your phone. FAT runs the three steps automatically and reports a 0–100 score plus an A–F grade.'),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────

  Widget _heroImage(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('assets/images/hero.jpg',
                      fit: BoxFit.cover),
                ),
                // Title text — bottom center
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('The FAT App',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black54)
                              ])),
                      SizedBox(height: 4),
                      Text('Farm Animal Transparency',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black54)
                              ])),
                    ],
                  ),
                ),
                // Info button — top right
                Positioned(
                  top: 8,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.info, color: Colors.white, size: 26),
                    ),
                  ),
                ),
                // Diagonal orange ribbon — top left
                Positioned(
                  top: 40,
                  left: -30,
                  child: Transform.rotate(
                    angle: -35 * math.pi / 180,
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.orange,
                      child: const Text(
                        'NOW Seafood, Turkey, Lamb',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Independence badge ──────────────────────────────────────────────────

  Widget _independenceBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: FATTheme.scanGreen.withValues(alpha: 0.06),
        border: Border.all(color: FATTheme.scanGreen.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _pill(Icons.verified, 'Independent'),
          _divider(),
          _pill(Icons.block, 'No Ads'),
          _divider(),
          _pill(Icons.money_off, 'No Sponsors'),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: FATTheme.scanGreen),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: FATTheme.scanGreen)),
      ],
    );
  }

  Widget _divider() => Container(
      height: 28, width: 1, color: FATTheme.scanGreen.withValues(alpha: 0.3));

  // ── Scan CTA ────────────────────────────────────────────────────────────

  Widget _scanCTA() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: widget.onScanTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: FATTheme.scanGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.center_focus_weak, color: Colors.white, size: 26),
              SizedBox(width: 14),
              Text('Scan Meat/Seafood Label',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loose fish CTA (service-case scan) ──────────────────────────────────

  Widget _looseFishCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServiceCaseCaptureScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: FATTheme.scanGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Scan Loose Fish at a Counter',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '“Loose fish” is seafood sold from a full-service case with no '
                'package to scan. FAT reads the counter placard instead — the '
                'USDA AMS sign that shows country of origin and wild vs. farmed.',
                style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.92)),
              ),
              const SizedBox(height: 12),
              // Learn link — own hit target so it doesn't trigger the scan.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openServiceCaseLearnTopic(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('How FAT reads a counter placard — Learn more',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick Lookup card (compact) ─────────────────────────────────────────

  void _runQuickLookup() {
    final q = _qlController.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    // Auto-detect EST vs. meat vs. seafood from the text itself, so the user
    // doesn't have to pick a category first. The Lookup tab shows (and lets
    // them correct) whichever segment was chosen.
    widget.onQuickLookup(LookupRouter.detect(q), q);
    _qlController.clear();
  }

  Widget _quickLookupCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FATTheme.scanGreen.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.search, size: 16, color: FATTheme.scanGreen),
                SizedBox(width: 8),
                Text('Quick Lookup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'EST number, meat brand, or seafood brand — we detect which.',
              style: TextStyle(
                  fontSize: 12.5, color: Colors.black.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qlController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runQuickLookup(),
                    decoration: InputDecoration(
                      hintText: "e.g. 969, Tyson, Gorton's",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _runQuickLookup,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: FATTheme.scanGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Look Up',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Cards & rows ────────────────────────────────────────────────────────

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

  Widget _pillarCard(String title, String body) {
    return Container(
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: FATTheme.scanGreen),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));

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

  Widget _gradeRow(String letter, String range, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: color,
            child: Text(letter,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(range,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
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
