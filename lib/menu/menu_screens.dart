import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lost_photo_recovery.dart';
import '../theme/fat_theme.dart';
import 'menu_explainer.dart';
import 'menu_interpreter.dart';
import 'menu_models.dart';
import 'menu_ocr.dart';

const _usStates = [
  'AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY',
  'LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH',
  'OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
];

const _menuBlue = Color(0xFF2C3E50);
const _certBlue = Color(0xFF1B4F72);
const _certPaleBlue = Color(0xFFEBF5FB);

// ── Capture ─────────────────────────────────────────────────────────────────

/// Entry screen for the menu track: photograph one or more menu pages (or
/// import a screenshot of a QR-code menu), read them, and open Dishes found.
class MenuScanScreen extends StatefulWidget {
  // Menu pages recovered after Android restarted the app mid-capture
  // (LostPhotoRecovery); shown in the page strip, ready for Read Menu.
  final List<String> recoveredPhotoPaths;

  const MenuScanScreen({super.key, this.recoveredPhotoPaths = const []});

  @override
  State<MenuScanScreen> createState() => _MenuScanScreenState();
}

class _MenuScanScreenState extends State<MenuScanScreen> {
  final List<String> _pages = [];
  bool _reading = false;
  String? _error;
  String _state = '';

  @override
  void initState() {
    super.initState();
    _pages.addAll(widget.recoveredPhotoPaths);
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _state = p.getString('menuDiningState') ?? '');
    });
  }

  Future<void> _setState(String s) async {
    setState(() => _state = s);
    (await SharedPreferences.getInstance()).setString('menuDiningState', s);
  }

  Future<void> _add(ImageSource source) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final files = await picker.pickMultiImage(imageQuality: 90, limit: 6);
        if (files.isEmpty) return;
        setState(() {
          _error = null;
          _pages.addAll(files.map((f) => f.path));
        });
      } else {
        final f = await LostPhotoRecovery.pickImage(PhotoScan.menu, source: source);
        if (f == null || !mounted) return;
        setState(() {
          _error = null;
          _pages.add(f.path);
        });
      }
    } catch (e) {
      setState(() => _error = 'Couldn’t open the photo: $e');
    }
  }

  Future<void> _read() async {
    setState(() {
      _reading = true;
      _error = null;
    });
    final ocr = <MenuPage>[];
    for (var i = 0; i < _pages.length; i++) {
      try {
        ocr.add(await MenuOCR.recognize(_pages[i], i));
      } catch (_) {/* skip unreadable page */}
    }
    if (!mounted) return;
    if (ocr.isEmpty) {
      setState(() {
        _reading = false;
        _error = 'Couldn’t read any text. Try a closer, flatter photo with less glare.';
      });
      return;
    }
    final glossary = await MenuClaimExplainer.loadGlossary();
    final result = MenuInterpreter(glossary)
        .interpret(ocr, diningState: _state.isEmpty ? null : _state);
    if (!mounted) return;
    setState(() => _reading = false);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MenuDishesScreen(result: result, glossary: glossary),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Photograph the dishes you’re choosing between. FAT explains the '
              'sourcing words on the menu and gives you questions to ask your server or chef.',
              style: TextStyle(fontSize: 16, height: 1.3)),
          const SizedBox(height: 10),
          const Text('FAT doesn’t check, score, or grade restaurants. The kitchen’s '
              'answers are the disclosure.',
              style: TextStyle(fontSize: 14, color: FATTheme.textSecondary)),
          const SizedBox(height: 18),
          _bigButton(
            icon: Icons.photo_camera,
            label: _pages.isEmpty ? 'Photograph Menu' : 'Add Another Page',
            color: FATTheme.scanGreen,
            onTap: () => _add(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _add(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: FATTheme.scanGreen),
            label: const Text('Import a Screenshot (QR-code menus)',
                style: TextStyle(color: FATTheme.scanGreen, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: FATTheme.scanGreen, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_pages.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(children: [
              Text(_pages.length == 1 ? '1 page' : '${_pages.length} pages',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _pages.clear();
                  _error = null;
                }),
                child: const Text('Clear', style: TextStyle(color: FATTheme.errorRed)),
              ),
            ]),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pages.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_pages[i]), width: 90, height: 120, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _pages.removeAt(i)),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.cancel, color: Colors.white, shadows: [Shadow(blurRadius: 3)]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: FATTheme.errorBGTint, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!,
                  style: const TextStyle(
                      color: FATTheme.errorRed, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
          if (_pages.isNotEmpty) ...[
            const SizedBox(height: 18),
            _bigButton(
              icon: null,
              label: _reading ? 'Reading menu…' : 'Read Menu',
              color: _menuBlue,
              onTap: _reading ? null : _read,
              busy: _reading,
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFF2F2F0), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Text('Dining in',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              DropdownButton<String>(
                value: _state,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: FATTheme.scanGreen, fontSize: 16),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Not set')),
                  for (final s in _usStates) DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => _setState(v ?? ''),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MenuLearnScreen())),
            child: const Row(children: [
              Icon(Icons.menu_book, color: FATTheme.scanGreen, size: 16),
              SizedBox(width: 6),
              Text('What a menu can and can’t tell you',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FATTheme.scanGreen,
                      decoration: TextDecoration.underline)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bigButton({
    required IconData? icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (busy)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else if (icon != null)
            Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ── Dishes found ────────────────────────────────────────────────────────────

class MenuDishesScreen extends StatefulWidget {
  final MenuResult result;
  final MenuGlossary glossary;
  const MenuDishesScreen({super.key, required this.result, required this.glossary});

  @override
  State<MenuDishesScreen> createState() => _MenuDishesScreenState();
}

class _MenuDishesScreenState extends State<MenuDishesScreen> {
  MenuResult get r => widget.result;

  Future<void> _fixProtein(MenuItem item) async {
    final chosen = await showModalBottomSheet<List<ProteinFamily>>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProteinEditor(item: item),
    );
    if (chosen == null) return;
    setState(() {
      item.proteins = chosen;
      MenuInterpreter(widget.glossary).reinterpret(item, r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = r.visibleItems;
    final withClaims = items.where((i) => i.claims.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Dishes found')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            '${items.length} ${items.length == 1 ? 'dish' : 'dishes'} with meat or seafood · '
            '$withClaims with a sourcing claim',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
              'Tap a dish to see what its sourcing words mean and what to ask. '
              'Swipe to remove anything that isn’t a dish; long-press to fix the protein.',
              style: TextStyle(fontSize: 13, color: FATTheme.textSecondary)),
          if (r.layoutUncertain) ...[
            const SizedBox(height: 10),
            const Row(children: [
              Icon(Icons.warning_amber, color: FATTheme.fatOrange, size: 18),
              SizedBox(width: 6),
              Expanded(
                  child: Text('Layout uncertain — columns may have run together. Check dish names below.',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: FATTheme.fatOrange))),
            ]),
          ],
          if (r.headerStatements.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('From the menu’s header',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: FATTheme.textSecondary)),
            for (final s in r.headerStatements)
              Text('“$s”', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
                'No meat, poultry or seafood dishes found. Try a closer photo of the section you’re ordering from.',
                style: TextStyle(fontSize: 14, color: FATTheme.textSecondary)),
          for (final item in items)
            Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: FATTheme.errorRed,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Text('Not a dish',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              onDismissed: (_) => setState(() => item.dismissed = true),
              child: InkWell(
                onLongPress: () => _fixProtein(item),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MenuDishScreen(
                      item: item, glossary: widget.glossary, diningState: r.diningState),
                )),
                child: _DishRow(item: item),
              ),
            ),
          const SizedBox(height: 16),
          Text('Glossary ${r.glossaryVersion}',
              style: const TextStyle(fontSize: 12, color: FATTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  final MenuItem item;
  const _DishRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE6E6E4)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.dishName,
                maxLines: 2,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (item.description.isNotEmpty)
              Text(item.description,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: FATTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in item.proteins) _Chip(p.displayName, _ChipStyle.protein),
              if (item.proteins.isEmpty) const _Chip('protein unknown', _ChipStyle.muted),
              if (item.minorProteinOnly) const _Chip('minor ingredient', _ChipStyle.muted),
              for (final c in item.claims)
                _Chip(c.matchedText.toLowerCase(),
                    c.inheritedFromHeader ? _ChipStyle.inherited : _ChipStyle.claim),
              if (item.claims.isEmpty) const _Chip('no sourcing claim', _ChipStyle.muted),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right, color: FATTheme.textSecondary),
      ]),
    );
  }
}

enum _ChipStyle { protein, claim, inherited, muted }

class _Chip extends StatelessWidget {
  final String text;
  final _ChipStyle style;
  const _Chip(this.text, this.style);

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (style) {
      _ChipStyle.protein => (Colors.white, FATTheme.scanGreen),
      _ChipStyle.claim => (_certBlue, _certPaleBlue),
      _ChipStyle.inherited => (_certBlue, _certPaleBlue.withValues(alpha: 0.5)),
      _ChipStyle.muted => (FATTheme.textSecondary, const Color(0xFFE6E6E4)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _ProteinEditor extends StatefulWidget {
  final MenuItem item;
  const _ProteinEditor({required this.item});

  @override
  State<_ProteinEditor> createState() => _ProteinEditorState();
}

class _ProteinEditorState extends State<_ProteinEditor> {
  late final Set<ProteinFamily> _sel = widget.item.proteins.toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.item.dishName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('What’s in this dish?', style: TextStyle(color: FATTheme.textSecondary)),
          for (final p in ProteinFamily.values)
            SwitchListTile(
              dense: true,
              activeThumbColor: FATTheme.scanGreen,
              title: Text(p.displayName),
              value: _sel.contains(p),
              onChanged: (on) => setState(() => on ? _sel.add(p) : _sel.remove(p)),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FATTheme.scanGreen),
            onPressed: () => Navigator.pop(
                context, ProteinFamily.values.where(_sel.contains).toList()),
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}

// ── Dish detail: claim cards ────────────────────────────────────────────────

class MenuDishScreen extends StatelessWidget {
  final MenuItem item;
  final MenuGlossary glossary;
  final String? diningState;
  const MenuDishScreen({super.key, required this.item, required this.glossary, required this.diningState});

  @override
  Widget build(BuildContext context) {
    final cards = MenuClaimExplainer.cards(item, glossary, diningState);
    return Scaffold(
      appBar: AppBar(title: const Text('Dish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item.dishName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          if (item.description.isNotEmpty)
            Text(item.description,
                style: const TextStyle(fontSize: 15, color: FATTheme.textSecondary)),
          if (item.section != null)
            Text(item.section!.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: FATTheme.textSecondary)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => MenuQuestionSheet(
                  item: item, questions: MenuClaimExplainer.topQuestions(item, glossary)),
            )),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: FATTheme.scanGreen, borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.forum, color: Colors.white),
                SizedBox(width: 10),
                Text('Questions for the table',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          for (final c in cards) _ClaimCardView(card: c),
        ],
      ),
    );
  }
}

class _ClaimCardView extends StatelessWidget {
  final MenuClaimCard card;
  const _ClaimCardView({required this.card});

  Widget _part(String heading, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF505050))),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(fontSize: 15, height: 1.3, color: Color(0xFF555555))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8C8C8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(card.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: _certBlue))),
          if (card.entry != null)
            Text(card.entry!.family.displayName,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: FATTheme.textSecondary)),
        ]),
        if (card.inheritedFromHeader) ...[
          const SizedBox(height: 4),
          const Text('From the menu’s header',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E86C1))),
        ],
        const SizedBox(height: 12),
        _part('What it means', card.meaning),
        const SizedBox(height: 4),
        Text(card.authority ?? 'No legal definition',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: FATTheme.textSecondary)),
        const SizedBox(height: 12),
        _part('What it doesn’t tell you', card.gap),
        if (card.stateNote != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF5E7), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.place, size: 16, color: _menuBlue),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(card.stateNote!,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _menuBlue))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Ask',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: FATTheme.scanGreen)),
        for (final q in card.questions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.help, size: 18, color: FATTheme.scanGreen),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(q,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MenuLearnScreen())),
          child: const Text('What a menu can and can’t tell you',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FATTheme.scanGreen,
                  decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }
}

// ── Question sheet ──────────────────────────────────────────────────────────

/// Large-type sheet the diner can read from or hand across the table.
class MenuQuestionSheet extends StatelessWidget {
  final MenuItem item;
  final List<String> questions;
  const MenuQuestionSheet({super.key, required this.item, required this.questions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Questions'),
        actions: [
          IconButton(
            tooltip: 'Share questions',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Share.share(MenuClaimExplainer.shareText(item, questions)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(item.dishName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: FATTheme.textSecondary)),
          const SizedBox(height: 24),
          for (var i = 0; i < questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 36,
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900, color: FATTheme.scanGreen)),
                ),
                Expanded(
                    child: Text(questions[i],
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15))),
              ]),
            ),
          const Text('Thank you — we like knowing where our food comes from.',
              style: TextStyle(
                  fontSize: 18, fontStyle: FontStyle.italic, color: FATTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── Learn article ───────────────────────────────────────────────────────────

class MenuLearnScreen extends StatelessWidget {
  const MenuLearnScreen({super.key});

  static const _sections = <(String, String)>[
    ('Why FAT explains instead of checking',
        'Nothing on a menu can be checked at the table. The USDA inspection mark and establishment number are on the wholesale case in the kitchen, not on your plate. Country-of-origin labeling (COOL) exempts restaurants. The USDA’s rules for claims like “grass-fed” or “raised without antibiotics” cover product labels, not menu copy. And words like “local,” “Wagyu” and “heritage” have no federal definition at all.'),
    ('So the question is the tool',
        'If you know that “grass-fed” doesn’t say whether the animal was finished on grain, or that “Gulf shrimp” names a body of water rather than a country, you can ask a better question. The kitchen’s answer is the disclosure. FAT supplies the words and the questions; the restaurant supplies the facts.'),
    ('What a menu usually leaves out',
        'Species (which snapper?), origin (which country?), method (wild or farmed, and how caught?), the supplier, and whether a certification belongs to the supplier or the restaurant. A 2026 FAT review of 67 Michelin-starred restaurants found that none of their published menus named a boat, cited a seafood certification, or said whether their caviar was wild or farmed.'),
    ('Where the law does reach menus',
        'Some Gulf states — Alabama, Louisiana, Mississippi and Texas — now require restaurants to say when shrimp or other seafood is imported. Set your dining state on the Menu screen and FAT will mention it on the cards where it applies.'),
    ('How to ask',
        'Start friendly: “What can you tell me about the fish?” (a Seafood Watch suggestion). Most servers will check with the kitchen, and many chefs are glad to talk about their suppliers. Asking to see a case label or invoice is an invitation, not a demand — many kitchens are happy to show you.'),
    ('What FAT doesn’t do here',
        'FAT doesn’t score, grade or verify restaurants, and it never suggests a claim is false. It explains what a claim says and what it leaves unsaid.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('What a menu can and can’t tell you',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          for (final (h, b) in _sections) ...[
            Text(h, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _menuBlue)),
            const SizedBox(height: 6),
            Text(b, style: const TextStyle(fontSize: 16, height: 1.35, color: Color(0xFF555555))),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
