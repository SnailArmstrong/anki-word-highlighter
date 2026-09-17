import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'services/anki_sync_service.dart';
import 'services/dictionary_service.dart';

/// Central app state — holds settings, word cache, and sync state.
/// Replaces chrome.storage.local + IndexedDB from the extension.
class AppModel extends ChangeNotifier {
  // Settings
  bool highlightEnabled = true;
  String annotationStyle = 'highlight';
  Color colorLearning = const Color(0xFFFFC107);
  Color colorMature = const Color(0xFF28A745);
  Color colorUnknown = const Color(0xFF6B7280);
  bool highlightLearningEnabled = true;
  bool highlightMatureEnabled = true;
  bool highlightUnknownEnabled = true;
  String selectedDeck = 'Mined word';
  String selectedField = 'Spanish Word';
  bool suspendedOverrideEnabled = false;
  String suspendedOverrideStatus = 'mature';

  // Data
  Map<String, String> wordCache = {};
  Map<String, List<String>> lemmatizationRules = {};
  Set<String> dictionaryWords = {};

  // Sync state
  bool isSyncing = false;
  String syncStatus = 'Ready';

  Color get syncStatusColor {
    if (isSyncing) return const Color(0xFFFFC107);
    if (syncStatus == 'Updated!') return const Color(0xFF4ADE80);
    if (syncStatus == 'Error!') return const Color(0xFFDC2626);
    return const Color(0xFF4ADE80);
  }

  List<String> availableDecks = [
    'Mined word',
    'Spanish::Vocabulary',
    'Spanish::Grammar',
    'Default',
  ];
  List<String> availableFields = [
    'Spanish Word',
    'Front',
    'Back',
    'Definition',
    'Example',
  ];

  AppModel() {
    wordCache = Map<String, String>.from(AnkiSyncService.mockWordCache);
    dictionaryWords = Set<String>.from(AnkiSyncService.mockDictionaryWords);
  }

  int get wordCount => wordCache.length;

  Future<void> syncFromAnki() async {
    isSyncing = true;
    syncStatus = 'Syncing...';
    notifyListeners();

    try {
      final result = await AnkiSyncService.sync(
        targetDeck: selectedDeck,
        targetField: selectedField,
        lemmatizationRules: lemmatizationRules,
        suspendedOverrideEnabled: suspendedOverrideEnabled,
        suspendedOverrideStatus: suspendedOverrideStatus,
      );
      wordCache = result.wordCache;
      syncStatus = 'Updated!';
    } catch (e) {
      syncStatus = 'Error!';
    }

    isSyncing = false;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    syncStatus = 'Ready';
    notifyListeners();
  }

  Future<String> importDictionary(Uint8List zipBytes) async {
    final result = DictionaryService.import(
      zipBytes,
      lemmatizationRules,
      dictionaryWords,
    );
    lemmatizationRules = result.lemmatizationRules;
    dictionaryWords = result.dictionaryWords;
    notifyListeners();
    return 'Imported ${result.totalTermsProcessed} terms, ${result.rulesAdded} rules';
  }

  // Settings update methods
  void setHighlightEnabled(bool v) { highlightEnabled = v; notifyListeners(); }
  void setAnnotationStyle(String v) { annotationStyle = v; notifyListeners(); }
  void setCategoryEnabled(String category, bool v) {
    switch (category) {
      case 'learning': highlightLearningEnabled = v;
      case 'mature': highlightMatureEnabled = v;
      case 'unknown': highlightUnknownEnabled = v;
    }
    notifyListeners();
  }
  void setColor(String category, Color color) {
    switch (category) {
      case 'learning': colorLearning = color;
      case 'mature': colorMature = color;
      case 'unknown': colorUnknown = color;
    }
    notifyListeners();
  }
  void setSelectedDeck(String v) { selectedDeck = v; notifyListeners(); }
  void setSelectedField(String v) { selectedField = v; notifyListeners(); }
  void setSuspendedOverride(bool enabled, String status) {
    suspendedOverrideEnabled = enabled;
    suspendedOverrideStatus = status;
    notifyListeners();
  }
  void clearAllData() {
    wordCache = {};
    lemmatizationRules = {};
    dictionaryWords = {};
    notifyListeners();
  }
}
