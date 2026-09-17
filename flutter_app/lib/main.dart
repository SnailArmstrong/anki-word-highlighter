import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_model.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppModel(),
      child: const AnkiSpanishSyncApp(),
    ),
  );
}

class AnkiSpanishSyncApp extends StatelessWidget {
  const AnkiSpanishSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anki Spanish Sync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
