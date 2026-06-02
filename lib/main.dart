import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/fat_theme.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/lookup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  void _onScanTap() {
    setState(() {
      _autoLaunchCamera = true;
      _selectedIndex = 1;
    });
  }

  void _clearAutoLaunch() {
    setState(() => _autoLaunchCamera = false);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onScanTap: _onScanTap),
      ScanScreen(autoLaunch: _autoLaunchCamera, onAutoLaunchConsumed: _clearAutoLaunch),
      const LookupScreen(),
      const HistoryScreen(),
      const LearnScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          if (i != 1) _clearAutoLaunch();
          setState(() => _selectedIndex = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled),  label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt),   label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.search),       label: 'Lookup'),
          BottomNavigationBarItem(icon: Icon(Icons.history),      label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book),    label: 'Learn'),
        ],
      ),
    );
  }
}
