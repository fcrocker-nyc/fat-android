import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onScanTap;
  const HomeScreen({super.key, required this.onScanTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // extendBodyBehindAppBar would help if we had one; instead we handle
      // the status-bar inset manually inside the hero.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero is OUTSIDE SafeArea — bleeds edge-to-edge behind the status bar
          _heroImage(context),
          // Everything below the hero respects safe-area insets
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const SizedBox(height: 16),
              _independenceBadge(),
              const SizedBox(height: 12),
              _scanCTA(),
              const SizedBox(height: 16),
              const Divider(color: FATTheme.primaryGreen, thickness: 2, indent: 16, endIndent: 16),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How FAT Scores a Label',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text(
                      'Every FAT score is the result of a three-step analysis. Each step asks a different question about the label.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _stepCard(1, 'What is disclosed?',
                        'We read the label and check which of 15+ transparency categories are addressed — species, breed, processor, feed, welfare, hormones, organic, and more. Each category is marked Disclosed, Partially disclosed, or Not disclosed.'),
                    const SizedBox(height: 10),
                    _stepCard(2, 'How credible is the disclosure?',
                        'A claim can be Third-Party Audited, USDA-Reviewed, Producer Affidavit, or Unverified Marketing. The same disclosure carries very different weight depending on which tier applies.'),
                    const SizedBox(height: 10),
                    _stepCard(3, 'Who stands behind the label?',
                        'The processor and its FSIS / FDA enforcement record (recalls, residue violations, humane-handling actions), the brand owner and corporate parent, foreign-ownership status, and economic concentration / HHI for the supply chain.'),
                    const SizedBox(height: 8),
                    Text(
                      'Same model documented at farmanimaltransparency.com/learn-how-to-read-meat-labels/.',
                      style: TextStyle(fontSize: 13, color: Colors.black.withAlpha(165), fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    _sectionHeader('How the Score Is Calculated'),
                    const SizedBox(height: 6),
                    const Text(
                      'The 0–100 FAT Score is split 70% Disclosure / 30% Credibility. Step 3 sits alongside the score as public-record context.',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    _pillarCard('Pillar 1 — Disclosure (70 pts)',
                        'Each transparency category contributes up to 5 pts when fully Known, 2 pts when Partial, 0 when Missing.'),
                    const SizedBox(height: 8),
                    _pillarCard('Pillar 2 — Credibility (30 pts)',
                        'FAT averages credibility weights: Third-Party Audited 1.0 · USDA-Reviewed 0.7 · Producer Affidavit 0.4 · Unverified Marketing 0.1.'),
                    const SizedBox(height: 8),
                    _pillarCard('Step 3 — Who Stands Behind the Label',
                        'FSIS / FDA enforcement history, brand owner, corporate parent, foreign-ownership status, and HHI. Not added to the 0–100 score.'),
                    const SizedBox(height: 16),
                    _sectionHeader('The Three Lights'),
                    const SizedBox(height: 8),
                    _lightRow(const Color(0xFF34A853), 'Green', 'Disclosed and independently verified or backed by a federal program with audit teeth.'),
                    _lightRow(const Color(0xFFFBC02D), 'Amber', 'Partially disclosed, or backed only by a producer affidavit or USDA label-language review.'),
                    _lightRow(Colors.red, 'Red', 'Not disclosed at all, or required FSIS/FDA language is missing.'),
                    const SizedBox(height: 16),
                    _sectionHeader('A–F Grade'),
                    const SizedBox(height: 8),
                    _gradeRow('A', '80–100', const Color(0xFF34A853), 'Comprehensive disclosure, strongly backed claims.'),
                    _gradeRow('B', '65–79', const Color(0xFF64B446), 'Good disclosure with solid credibility.'),
                    _gradeRow('C', '50–64', const Color(0xFFFBC02D), 'Moderate disclosure or mixed credibility.'),
                    _gradeRow('D', '35–49', const Color(0xFFEA8600), 'Limited disclosure or weakly backed claims.'),
                    _gradeRow('F', '0–34', Colors.red, 'Minimal disclosure, little or no verification.'),
                    const SizedBox(height: 12),
                    // Show more toggle
                    GestureDetector(
                      onTap: () => setState(() => _showMore = !_showMore),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showMore ? 'Show Less' : 'More About FAT',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: FATTheme.scanGreen),
                          ),
                          Icon(_showMore ? Icons.expand_less : Icons.expand_more,
                              color: FATTheme.scanGreen),
                        ],
                      ),
                    ),
                    if (_showMore) ...[
                      const SizedBox(height: 12),
                      _paragraphView(1, 'How It Works',
                          'Scan a meat, poultry, or seafood label. FAT runs the three steps and reports a 0–100 score plus an A–F grade.'),
                      const SizedBox(height: 8),
                      _paragraphView(2, 'Transparency Categories',
                          'FAT evaluates species, breed, origin, feed, grazing practices, living conditions, outdoor access, animal welfare, antibiotics, hormones, slaughter practices, and processor information.'),
                      const SizedBox(height: 8),
                      _paragraphView(3, 'Processor & Enforcement Data',
                          'When a USDA establishment number is found, FAT retrieves recalls, administrative actions, humane handling violations, residue violations, and pathogen testing results from public FSIS data.'),
                      const SizedBox(height: 8),
                      _paragraphView(4, 'Lookup',
                          'The Lookup tab lets you search by USDA establishment number, meat brand, or seafood brand to see corporate ownership, market concentration, and enforcement history.'),
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

  // ── Widgets ─────────────────────────────────────────────────────────────

  Widget _heroImage(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return SizedBox(
      width: double.infinity,
      height: 240 + statusBarHeight,
      child: Stack(
        children: [
          // Full-bleed gradient — no margin, no border radius
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FATTheme.scanGreen, Color(0xFF1B4020)],
              ),
            ),
          ),
          // "NOW Seafood, Turkey, Lamb" ribbon — positioned below status bar
          Positioned(
            top: statusBarHeight + 16,
            left: -20,
            child: Transform.rotate(
              angle: -0.61,
              child: Container(
                width: 240,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.orange,
                child: const Center(
                  child: Text('NOW Seafood, Turkey, Lamb',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ),
          ),
          // Title text — centered in the area below the status bar
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: statusBarHeight),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('The FAT App',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white,
                          shadows: [Shadow(blurRadius: 4)])),
                  Text('Farm Animal Transparency',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                          shadows: [Shadow(blurRadius: 4)])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _independenceBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: FATTheme.scanGreen.withAlpha(90)),
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
      children: [
        Icon(icon, size: 16, color: FATTheme.scanGreen),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FATTheme.scanGreen)),
      ],
    );
  }

  Widget _divider() => Container(height: 28, width: 1, color: Colors.grey.shade300);

  Widget _scanCTA() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: widget.onScanTap,
        icon: const Icon(Icons.camera_alt, size: 26),
        label: const Text('Scan Meat / Seafood Label', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: FATTheme.scanGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

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
          CircleAvatar(
            radius: 20,
            backgroundColor: FATTheme.scanGreen,
            child: Text('$number', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillarCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) =>
      Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));

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
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            child: Text(letter, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(range, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                Text(text, style: const TextStyle(fontSize: 13)),
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
          Row(children: [
            Text('$number. ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
