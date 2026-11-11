import 'package:flutter/material.dart';
import 'db.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.database;
  runApp(const AddoManagerApp());
}

class AddoManagerApp extends StatefulWidget {
  const AddoManagerApp({super.key});
  @override
  State<AddoManagerApp> createState() => _AddoManagerAppState();
}

class _AddoManagerAppState extends State<AddoManagerApp> {
  bool swahili = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ADDO Manager',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF13845B)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F8F6),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF13845B), foregroundColor: Colors.white),
    ),
    home: LoginPage(
      swahili: swahili,
      onLanguageChanged: (v) => setState(() => swahili = v),
    ),
  );
}
