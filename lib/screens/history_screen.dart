import 'package:flutter/material.dart';
import '../models/fat_models.dart';
import '../services/scan_store.dart';
import '../theme/fat_theme.dart';
import 'results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<FATResult> _results = [];
  bool _loading = true;
  String _search = '';
  ProductType? _typeFilter; // null = All
  final _searchController = TextEditingController();

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
      if (_typeFilter != null && r.productType != _typeFilter) return false;
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
                    _filterChips(),
                    const SizedBox(height: 10),
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
          if (_results.isNotEmpty)
            GestureDetector(
              onTap: _confirmClear,
              child: const Text('Clear All',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
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

  // Product-type filter chips (All / Meat / Seafood) — mirrors iOS HistoryFilter.
  Widget _filterChips() {
    Widget chip(String label, ProductType? type) {
      final selected = _typeFilter == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _typeFilter = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? FATTheme.primaryGreen
                  : FATTheme.primaryGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FATTheme.primaryGreen),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.black : Colors.black54)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip('All', null),
          chip('Meat', ProductType.meat),
          chip('Seafood', ProductType.seafood),
        ],
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
