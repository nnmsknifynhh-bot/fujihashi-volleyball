import 'package:flutter/material.dart';

class AppTheme {
  // チームカラー
  static const Color primaryRed = Color(0xFFCC0000);
  static const Color darkRed = Color(0xFF990000);
  static const Color gold = Color(0xFFFFD700);
  static const Color darkGold = Color(0xFFB8860B);
  static const Color black = Color(0xFF0A0A0A);
  static const Color darkBg = Color(0xFF111111);
  static const Color cardBg = Color(0xFF1A1A1A);
  static const Color cardBg2 = Color(0xFF222222);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFCCCCCC);
  static const Color grey = Color(0xFF888888);

  // サーブ結果カラー
  static const Color aceColor = Color(0xFFFFD700);    // 金：エース
  static const Color underColor = Color(0xFF4CAF50);  // 緑：崩し
  static const Color justInColor = Color(0xFF2196F3); // 青：入っただけ
  static const Color missColor = Color(0xFFCC0000);   // 赤：ミス

  // レシーブ結果カラー
  static const Color overColor = Color(0xFF4CAF50);   // 緑：オーバー
  static const Color receiveUnderColor = Color(0xFF2196F3); // 青：アンダー
  static const Color directColor = Color(0xFFFF9800); // オレンジ：ダイレクト
  static const Color receiveMissColor = Color(0xFFCC0000); // 赤：ミス

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryRed,
        scaffoldBackgroundColor: black,
        colorScheme: const ColorScheme.dark(
          primary: primaryRed,
          secondary: gold,
          surface: cardBg,
          onPrimary: white,
          onSecondary: black,
          onSurface: white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: black,
          foregroundColor: white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111111),
          selectedItemColor: gold,
          unselectedItemColor: grey,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          type: BottomNavigationBarType.fixed,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            foregroundColor: white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF333333), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardBg2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryRed, width: 2),
          ),
          labelStyle: const TextStyle(color: lightGrey),
          hintStyle: const TextStyle(color: grey),
        ),
        dividerColor: const Color(0xFF333333),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: white),
          bodyMedium: TextStyle(color: lightGrey),
          titleLarge: TextStyle(color: white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: white, fontWeight: FontWeight.w600),
        ),
      );

  // ゴールドのグラデーション
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 赤のグラデーション
  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFCC0000), Color(0xFF660000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ヘッダーのグラデーション
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1A0000), Color(0xFF2A0000), Color(0xFF0A0A0A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
