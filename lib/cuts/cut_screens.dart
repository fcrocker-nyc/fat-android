import 'package:flutter/material.dart';

import '../models/lookup_record.dart';
import '../services/scan_store.dart';
import '../theme/fat_theme.dart';
import 'cut_guide.dart';

/// One cut: the diagram with its section highlighted, what it is, the names it
/// goes by, and what the name doesn't tell you. Port of iOS CutDetailCard.
class CutDetailCard extends StatelessWidget {
  final CutEntry cut;
  final CutGuide guide;
  const CutDetailCard({super.key, required this.cut, required this.guide});

  @override
  Widget build(BuildContext context) {
    final species = guide.speciesFor(cut.species);
    final primal = guide.primalFor(cut);
    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1B3A57))),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 15, height: 1.35)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          label: '${species?.name ?? ''} diagram with the ${primal?.name ?? ''} section highlighted',
          child: Image.asset(cut.asset, fit: BoxFit.contain, width: double.infinity),
        ),
        const SizedBox(height: 12),
        Text('${species?.name ?? cut.species} · ${primal?.name ?? cut.primal}'.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: FATTheme.scanGreen)),
        const SizedBox(height: 4),
        Text(cut.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(cut.about, style: const TextStyle(fontSize: 16, height: 1.35)),
        if (primal != null) section('Where it comes from', '${primal.name}: ${primal.about}'),
        if (cut.otherNames.isNotEmpty) section('Also called', cut.otherNames.map(_display).join(', ')),
        section('What the name doesn’t tell you',
            [cut.nameNote, species?.nameNeverSays ?? ''].where((s) => s.isNotEmpty).join('\n\n')),
        const SizedBox(height: 12),
        Text('Source: ${cut.source}', style: const TextStyle(fontSize: 12, color: FATTheme.textSecondary)),
      ]),
    );
  }

  /// "ny strip" → "NY strip", "new york strip" → "New York strip".
  static String _display(String alias) {
    const upper = {'ny', 'kc', 'la', 'st'};
    const proper = {'new', 'york', 'kansas', 'city', 'boston', 'denver', 'santa', 'maria', 'london', 'st.', 'louis',
        'louis-style', 'iowa', 'delmonico', 'spencer', 'scotch', 'porterhouse', 'chateaubriand', 'statler', 'cornish',
        'canadian', 'english', 'brazilian', 'ibérico'};
    return alias.split(' ').map((w) {
      if (upper.contains(w)) return w.toUpperCase();
      if (proper.contains(w) && w.isNotEmpty) return w[0].toUpperCase() + w.substring(1);
      return w;
    }).join(' ');
  }
}

/// Full-screen cut page, pushed from Lookup rows and menu dishes.
class CutDetailScreen extends StatelessWidget {
  final CutEntry cut;
  final CutGuide guide;
  const CutDetailScreen({super.key, required this.cut, required this.guide});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(cut.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [CutDetailCard(cut: cut, guide: guide)]),
    );
  }
}

/// Lookup → Cut: search a cut name or browse a species. Port of iOS
/// CutLookupSection.
class CutLookupTab extends StatefulWidget {
  final TextEditingController controller;

  /// Bumped by the Home "Quick Lookup" hand-off to run the search.
  final int searchTrigger;
  const CutLookupTab({super.key, required this.controller, this.searchTrigger = 0});

  @override
  State<CutLookupTab> createState() => _CutLookupTabState();
}

class _CutLookupTabState extends State<CutLookupTab> {
  CutGuide? _guide;
  List<CutEntry> _results = const [];
  bool _searched = false;
  String? _browsing;

  @override
  void initState() {
    super.initState();
    CutGuide.load().then((g) {
      if (!mounted) return;
      setState(() => _guide = g);
      if (widget.searchTrigger > 0 && widget.controller.text.trim().isNotEmpty) _search();
    });
  }

  @override
  void didUpdateWidget(CutLookupTab old) {
    super.didUpdateWidget(old);
    if (widget.searchTrigger != old.searchTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  void _search() {
    final g = _guide;
    final q = widget.controller.text.trim();
    if (g == null || q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final results = g.search(q);
    setState(() {
      _browsing = null;
      _results = results;
      _searched = true;
    });
    final top = results.isEmpty ? null : results.first;
    ScanStore.instance.saveLookup(LookupRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}-cut',
      date: DateTime.now(),
      category: LookupCategory.cut,
      query: q,
      resultTitle: top?.name ?? 'No cut found',
      resultSubtitle: top == null ? null : '${g.speciesFor(top.species)?.name ?? ''} · ${g.primalFor(top)?.name ?? ''}',
      matchCount: results.length,
    ));
  }

  void _clear() => setState(() {
        widget.controller.clear();
        _results = const [];
        _searched = false;
        _browsing = null;
      });

  @override
  Widget build(BuildContext context) {
    final g = _guide;
    if (g == null) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    }
    final q = widget.controller.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Look up a cut of beef, pork or chicken',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('cutField'),
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. ribeye, pork butt, chicken thigh',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          if (_searched || _browsing != null)
            IconButton(onPressed: _clear, icon: const Icon(Icons.cancel, color: Colors.black26)),
        ]),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: q.isEmpty ? null : _search,
          style: ElevatedButton.styleFrom(
            backgroundColor: FATTheme.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Search', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Or browse:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
          for (final s in g.species)
            ChoiceChip(
              label: Text(s.name),
              selected: _browsing == s.key,
              onSelected: (_) => setState(() => _browsing = _browsing == s.key ? null : s.key),
              selectedColor: FATTheme.scanGreen,
              labelStyle: TextStyle(
                  fontWeight: FontWeight.w700, color: _browsing == s.key ? Colors.white : FATTheme.scanGreen),
              backgroundColor: FATTheme.scanGreen.withValues(alpha: 0.12),
              side: BorderSide.none,
              showCheckmark: false,
            ),
        ]),
        const SizedBox(height: 14),
        ..._body(g),
        const SizedBox(height: 24),
      ]),
    );
  }

  List<Widget> _body(CutGuide g) {
    final b = _browsing;
    if (b != null) {
      final s = g.speciesFor(b)!;
      return [
        Image.asset(s.asset, fit: BoxFit.contain),
        const SizedBox(height: 8),
        Text(s.nameNeverSays, style: const TextStyle(fontSize: 14, height: 1.35)),
        const SizedBox(height: 10),
        for (final c in g.cutsOf(b)) _row(g, c),
      ];
    }
    if (_searched) {
      if (_results.isEmpty) {
        return [
          Text('No cut found for “${widget.controller.text.trim()}”',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Try another name for it, or browse Beef, Pork or Chicken above. FAT covers the common cuts of those three.',
              style: TextStyle(fontSize: 14, color: Colors.black54)),
        ];
      }
      return [
        CutDetailCard(cut: _results.first, guide: g),
        if (_results.length > 1) ...[
          const SizedBox(height: 14),
          const Text('Other matches', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final c in _results.skip(1)) _row(g, c),
        ],
      ];
    }
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: FATTheme.primaryGreen.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(14)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What a cut name tells you', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('A cut name says which part of the animal the meat comes from — the rib, the shoulder, the thigh. Search a name you see on a label or a menu to see where it is on the animal and the other names it goes by.',
              style: TextStyle(fontSize: 14, height: 1.35)),
          SizedBox(height: 6),
          Text('It doesn’t say the breed, the grade, what the animal ate, or where it was raised. Those are on the label — scan it to see what it discloses.',
              style: TextStyle(fontSize: 14, height: 1.35)),
        ]),
      ),
    ];
  }

  Widget _row(CutGuide g, CutEntry c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => CutDetailScreen(cut: c, guide: g))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            SizedBox(width: 72, height: 40, child: Image.asset(c.asset, fit: BoxFit.contain)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${g.speciesFor(c.species)?.name ?? ''} · ${g.primalFor(c)?.name ?? ''}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ]),
        ),
      ),
    );
  }
}
