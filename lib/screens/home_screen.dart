import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';
import '../data/lookup_router.dart';
import 'about_screen.dart';
import 'learn_screen.dart';
import 'service_case_capture_screen.dart';
import 'how_fat_works_screen.dart';

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
                    _howFATWorksCard(context),
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
                        'Now Scanning Loose Fish',
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _pill(Icons.verified, 'Independent'),
              _divider(),
              _pill(Icons.block, 'No Ads'),
              _divider(),
              _pill(Icons.money_off, 'No Sponsors'),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'We score disclosure, not the product — nothing for a brand to buy its way out of.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FATTheme.scanGreen),
            ),
          ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FATTheme.scanGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.search, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Quick Lookup',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'EST number, meat brand, or seafood brand — we detect which.',
              style: TextStyle(
                  fontSize: 12.5, color: Colors.white.withValues(alpha: 0.92)),
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
                      filled: true,
                      fillColor: Colors.white,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Look Up',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FATTheme.scanGreen)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── How FAT works card (compact entry to the dedicated page) ────────────

  Widget _howFATWorksCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HowFATWorksScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FATTheme.primaryGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.list_alt, size: 22, color: FATTheme.scanGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('How FAT Works',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: FATTheme.scanGreen),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'What we read across 16 transparency categories, how claims are '
                'backed, and how to read a FAT card. We rate the '
                'disclosure — never the food.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
