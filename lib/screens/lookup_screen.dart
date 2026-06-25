import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../theme/fat_theme.dart';
import '../data/meat_brand_database.dart';
import '../data/seafood_brand_database.dart';
import '../data/pork_owner_database.dart';
import '../data/seafood_enforcement_database.dart';

/// A lookup request handed from the Home "Quick Lookup" card to the Lookup tab.
class LookupRequest {
  final int tab; // 0=EST, 1=Meat Brand, 2=Seafood Brand
  final String query;
  const LookupRequest(this.tab, this.query);
}

class LookupScreen extends StatefulWidget {
  /// Optional cross-tab request from the Home screen. When set, the Lookup tab
  /// adopts the tab + query, runs the search, then calls [onConsumed].
  final LookupRequest? pending;
  final VoidCallback? onConsumed;
  const LookupScreen({super.key, this.pending, this.onConsumed});

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  int _selectedTab = 0; // 0=EST, 1=Meat Brand, 2=Seafood Brand
  final _estController = TextEditingController();
  final _meatController = TextEditingController();
  final _seafoodController = TextEditingController();

  bool _isLoading = false;

  // EST
  Map<String, dynamic>? _processorData;
  PorkOwnerResult? _porkOwner;
  bool _estSearched = false;
  bool _lookupFailed = false;

  // Brand searches
  List<MeatBrandResult>? _meatResults;
  List<SeafoodBrandResult>? _seafoodResults;

  // Seafood FDA enforcement
  final _enforcementController = TextEditingController();
  List<SeafoodEnforcementEntity>? _enforcementResults;

  static const _tabs = ['EST', 'Meat Brand', 'Seafood Brand', 'Seafood FDA'];

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _lookupEst() async {
    final est = _estController.text.trim().replaceAll(
        RegExp(r'^est\.?\s*', caseSensitive: false), '');
    if (est.isEmpty) return;
    setState(() {
      _isLoading = true;
      _processorData = null;
      _porkOwner = null;
      _estSearched = true;
      _lookupFailed = false;
    });
    try {
      final uri = Uri.parse(
        'https://farmanimaltransparency.com/wp-content/plugins/fat-fsis-data-manager/fat-fsis-data.php?est=$est',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('establishmentName')) {
          _processorData = Map<String, dynamic>.from(data);
        } else {
          _lookupFailed = true;
        }
      } else {
        _lookupFailed = true;
      }
    } catch (_) {
      _lookupFailed = true;
    } finally {
      _porkOwner =
          PorkOwnerDatabase.detectOwnerAnySpeciesForEstablishment(est);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _searchMeat() {
    FocusScope.of(context).unfocus();
    setState(() => _meatResults = MeatBrandDatabase.search(_meatController.text));
  }

  void _searchSeafood() {
    FocusScope.of(context).unfocus();
    setState(() =>
        _seafoodResults = SeafoodBrandDatabase.search(_seafoodController.text));
  }

  void _searchEnforcement() {
    FocusScope.of(context).unfocus();
    setState(() => _enforcementResults =
        SeafoodEnforcementDatabase.search(_enforcementController.text));
  }

  @override
  void initState() {
    super.initState();
    if (widget.pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
    }
  }

  @override
  void didUpdateWidget(LookupScreen old) {
    super.didUpdateWidget(old);
    if (widget.pending != null && !identical(widget.pending, old.pending)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
    }
  }

  /// Adopt a Home "Quick Lookup" request: switch tab, fill the field, run it.
  void _consumePending() {
    final req = widget.pending;
    if (req == null || !mounted) return;
    final q = req.query.trim();
    setState(() => _selectedTab = req.tab);
    switch (req.tab) {
      case 1:
        _meatController.text = q;
        if (q.isNotEmpty) _searchMeat();
        break;
      case 2:
        _seafoodController.text = q;
        if (q.isNotEmpty) _searchSeafood();
        break;
      default:
        _estController.text = q;
        if (q.isNotEmpty) _lookupEst();
    }
    widget.onConsumed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          SliverToBoxAdapter(child: _topRule()),
          SliverToBoxAdapter(child: _segmentedControl()),
          SliverToBoxAdapter(child: _tabContent()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────
  Widget _hero() {
    return SafeArea(
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
                    child:
                        Image.asset('assets/images/hero.jpg', fit: BoxFit.cover)),
                const Text('LOOKUP',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRule() => Container(
      height: 2,
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      color: FATTheme.primaryGreen);

  Widget _segmentedControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == _selectedTab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 3)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(_tabs[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.black : Colors.black54)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _tabContent() {
    switch (_selectedTab) {
      case 1:
        return _meatTab();
      case 2:
        return _seafoodTab();
      case 3:
        return _seafoodFdaTab();
      default:
        return _estTab();
    }
  }

  // ── EST tab ───────────────────────────────────────────────────────────
  Widget _estTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter USDA Establishment Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _searchField(_estController, 'e.g. 969',
              keyboard: TextInputType.number, onSubmit: _lookupEst),
          const SizedBox(height: 14),
          _actionButton('Look Up', _isLoading ? null : _lookupEst),
          const SizedBox(height: 20),
          if (_estSearched && _processorData != null)
            _processorCard(_processorData!),
          if (_porkOwner != null) ...[
            const SizedBox(height: 14),
            _porkOwnerCard(_porkOwner!),
          ],
          if (_estSearched && _lookupFailed && _processorData == null)
            _estFailureCard(),
          if (!_estSearched) _estInfoSection(),
        ],
      ),
    );
  }

  // ── Meat tab ──────────────────────────────────────────────────────────
  Widget _meatTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Search Meat Brand or Company',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _searchField(_meatController, 'e.g. Tyson, Smithfield, Perdue',
              onSubmit: _searchMeat),
          const SizedBox(height: 14),
          _actionButton('Search', _searchMeat),
          const SizedBox(height: 20),
          if (_meatResults != null) ...[
            if (_meatResults!.isEmpty)
              _notFoundCard('Brand Not Found',
                  'No results for "${_meatController.text}". Try searching by parent company, subsidiary brand, or processor name.')
            else
              for (final b in _meatResults!) ...[
                _meatBrandCard(b),
                const SizedBox(height: 14),
              ],
          ] else
            _meatInfoSection(),
        ],
      ),
    );
  }

  // ── Seafood tab ───────────────────────────────────────────────────────
  Widget _seafoodTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Search Seafood Brand',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _searchField(_seafoodController, "e.g. Gorton's, SeaPak, StarKist",
              onSubmit: _searchSeafood),
          const SizedBox(height: 14),
          _actionButton('Search', _searchSeafood),
          const SizedBox(height: 20),
          if (_seafoodResults != null) ...[
            if (_seafoodResults!.isEmpty)
              _notFoundCard('Brand Not Found',
                  'No results for "${_seafoodController.text}". This brand may not be in our database yet. Try searching by parent company name or a different spelling.')
            else
              for (final b in _seafoodResults!) ...[
                _seafoodBrandCard(b),
                const SizedBox(height: 14),
              ],
          ] else
            _seafoodInfoSection(),
        ],
      ),
    );
  }

  // ── Seafood FDA enforcement tab ───────────────────────────────────────
  Widget _seafoodFdaTab() {
    final results = _enforcementResults;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Search FDA Seafood Enforcement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _searchField(_enforcementController,
              'Entity, country, product, or alert #',
              onSubmit: _searchEnforcement),
          const SizedBox(height: 14),
          _actionButton('Search', _searchEnforcement),
          const SizedBox(height: 20),
          if (results != null) ...[
            if (results.isEmpty)
              _notFoundCard('No Match in the Public Record',
                  'No FDA seafood enforcement entity matched "${_enforcementController.text}". This registry covers public 2023–2025 warning letters, import alerts, and refusals tracked by FAT. Absence here does not mean a firm is clean — the FDA public record is incomplete, especially for foreign firms.')
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 2),
                child: Text(
                    '${results.length} ${results.length == 1 ? 'entity' : 'entities'} in the public FDA record',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.6))),
              ),
              for (final e in results) ...[
                _enforcementCard(e),
                const SizedBox(height: 14),
              ],
            ],
          ] else
            _seafoodFdaInfoSection(),
        ],
      ),
    );
  }

  Widget _enforcementCard(SeafoodEnforcementEntity e) {
    final stage = e.publicLifecycle ?? e.visibleStage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8C8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.entity,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.public,
                  size: 14, color: Colors.black.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(e.country.isEmpty ? 'United States (domestic)' : e.country,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              if (e.hasImportAlert) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFC83C3C),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('IMPORT ALERT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ],
            ],
          ),
          if (stage != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_circle_right,
                    size: 14, color: FATTheme.primaryGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(stage,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
          _cardDivider(),
          if (e.firstWarningDate != null)
            _enfRow('FDA warning letter',
                '${e.firstWarningDate}${e.warningYear != null ? ' (${e.warningYear})' : ''}'),
          if (e.warningIssue != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(e.warningIssue!,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.6))),
            ),
          if (e.firstFollowupType != null && e.firstFollowupDate != null)
            _enfRow('First visible follow-up',
                '${e.firstFollowupType} — ${e.firstFollowupDate}'),
          if (e.latestActionType != null && e.latestActionDate != null)
            _enfRow('Latest public action',
                '${e.latestActionType} — ${e.latestActionDate}'),
          if (e.hasImportAlert) ...[
            _cardDivider(),
            if (e.importAlertNumber != null && e.importAlertDate != null)
              _enfRow('Import Alert',
                  '${e.importAlertNumber} — ${e.importAlertDate}'),
            if (e.importAlertProduct != null)
              _enfRow('Product focus', e.importAlertProduct!),
            if (e.hazardPrimary != null)
              _enfRow('Primary hazard', e.hazardPrimary!),
            if (e.laterRefusalDate != null)
              _enfRow('Later import refusal', e.laterRefusalDate!),
            if (e.lifecycleBucket != null)
              _enfRow('Lifecycle speed', e.lifecycleBucket!),
          ],
          if (e.noaaImportValueUSD != null)
            _enfRow('NOAA 2024 edible import value',
                _formatUsd(e.noaaImportValueUSD!)),
          const SizedBox(height: 8),
          Text(
              'Public FDA record only. Absence of further action is not equivalent to a clean record. This is entity-level enforcement, not a verdict on any specific consumer brand.',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black.withValues(alpha: 0.55))),
          if (e.warningSourceURL != null) ...[
            const SizedBox(height: 10),
            _sourceLink('FDA warning letter', e.warningSourceURL!),
          ],
          if (e.hasImportAlert && e.alertSourceURL != null) ...[
            const SizedBox(height: 8),
            _sourceLink('FDA import alert', e.alertSourceURL!),
          ],
        ],
      ),
    );
  }

  Widget _enfRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withValues(alpha: 0.6))),
            const SizedBox(height: 1),
            Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _sourceLink(String label, String url) => GestureDetector(
        onTap: () => _openUrl(url),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.public, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
        ]),
      );

  String _formatUsd(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '\$$b';
  }

  Widget _seafoodFdaInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About Seafood FDA Enforcement',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text(
            'Roughly 80% of the seafood Americans eat is imported, and the public enforcement record is organized by regulated firm — not by the brand on the package. This registry surfaces FDA-visible seafood enforcement entities from the 2023–2025 public record: warning letters, import alerts, and import refusals, with their lifecycle timing and NOAA trade context.',
            style: TextStyle(fontSize: 16, height: 1.3)),
        const SizedBox(height: 16),
        _iconInfoBox('What you can find:', const [
          (Icons.description, 'FDA warning letters and the issue cited'),
          (Icons.report, 'Import alerts and import refusals'),
          (Icons.schedule, 'Lifecycle timing: warning → alert → refusal'),
          (Icons.public, 'Country and NOAA edible-import value'),
          (Icons.link, 'Direct links to the FDA source pages'),
        ]),
        const SizedBox(height: 14),
        Text(
            'Source: FAT FDA Seafood Reporting Package v2 (June 17, 2026), built from FDA warning letters, import alerts, and NOAA Foreign Fishery Trade Data. The public record is incomplete, especially for foreign firms; this is enforcement context, not a verdict on any consumer brand.',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.black.withValues(alpha: 0.6))),
      ],
    );
  }

  // ── Shared input widgets ──────────────────────────────────────────────
  Widget _searchField(TextEditingController c, String hint,
      {TextInputType? keyboard, VoidCallback? onSubmit}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: keyboard == TextInputType.number
          ? TextCapitalization.none
          : TextCapitalization.words,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFC8C8C8))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFC8C8C8))),
      ),
      onSubmitted: (_) => onSubmit?.call(),
    );
  }

  Widget _actionButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FATTheme.primaryGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
        ),
      ),
    );
  }

  // ── EST processor card ────────────────────────────────────────────────
  Widget _processorCard(Map<String, dynamic> data) {
    final name = data['establishmentName'] as String? ?? 'Unknown';
    final address = data['fullAddress'] as String? ?? '';
    final est = _estController.text.trim();
    return _greenCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20)),
            child: Text('USDA EST. $est',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 12),
            _iconLine(Icons.location_on, address),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openUrl(
                'https://farmanimaltransparency.com/processor-lookup/?est=$est'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public, size: 16, color: Colors.blue),
                SizedBox(width: 6),
                Text('View Full Profile',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _porkOwnerCard(PorkOwnerResult r) {
    final o = r.owner;
    return _greenCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Corporate Owner',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text('${o.flag} ${o.name}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('${o.country} · ${o.marketSharePct.toStringAsFixed(0)}% market share'
              '${o.isTop3 ? ' · Top 3' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(o.note, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _estFailureCard() {
    final est = _estController.text.trim();
    return _greenCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Establishment Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(
              'No data found for EST. $est. This establishment may not be in our database yet, or the number may be incorrect.',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openUrl(
                'https://farmanimaltransparency.com/processor-lookup/?est=$est'),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.public, size: 16, color: Colors.blue),
              SizedBox(width: 6),
              Text('Search on FAT Website',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Meat brand card ───────────────────────────────────────────────────
  Widget _meatBrandCard(MeatBrandResult b) {
    final locations = b.keyPlantLocations.take(8).toList();
    final extra = b.keyPlantLocations.length - locations.length;
    return _greenCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.brandName,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '${b.parentCountry}  ',
                style: const TextStyle(fontSize: 16)),
            TextSpan(
                text: b.corporateParent,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ])),
          if (b.isForeignOwned) ...[
            const SizedBox(height: 8),
            _foreignWarning(b.parentCountry),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in b.species) _speciesTag(s)],
          ),
          _cardDivider(),
          Text(b.marketPosition,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.apartment, size: 14, color: FATTheme.scanGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Facilities: ${b.plantCount}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.65))),
            ),
          ]),
          const SizedBox(height: 4),
          for (final loc in locations)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text('• $loc',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text('+ $extra more locations',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.55))),
            ),
          if (b.relatedBrands.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.sell, size: 14, color: FATTheme.scanGreen),
              const SizedBox(width: 6),
              Text('Related Brands',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.65))),
            ]),
            const SizedBox(height: 2),
            Text(b.relatedBrands.join(', '),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          _cardDivider(),
          Text(b.ownershipNotes,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.7))),
          if (b.regulatoryNotes != null) ...[
            const SizedBox(height: 10),
            _regulatoryBox(b.regulatoryNotes!),
          ],
        ],
      ),
    );
  }

  // ── Seafood brand card ────────────────────────────────────────────────
  Widget _seafoodBrandCard(SeafoodBrandResult b) {
    return _greenCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.brandName,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '${b.parentCountry}  ',
                style: const TextStyle(fontSize: 16)),
            TextSpan(
                text: b.corporateParent,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ])),
          if (b.isForeignOwned) ...[
            const SizedBox(height: 8),
            _foreignWarning(b.parentCountry),
          ],
          _cardDivider(),
          if (b.certifications.isEmpty)
            Row(children: [
              Icon(Icons.info_outline,
                  size: 14, color: Colors.black.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'No third-party sustainability certifications identified',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.6))),
              ),
            ])
          else ...[
            _label('Certifications'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in b.certifications) _certTag(c),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _label('Primary Species'),
          const SizedBox(height: 2),
          Text(b.primarySpecies.join(', '),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (b.plantLocations.isNotEmpty) ...[
            const SizedBox(height: 10),
            _iconLabel(Icons.apartment, 'Processing Plants'),
            for (final p in b.plantLocations)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 2),
                child: Text('• $p',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ],
          if (b.fleetInfo != null) ...[
            const SizedBox(height: 10),
            _iconLabel(Icons.directions_boat, 'Fleet / Vessels'),
            const SizedBox(height: 2),
            Text(b.fleetInfo!,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          if (b.sourcingRegions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _iconLabel(Icons.public, 'Sourcing Regions'),
            const SizedBox(height: 2),
            Text(b.sourcingRegions.join(' • '),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          if (b.farmSourcing != null) ...[
            const SizedBox(height: 10),
            _iconLabel(Icons.eco, 'Aquaculture / Farm Sourcing'),
            const SizedBox(height: 2),
            Text(b.farmSourcing!,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          _cardDivider(),
          _label('Sourcing Overview'),
          const SizedBox(height: 2),
          Text(b.sourcingNotes,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(b.ownershipNotes,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.7))),
          if (b.regulatoryNotes != null) ...[
            const SizedBox(height: 10),
            _regulatoryBox(b.regulatoryNotes!),
          ],
          if (b.fdaEnforcementURL != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openUrl(b.fdaEnforcementURL!),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.public, size: 16, color: Colors.blue),
                SizedBox(width: 6),
                Text('View FDA Enforcement History',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Info sections ─────────────────────────────────────────────────────
  Widget _estInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About USDA Establishment Numbers',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        const Text(
            'Many meat and poultry labels include a USDA establishment number, often shown as "EST. ####" near the inspection legend.',
            style: TextStyle(fontSize: 16, height: 1.3)),
        const SizedBox(height: 14),
        const Text(
            "This number identifies the federally inspected facility where the product was processed, as listed by the U.S. Department of Agriculture's Food Safety and Inspection Service (FSIS).",
            style: TextStyle(fontSize: 16, height: 1.3)),
        const SizedBox(height: 16),
        _infoBox('What you can find:', const [
          'Processor name and location',
          'Processing activities and size',
          'Administrative actions and violations',
          'Recall history',
          'Pathogen testing results',
        ]),
      ],
    );
  }

  Widget _meatInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About Meat Brand Lookup',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text(
            'Search by brand name or parent company to see corporate ownership, market position, processing plant locations, related brands, and regulatory history for major US meat companies.',
            style: TextStyle(fontSize: 16, height: 1.3)),
        const SizedBox(height: 16),
        _iconInfoBox('What you can find:', const [
          (Icons.apartment, 'Corporate parent and ownership'),
          (Icons.public, 'Foreign vs. domestic ownership'),
          (Icons.place, 'Processing plant locations'),
          (Icons.sell, 'Related brands and subsidiaries'),
          (Icons.bar_chart, 'Market position and concentration'),
          (Icons.warning_amber, 'Regulatory and legal history'),
        ]),
        const SizedBox(height: 14),
        Text(
            'Four companies (Tyson, JBS, Cargill, National Beef) control approximately 85% of US beef processing. Two of the four — JBS (Brazil) and National Beef (Brazil via Marfrig) — are foreign-owned.',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.black.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _seafoodInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About Seafood Brand Lookup',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text(
            'Unlike meat and poultry, most retail seafood packaging does not include a federal establishment number. FDA facility registration numbers are internal administrative records and do not appear on consumer labels.',
            style: TextStyle(fontSize: 16, height: 1.3)),
        const SizedBox(height: 12),
        const Text(
            'Search by brand name to find corporate ownership, sourcing information, and sustainability certifications for major US retail seafood brands.',
            style: TextStyle(fontSize: 16, height: 1.3)),
        const SizedBox(height: 16),
        _iconInfoBox('What you can find:', const [
          (Icons.apartment, 'Corporate parent company'),
          (Icons.public, 'Foreign vs. domestic ownership'),
          (Icons.verified, 'Sustainability certifications (MSC, ASC, BAP)'),
          (Icons.set_meal, 'Primary species sold'),
          (Icons.inventory_2, 'Sourcing regions and methods'),
        ]),
        const SizedBox(height: 14),
        Text(
            'This database covers major US retail seafood brands. FAT does not rate, endorse, or certify any brand or product.',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.black.withValues(alpha: 0.6))),
      ],
    );
  }

  // ── Small building blocks ─────────────────────────────────────────────
  Widget _greenCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: FATTheme.primaryGreen,
            borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _cardDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(height: 1, color: Colors.black.withValues(alpha: 0.12)),
      );

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black.withValues(alpha: 0.65)));

  Widget _iconLabel(IconData icon, String t) => Row(children: [
        Icon(icon, size: 13, color: FATTheme.scanGreen),
        const SizedBox(width: 6),
        Text(t,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black.withValues(alpha: 0.65))),
      ]);

  Widget _iconLine(IconData icon, String t) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: FATTheme.scanGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      );

  Widget _speciesTag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: FATTheme.scanGreen, borderRadius: BorderRadius.circular(20)),
        child: Text(s,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _certTag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.blue, borderRadius: BorderRadius.circular(20)),
        child: Text(s,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _foreignWarning(String country) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                'Foreign-owned: this US brand is ultimately owned by a company headquartered in $country.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.7))),
          ),
        ],
      );

  Widget _regulatoryBox(String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.7))),
            ),
          ],
        ),
      );

  Widget _notFoundCard(String title, String body) => _greenCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.search, color: Colors.orange),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 16)),
          ],
        ),
      );

  Widget _infoBox(String title, List<String> items) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: FATTheme.primaryGreen,
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(it,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      );

  Widget _iconInfoBox(String title, List<(IconData, String)> items) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: FATTheme.primaryGreen,
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(it.$1, size: 18, color: Colors.black),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(it.$2,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600))),
                ]),
              ),
          ],
        ),
      );

  @override
  void dispose() {
    _estController.dispose();
    _meatController.dispose();
    _seafoodController.dispose();
    _enforcementController.dispose();
    super.dispose();
  }
}
