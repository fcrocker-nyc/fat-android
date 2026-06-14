import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/fat_theme.dart';

class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key});

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  int _selectedTab = 0; // 0=EST, 1=Meat Brand, 2=Seafood Brand
  final _estController = TextEditingController();
  final _brandController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _processorData;
  bool _lookupFailed = false;
  String? _failureMsg;

  final List<String> _tabs = ['EST', 'Meat Brand', 'Seafood Brand'];

  Future<void> _lookupEst() async {
    final est = _estController.text.trim();
    if (est.isEmpty) return;
    setState(() {
      _isLoading = true;
      _processorData = null;
      _lookupFailed = false;
      _failureMsg = null;
    });
    try {
      final uri = Uri.parse(
        'https://farmanimaltransparency.com/wp-content/plugins/fat-fsis-data-manager/fat-fsis-data.php?est=$est',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('establishmentName')) {
          setState(() => _processorData = Map<String, dynamic>.from(data));
        } else {
          setState(() {
            _lookupFailed = true;
            _failureMsg = 'No establishment found for EST. $est.';
          });
        }
      } else {
        setState(() {
          _lookupFailed = true;
          _failureMsg = 'Server returned ${response.statusCode}.';
        });
      }
    } catch (e) {
      setState(() {
        _lookupFailed = true;
        _failureMsg = 'Network error. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _lookupBrand() async {
    final brand = _brandController.text.trim();
    if (brand.isEmpty) return;
    setState(() {
      _isLoading = true;
      _processorData = null;
      _lookupFailed = false;
      _failureMsg = null;
    });
    // Brand lookup not yet implemented — show coming soon
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _lookupFailed = true;
        _failureMsg =
            'Brand lookup coming soon. Use the EST tab to look up a USDA establishment number.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _heroHeader()),
          SliverToBoxAdapter(child: _topRule()),
          SliverToBoxAdapter(child: _tabSegmentedControl()),
          SliverToBoxAdapter(child: _tabContent()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _heroHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              child: Image.asset(
                'assets/images/hero.jpg',
                height: 252,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              child: Container(
                height: 252,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ),
            const Text(
              'LOOKUP',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0,
                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topRule() {
    return Container(
      height: 2,
      margin: const EdgeInsets.fromLTRB(14, 24, 14, 0),
      color: FATTheme.primaryGreen,
    );
  }

  Widget _tabSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == _selectedTab;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = i;
                    _processorData = null;
                    _lookupFailed = false;
                    _failureMsg = null;
                  });
                },
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(21),
                    border: selected
                        ? Border.all(
                            color: Colors.black.withValues(alpha: 0.04),
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _tabs[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
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
    if (_selectedTab == 0) return _estTab();
    return _brandTab(_selectedTab == 1 ? 'Meat' : 'Seafood');
  }

  Widget _estTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter USDA Establishment Number',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _estController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'e.g. 969',
              hintStyle: const TextStyle(
                color: Color(0xFFC9C9C9),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            onSubmitted: (_) => _lookupEst(),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _isLoading ? null : _lookupEst,
            style: ElevatedButton.styleFrom(
              backgroundColor: FATTheme.primaryGreen,
              foregroundColor: Colors.black.withValues(alpha: 0.50),
              disabledBackgroundColor: FATTheme.primaryGreen.withValues(
                alpha: 0.60,
              ),
              disabledForegroundColor: Colors.black.withValues(alpha: 0.42),
              elevation: 0,
              minimumSize: const Size.fromHeight(62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Look Up',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
          ),
          const SizedBox(height: 24),
          if (_processorData != null) _processorCard(_processorData!),
          if (_lookupFailed) _failureCard(),
          if (_processorData == null && !_lookupFailed) _estInfoSection(),
        ],
      ),
    );
  }

  Widget _brandTab(String type) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter $type Brand Name',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _brandController,
            decoration: InputDecoration(
              hintText: 'e.g. Tyson, Gorton\'s',
              hintStyle: const TextStyle(color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            onSubmitted: (_) => _lookupBrand(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _lookupBrand,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Look Up',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 20),
          if (_lookupFailed) _failureCard(),
        ],
      ),
    );
  }

  Widget _estInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About USDA Establishment Numbers',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Many meat and poultry labels include a USDA establishment number, often shown as "EST. ####" near the inspection legend.',
          style: TextStyle(
            fontSize: 18,
            height: 1.24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'This number identifies the federally inspected facility where the product was processed, as listed by the U.S. Department of Agriculture\'s Food Safety and Inspection Service (FSIS).',
          style: TextStyle(
            fontSize: 18,
            height: 1.24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: FATTheme.primaryGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What you can find:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 18),
              Text(
                'Processor name and location',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 18),
              Text(
                'Processing activities and size',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 18),
              Text(
                'Administrative actions and violations',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 18),
              Text(
                'Recall history',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 18),
              Text(
                'Pathogen testing results',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _processorCard(Map<String, dynamic> data) {
    final name = data['establishmentName'] as String? ?? 'Unknown';
    final address = data['fullAddress'] as String? ?? '';
    final species = data['species'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(address, style: const TextStyle(fontSize: 14)),
          ],
          if (species.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Species: $species', style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 8),
          Text(
            'EST. ${_estController.text.trim()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FATTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failureCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _failureMsg ?? 'Lookup failed.',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _estController.dispose();
    _brandController.dispose();
    super.dispose();
  }
}
