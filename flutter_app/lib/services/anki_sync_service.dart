import 'word_utils.dart';

/// Syncs word learning status from Anki.
/// On Android: queries AnkiDroid's content provider via platform channel.
/// On web/desktop (preview): returns mock data for demonstration.

class SyncResult {
  final Map<String, String> wordCache;
  final int count;
  SyncResult({required this.wordCache, required this.count});
}

class AnkiSyncService {
  static Map<String, String> get mockWordCache => {
    'tener': 'mature', 'tiene': 'mature', 'tenía': 'mature', 'tendrá': 'mature',
    'hacer': 'mature', 'hago': 'mature', 'hacía': 'mature', 'hizo': 'mature',
    'decir': 'mature', 'dice': 'mature', 'dijo': 'mature', 'dirá': 'mature',
    'ir': 'mature', 'voy': 'mature', 'fui': 'mature', 'iba': 'mature',
    'ver': 'mature', 'veo': 'mature', 'vio': 'mature', 'veía': 'mature',
    'ser': 'mature', 'es': 'mature', 'fue': 'mature', 'era': 'mature',
    'estar': 'mature', 'estoy': 'mature', 'estaba': 'mature', 'estuvo': 'mature',
    'poder': 'mature', 'puedo': 'mature', 'podía': 'mature', 'pudo': 'mature',
    'querer': 'mature', 'quiero': 'mature', 'quería': 'mature', 'quiso': 'mature',
    'saber': 'mature', 'sé': 'mature', 'sabía': 'mature', 'supo': 'mature',
    'dar': 'mature', 'doy': 'mature', 'dio': 'mature', 'daba': 'mature',
    'comer': 'learning', 'como': 'learning', 'comió': 'learning', 'comía': 'learning',
    'hablar': 'learning', 'hablo': 'learning', 'habló': 'learning', 'hablaba': 'learning',
    'aprender': 'learning', 'aprendo': 'learning', 'aprendió': 'learning',
    'trabajar': 'learning', 'trabajo': 'learning', 'trabajó': 'learning',
    'estudiar': 'learning', 'estudio': 'learning', 'estudió': 'learning',
    'vivir': 'learning', 'vivo': 'learning', 'vivió': 'learning',
    'escribir': 'learning', 'escribo': 'learning', 'escribió': 'learning',
    'leer': 'learning', 'leo': 'learning', 'leyó': 'learning',
    'practicar': 'learning', 'practico': 'learning', 'practicó': 'learning',
    'viajar': 'learning', 'viajo': 'learning', 'viajó': 'learning',
  };

  static Set<String> get mockDictionaryWords => {
    'caminar', 'nadar', 'saltar', 'correr', 'manzana', 'calle',
    'biblioteca', 'piscina', 'amigo', 'idioma', 'próximo', 'año',
    'después', 'también', 'personas', 'nativas', 'actividades',
    'importantes', 'mejor', 'manera', 'pronunciación', 'constante',
    'clave', 'duro', 'paciente', 'nuevo', 'mejorando', 'sigue',
  };

  static Future<SyncResult> sync({
    required String targetDeck,
    required String targetField,
    required Map<String, List<String>> lemmatizationRules,
    required bool suspendedOverrideEnabled,
    required String suspendedOverrideStatus,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Android platform channel → AnkiDroid FlashCardsProvider
    final wordCache = Map<String, String>.from(mockWordCache);

    // Apply lemmatization rules
    lemmatizationRules.forEach((inflected, rootLemmas) {
      final cleanInflection = inflected.toLowerCase().trim();
      for (final root in rootLemmas) {
        final cleanRoot = root.toLowerCase().trim();
        if (wordCache.containsKey(cleanRoot)) {
          final sharedStatus = wordCache[cleanRoot]!;
          if (!wordCache.containsKey(cleanInflection) ||
              sharedStatus == 'mature') {
            wordCache[cleanInflection] = sharedStatus;
          }
        }
      }
    });

    return SyncResult(wordCache: wordCache, count: wordCache.length);
  }
}
