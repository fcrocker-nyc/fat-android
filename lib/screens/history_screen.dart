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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await ScanStore.instance.loadAll();
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          if (_results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FATTheme.scanGreen))
          : _results.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _historyCard(_results[i]),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: FATTheme.primaryGreen),
          SizedBox(height: 16),
          Text('No scans yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('Scan a meat or seafood label to get started.',
              style: TextStyle(fontSize: 16, color: FATTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _historyCard(FATResult result) {
    final species = result.categories[FATCategory.species]?.value ?? 'Unknown species';
    final scoreStr = result.fatScore.toStringAsFixed(0);
    final gradeColor = result.gradeColor;
    final date = result.scannedAt;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsScreen(result: result))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FATTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: gradeColor,
              child: Text(result.grade,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(species, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Score: $scoreStr/100  ·  ${_formatDate(date)}',
                      style: const TextStyle(fontSize: 14, color: FATTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${result.knownCount} disclosed  ${result.partialCount} partial  ${result.missingCount} missing',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FATTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Delete all saved scans? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
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
