import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/serve_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Firebase初期化の状態管理
  bool _firebaseInitialized = false;
  String? _firebaseError;

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (mounted) {
        setState(() => _firebaseInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _firebaseError = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Firebase初期化中
    if (!_firebaseInitialized && _firebaseError == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: AppTheme.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryRed),
                const SizedBox(height: 20),
                const Text(
                  '接続中...',
                  style: TextStyle(color: AppTheme.lightGrey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Firebase初期化エラー
    if (_firebaseError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: AppTheme.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.primaryRed, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '接続エラー',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ネットワーク接続を確認してください',
                  style: TextStyle(color: AppTheme.lightGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _firebaseError = null;
                    });
                    _initFirebase();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                  child: const Text('再接続', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Firebase初期化成功 → アプリ本体
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: '藤橋JVC男子 バレーボール分析',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ServeScreen(),
    const ReceiveScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildSloganBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSloganBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1A0000),
            Color(0xFF2D0000),
            Color(0xFF1A0000),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 1,
            color: AppTheme.gold.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          const Text(
            'この一本、この一点',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 20,
            height: 1,
            color: AppTheme.gold.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, 'ホーム', 0),
              _serveNavItem(1),
              _receiveNavItem(2),
              _navItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, '集計', 3),
              _navItem(Icons.settings_rounded, Icons.settings_outlined, '設定', 4),
            ],
          ),
        ),
      ),
    );
  }

  // 通常ナビアイテム
  Widget _navItem(IconData activeIcon, IconData inactiveIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryRed.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? AppTheme.gold : AppTheme.grey,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.gold : AppTheme.grey,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // サーブ専用ナビアイテム（目立つデザイン）
  Widget _serveNavItem(int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF8B0000), AppTheme.primaryRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryRed
                  : const Color(0xFF333333),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: AppTheme.primaryRed.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_volleyball,
                color: isSelected ? Colors.white : const Color(0xFF884444),
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                'サーブ',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF884444),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 1),
                Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // レシーブ専用ナビアイテム（目立つデザイン）
  Widget _receiveNavItem(int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF003080), Colors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : const Color(0xFF333333),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.back_hand_rounded,
                color: isSelected ? Colors.white : const Color(0xFF334488),
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                'レシーブ',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334488),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 1),
                Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
