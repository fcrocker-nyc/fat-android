import 'package:flutter/material.dart';
import '../models/fat_models.dart';
import '../services/scan_store.dart';
import '../theme/fat_theme.dart';
import 'results_screen.dart';

/// Product-type dimension for the History filter sheet — mirrors iOS
/// HistoryFilter.ProductTypeFilter (all / meat / seafood / siluriformes).
enum _ProductTypeFilter {
  all,
  meat,
  seafood,
  siluriformes; // catfish / FSIS-regulated seafood

  String get displayName {
    switch (this) {
      case _ProductTypeFilter.all:          return 'All';
      case _ProductTypeFilter.meat:         return 'Meat';
      case _ProductTypeFilter.seafood:      return 'Seafood';
      case _ProductTypeFilter.siluriformes: return 'Siluriformes';
    }
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<FATResult> _results = [];
  bool _loading = true;
  String _search = '';

  // ── Filter state (mirrors iOS HistoryFilter) ──
  _ProductTypeFilter _typeFilter = _ProductTypeFilter.all;
  DateTime? _dateFrom; // start-of-day, filters r.scannedAt >= this
  DateTime? _dateTo;   // end-of-day, filters r.scannedAt <= this
  bool _enforcementOnly = false;

  final _searchController = TextEditingController();

  /// Active-filter count for the badge on the header filter button — mirrors
  /// iOS HistoryFilter.activeCount. Search is a separate inline field, so the
  /// badge counts only the sheet-driven dimensions (date / type / enforcement).
  int get _activeFilterCount {
    var n = 0;
    if (_dateFrom != null || _dateTo != null) n++;
    if (_typeFilter != _ProductTypeFilter.all) n++;
    if (_enforcementOnly) n++;
    return n;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await ScanStore.instance.loadAll();
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  List<FATResult> get _filtered {
    final needle = _search.trim().toLowerCase();
    return _results.where((r) {
      // Product type (Siluriformes = seafood && isSiluriformes).
      switch (_typeFilter) {
        case _ProductTypeFilter.all:
          break;
        case _ProductTypeFilter.meat:
          if (r.productType != ProductType.meat) return false;
          break;
        case _ProductTypeFilter.seafood:
          if (r.productType != ProductType.seafood) return false;
          break;
        case _ProductTypeFilter.siluriformes:
          if (!(r.productType == ProductType.seafood && r.isSiluriformes)) {
            return false;
          }
          break;
      }
      // Date range on scannedAt.
      if (_dateFrom != null && r.scannedAt.isBefore(_dateFrom!)) return false;
      if (_dateTo != null && r.scannedAt.isAfter(_dateTo!)) return false;
      // Enforcement-only: show only records where regulatory language was NOT
      // detected (!regulatoryPassed). This is the closest available proxy for
      // iOS's HistoryEnforcement.isFlagged — Android has no processor-enforcement
      // data on saved scans.
      if (_enforcementOnly && r.regulatoryPassed) return false;
      // Free-text search over EST # / scanned text.
      if (needle.isEmpty) return true;
      final est = (r.detectedEstablishmentNumber ?? '').toLowerCase();
      final text = r.scannedText.toLowerCase();
      return est.contains(needle) || text.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: FATTheme.scanGreen))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerRow(),
                  _searchBar(),
                  const SizedBox(height: 10),
                  if (_results.isNotEmpty) ...[
                    _aggregateCard(),
                    const SizedBox(height: 4),
                  ],
                  Expanded(child: _list()),
                ],
              ),
      ),
    );
  }

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Text('History',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (_results.isNotEmpty) ...[
            _filterButton(),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _confirmClear,
              child: const Text('Clear All',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  // Filter icon with an active-count badge — opens the filter sheet (mirrors
  // iOS HistoryView's toolbar filter button + HistoryFilter.activeCount badge).
  Widget _filterButton() {
    final count = _activeFilterCount;
    return GestureDetector(
      onTap: _openFilterSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            count > 0 ? Icons.filter_list : Icons.filter_list_outlined,
            size: 28,
            color: count > 0 ? FATTheme.scanGreen : Colors.black87,
          ),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                  color: FATTheme.scanGreen,
                  shape: BoxShape.circle,
                ),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.black54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search EST # or brand',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_search.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                child: const Icon(Icons.cancel,
                    color: Colors.black38, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── Filter sheet (mirrors iOS HistoryFilterSheet) ──
  // Product type, date range, and enforcement-only toggle, plus Clear-all.
  // Edits are staged locally and committed to the screen state on "Apply".
  Future<void> _openFilterSheet() async {
    var type = _typeFilter;
    var from = _dateFrom;
    var to = _dateTo;
    var enforcementOnly = _enforcementOnly;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            String dateLabel(DateTime? d) => d == null
                ? 'Any'
                : '${_months[d.month - 1]} ${d.day}, ${d.year}';

            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: from ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setSheet(() {
                  // Start-of-day so the whole picked day is included.
                  from = DateTime(picked.year, picked.month, picked.day);
                });
              }
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: to ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setSheet(() {
                  // End-of-day so a same-day filter includes afternoon scans.
                  to = DateTime(
                      picked.year, picked.month, picked.day, 23, 59, 59);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Filter History',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),

                  // Product type
                  _sheetLabel('Product type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ProductTypeFilter.values.map((t) {
                      final selected = type == t;
                      return GestureDetector(
                        onTap: () => setSheet(() => type = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? FATTheme.primaryGreen
                                : FATTheme.primaryGreen.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: FATTheme.primaryGreen),
                          ),
                          child: Text(t.displayName,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      selected ? Colors.black : Colors.black54)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Date range
                  _sheetLabel('Date range'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField('From', dateLabel(from), pickFrom,
                            from != null, () => setSheet(() => from = null)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField('To', dateLabel(to), pickTo,
                            to != null, () => setSheet(() => to = null)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Enforcement-only toggle
                  _sheetLabel('Enforcement'),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: FATTheme.scanGreen,
                    title: const Text('Show only flagged scans',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Records where USDA / FSIS disclosure was not detected',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    value: enforcementOnly,
                    onChanged: (v) => setSheet(() => enforcementOnly = v),
                  ),
                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheet(() {
                            type = _ProductTypeFilter.all;
                            from = null;
                            to = null;
                            enforcementOnly = false;
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FATTheme.errorRed,
                            side:
                                const BorderSide(color: FATTheme.errorRed),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Clear all',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FATTheme.scanGreen,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Apply',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Commit staged edits to the screen.
    setState(() {
      _typeFilter = type;
      _dateFrom = from;
      _dateTo = to;
      _enforcementOnly = enforcementOnly;
    });
  }

  Widget _sheetLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Colors.black54));

  Widget _dateField(String label, String value, VoidCallback onTap,
      bool hasValue, VoidCallback onClear) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.cancel,
                    color: Colors.black38, size: 18),
              )
            else
              const Icon(Icons.calendar_today,
                  color: Colors.black38, size: 16),
          ],
        ),
      ),
    );
  }

  // Aggregate summary over the filtered records — mirrors iOS HistoryAggregateCard.
  Widget _aggregateCard() {
    final recs = _filtered;
    final total = recs.length;
    final metCount = recs.where((r) => r.regulatoryPassed).length;
    final pctMet = total > 0 ? '${(metCount / total * 100).round()}%' : '—';
    final ids = <String>{};
    for (final r in recs) {
      final est = r.detectedEstablishmentNumber;
      if (est != null && est.isNotEmpty) ids.add('est:$est');
    }
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FATTheme.primaryGreen.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FATTheme.primaryGreen),
        ),
        child: Row(
          children: [
            stat('$total', 'Scans'),
            stat(pctMet, 'Regulatory Met'),
            stat('${ids.length}', 'Brands / EST'),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_results.isEmpty) {
      return _emptyState(Icons.inbox_outlined, 'No saved evaluations yet');
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return _emptyState(
          Icons.filter_list_off, 'No scans match the current filter');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _historyCard(filtered[i]),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.black26),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _historyCard(FATResult r) {
    final regMet = r.regulatoryPassed;
    final est = r.detectedEstablishmentNumber;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ResultsScreen(result: r))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FATTheme.primaryGreen.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FATTheme.primaryGreen),
        ),
        child: Row(
          children: [
            // Disclosure-count badge (count model — not a letter grade).
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF34A853), // disclosure green
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${r.knownCount}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0)),
                  const Text('of 16',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_dateStr(r.scannedAt),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Text('at',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54)),
                      const SizedBox(width: 6),
                      Text(_timeStr(r.scannedAt),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: regMet
                          ? FATTheme.primaryGreen
                          : FATTheme.errorBGTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      regMet
                          ? 'USDA / FSIS disclosure detected'
                          : 'USDA / FSIS disclosure not detected',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: regMet ? Colors.black : FATTheme.errorRed),
                    ),
                  ),
                  if (est != null) ...[
                    const SizedBox(height: 4),
                    Text('EST. $est',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  String _dateStr(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String _timeStr(DateTime d) {
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
            'This will permanently delete all saved evaluations. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ScanStore.instance.deleteAll();
      await _load();
    }
  }
}
