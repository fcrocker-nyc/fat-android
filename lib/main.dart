import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/fat_theme.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/lookup_screen.dart';
import 'data/brand_resolver.dart';
import 'menu/menu_screens.dart';
import 'screens/service_case_capture_screen.dart';
import 'services/lost_photo_recovery.dart';
import 'interpreter/seafood_bycatch.dart';
import 'cuts/cut_guide.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Load the brand-data feed (crosswalk + aliases + enforcement). Bundled
  // snapshot loads first; remote refresh rolls forward in the background.
  BrandResolver.instance.init();
  // Bundled NOAA MMPA bycatch pairs for the seafood Cat. 10 context line.
  MmpaBycatchData.ensureLoaded();
  // Cut guide, so Home's Quick Lookup can route "ribeye" to Lookup → Cut.
  CutGuide.load();
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _autoLaunchCamera = false;
  LookupRequest? _pendingLookup;
  String? _recoveredLabelPhoto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recoverLostPhoto();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera result can reach image_picker after initState's check;
    // ask again whenever FAT comes back to the front. No-op unless a scan
    // is pending and no pick is open in this process.
    if (state == AppLifecycleState.resumed) _recoverLostPhoto();
  }

  /// Android can kill FAT while the camera is open; the photo then comes back
  /// after the restart. Reopen the scan that took it, with the photo in it.
  Future<void> _recoverLostPhoto() async {
    final recovered = await LostPhotoRecovery.retrieve();
    if (recovered == null || !mounted) return;
    switch (recovered.scan) {
      case PhotoScan.label:
        setState(() {
          _recoveredLabelPhoto = recovered.paths.first;
          _selectedIndex = 1;
        });
      case PhotoScan.serviceCase:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ServiceCaseCaptureScreen(recoveredPhotoPath: recovered.paths.first),
        ));
      case PhotoScan.menu:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MenuScanScreen(recoveredPhotoPaths: recovered.paths),
        ));
    }
  }

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
        recoveredPhotoPath: _recoveredLabelPhoto,
        onRecoveredPhotoConsumed: () =>
            setState(() => _recoveredLabelPhoto = null),
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

  // Floating rounded tab bar — matches the iOS 26 system TabView, which
  // renders as a floating capsule above the home indicator (not a flat bar).
  static const _items = [
    (Icons.home_filled, 'Home'),
    (Icons.camera_alt, 'Scan'),
    (Icons.search, 'Lookup'),
    (Icons.history, 'History'),
    (Icons.menu_book, 'Learn'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0x11000000)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
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
                    Icon(item.$1, size: 25, color: color),
                    const SizedBox(height: 2),
                    Text(
                      item.$2,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: color),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
