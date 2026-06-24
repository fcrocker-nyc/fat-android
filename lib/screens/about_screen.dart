import 'package:flutter/material.dart';
import '../theme/fat_theme.dart';
import 'scoring_explanation_screen.dart';
import 'seafood_scoring_explanation_screen.dart';

/// Mirrors iOS AboutView — opened from the info button on the Home hero.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('About',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: FATTheme.scanGreen)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            // Hero (matches Home)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Image.asset('assets/images/hero.jpg',
                              fit: BoxFit.cover),
                        ),
                        const Text('ABOUT',
                            style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 3, color: Colors.black54)
                                ])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(
                color: FATTheme.primaryGreen,
                thickness: 2,
                indent: 16,
                endIndent: 16),
            const SizedBox(height: 18),
            _sectionCard('Farm Animal Transparency',
                'Farm Animal Transparency (FAT) exists to improve consumer understanding of meat and seafood labels.\n\nRather than focusing on marketing language, FAT focuses on what labels actually disclose — and what they omit.'),
            const SizedBox(height: 18),
            _howFATScoresCard(context),
            const SizedBox(height: 18),
            _sectionCard('Our Approach',
                'FAT explains transparency — not safety, quality, or morality.\n\nLack of disclosure is treated as lack of information, not wrongdoing.'),
            const SizedBox(height: 18),
            _sectionCard('What FAT Does Not Do',
                'FAT does not rate products, certify practices, or infer information that is not disclosed.\n\nFAT does not judge safety, quality, or morality. It reports transparency — and the absence of transparency — based solely on label language.'),
            const SizedBox(height: 18),
            _sectionCard('Copyright & Intellectual Property',
                '© 2026 Farm Animal Transparency. All rights reserved.\n\nThis app, its design, and its content are protected by copyright and other intellectual property laws. No part may be reproduced or distributed without permission.\n\nFAT provides informational analysis of label disclosures and does not provide legal, medical, or financial advice.'),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, String body) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 16, height: 1.35)),
        ],
      ),
    );
  }

  Widget _howFATScoresCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How FAT Scores Labels',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const Text(
            'Every meat, poultry, and seafood label is evaluated across 16 transparency categories. The 0–100 FAT Score and A–F grade are built from two equal pillars — what the label discloses, and how credible those disclosures are.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 14),
          _scoringLinkRow(
            Icons.list_alt,
            'How FAT Scores Meat Labels',
            'Meat, poultry, lamb, turkey, bison · 16 categories · A–F grade',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ScoringExplanationScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _scoringLinkRow(
            Icons.set_meal,
            'How FAT Scores Seafood Labels',
            'Wild · farmed · catfish · FDA vs FSIS fork · 16 categories · A–F grade',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const SeafoodScoringExplanationScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoringLinkRow(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
        children: [
          SizedBox(width: 28, child: Icon(icon, size: 18, color: Colors.black)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13, color: Colors.black.withAlpha(190))),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: Colors.black.withAlpha(150)),
        ],
          ),
        ),
      ),
    );
  }
}
