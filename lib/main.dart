import 'package:flutter/material.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartCashierApp());
}

/// نقطة تشغيل التطبيق؛ بنثبت الثيم الداكن من البداية عشان كل الشاشات
/// تستخدم نفس ألوان الصورة المرجعية بدل ما كل شاشة تختار ألوانها لوحدها.
class SmartCashierApp extends StatelessWidget {
  const SmartCashierApp({super.key});

  static const neon = Color(0xFF00F0A0);
  static const background = Color(0xFF06110F);
  static const surface = Color(0xFF101D1A);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: neon,
      brightness: Brightness.dark,
      primary: neon,
      surface: surface,
      error: const Color(0xFFFF5B67),
    );

    return MaterialApp(
      title: 'كاشير المحل الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Color(0xFFE7FFF6),
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF243B35)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF091411),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF294139)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF294139)),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}
