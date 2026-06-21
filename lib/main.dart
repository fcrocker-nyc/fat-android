import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/fat_theme.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/lookup_screen.dart';
import 'data/brand_resolver.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Load the brand-data feed (crosswalk + aliases + enforcement). Bundled
  // snapshot loads first; remote refresh rolls forward in the background.
  BrandResolver.instance.init();
  runApp(const FATApp());
}

class FATApp extends StatelessWidget {
  const FATApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAT — Farm Animal Transparency',
      theme: FATTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _autoLaunchCamera = false;
  LookupRequest? _pendingLookup;

  void _onScanTap() {
    setState(() {
      _autoLaunchCamera = true;
      _selectedIndex = 1;
    });
  }

  void _clearAutoLaunch() {
    setState(() => _autoLaunchCamera = false);
  }

  /// Home "Quick Lookup" → switch to the Lookup tab with a pending request.
  void _onQuickLookup(int tab, String query) {
    setState(() {
      _autoLaunchCamera = false;
      _pendingLookup = LookupRequest(tab, query);
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onScanTap: _onScanTap, onQuickLookup: _onQuickLookup),
      ScanScreen(
        autoLaunch: _autoLaunchCamera,
        onAutoLaunchConsumed: _clearAutoLaunch,
      ),
      LookupScreen(
        pending: _pendingLookup,
        onConsumed: () => setState(() => _pendingLookup = null),
      ),
      const HistoryScreen(),
      const LearnScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: _FloatingFATTabBar(
        selectedIndex: _selectedIndex,
        onTap: (i) {
          if (i != 1) _clearAutoLaunch();
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }
}

class _FloatingFATTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingFATTabBar({required this.selectedIndex, required this.onTap});

  // Mirrors iOS ContentView TabView — standard bottom tab bar, filled icons,
  // green accent on the selected tab.
  static const _items = [
    (Icons.home_filled, 'Home'),
    (Icons.camera_alt, 'Scan'),
    (Icons.search, 'Lookup'),
    (Icons.history, 'History'),
    (Icons.menu_book, 'Learn'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(_items.length, (index) {
              final selected = selectedIndex == index;
              final item = _items[index];
              final color =
                  selected ? FATTheme.scanGreen : const Color(0xFF8E8E93);
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$1, size: 26, color: color),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: color),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
