// FAT 100 Field Study — the 100-product processed-meat target checklist.
// Companion to the "FAT Scan 100" capture form (a Claude artifact page whose
// shared study database collects the full field records). This screen is the
// in-store field guide: track which of the 100 targets have been captured,
// filter by brand/name, and jump to the capture form to record a full entry.
// Captured state is device-local (SharedPreferences), keyed by target UPC.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/fat100_targets.dart';
import '../theme/fat_theme.dart';

const String _captureFormUrl =
    'https://claude.ai/code/artifact/15cce712-5b88-4107-999b-08b538834853';

class Fat100Screen extends StatefulWidget {
  const Fat100Screen({super.key});

  @override
  State<Fat100Screen> createState() => _Fat100ScreenState();
}

class _Fat100ScreenState extends State<Fat100Screen> {
  static const _prefsKey = 'fat100_captured_upcs';
  Set<String> _captured = {};
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() =>
        _captured = (prefs.getStringList(_prefsKey) ?? const []).toSet());
  }

  Future<void> _toggle(String upc) async {
    setState(() {
      if (!_captured.remove(upc)) _captured.add(upc);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _captured.toList());
  }

  Future<void> _openCaptureForm() async {
    await launchUrl(Uri.parse(_captureFormUrl),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.toLowerCase();
    final count = fat100Targets.where((t) => _captured.contains(t.upc)).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FAT 100 Field Study',
                style: TextStyle(fontWeight: FontWeight.w800)),
            Text('$count/100',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: count / 100,
              minHeight: 6,
              backgroundColor: FATTheme.primaryGreen,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(FATTheme.scanGreen),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FATTheme.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'One hundred processed-meat targets — deli meats, sausage & '
              'bacon, nuggets & tenders — for the FAT field study of what '
              'multi-ingredient labels disclose. In the store: scan the label '
              'with the Scan tab as usual, tap a target here to mark it '
              'captured, and record the full study entry (price, UPC, '
              'ingredient statement) in the capture form. A same-brand, '
              'same-category substitute counts toward the quota.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FATTheme.scanGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _openCaptureForm,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open study capture form',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Filter by brand or name…',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
          for (final cat in fat100CategoryNames.keys) ...[
            Builder(builder: (context) {
              final items = fat100Targets
                  .where((t) =>
                      t.category == cat &&
                      (q.isEmpty ||
                          '${t.brand} ${t.name}'.toLowerCase().contains(q)))
                  .toList();
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8),
                    child: Text(
                      fat100CategoryNames[cat]!.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.black54),
                    ),
                  ),
                  for (final t in items) _targetTile(t),
                ],
              );
            }),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _targetTile(Fat100Target t) {
    final done = _captured.contains(t.upc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _toggle(t.upc),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: done
                ? FATTheme.successGreen.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: done
                    ? FATTheme.successGreen.withValues(alpha: 0.6)
                    : Colors.black12),
          ),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: done ? FATTheme.successGreen : Colors.black26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.brand,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${t.name} · ${t.tier}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black54)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: done
                      ? FATTheme.successGreen.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  done ? 'CAPTURED' : 'NEEDED',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color:
                          done ? FATTheme.successGreen : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
