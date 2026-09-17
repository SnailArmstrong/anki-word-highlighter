import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'word_utils.dart';

/// Result of a Yomitan dictionary import.
class DictionaryImportResult {
  final Map<String, List<String>> lemmatizationRules;
  final Set<String> dictionaryWords;
  final int totalTermsProcessed;
  final int rulesAdded;

  DictionaryImportResult({
    required this.lemmatizationRules,
    required this.dictionaryWords,
    required this.totalTermsProcessed,
    required this.rulesAdded,
  });
}

/// Ported from options.js — imports a Yomitan .zip dictionary,
/// parses term-bank JSON, and extracts lemma mappings.
class DictionaryService {
  static DictionaryImportResult import(
    Uint8List zipBytes,
    Map<String, List<String>> existingRules,
    Set<String> existingWords,
  ) {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final dictFiles = archive.where((f) =>
        f.isFile &&
        f.name.endsWith('.json') &&
        !f.name.startsWith('__MACOSX') &&
        !f.name.endsWith('index.json') &&
        !f.name.contains('tag_bank'));

    if (dictFiles.isEmpty) {
      throw Exception(
        'No valid term bank or inflection bank JSON files found in ZIP archive.',
      );
    }

    final lemmatizationRules = Map<String, List<String>>.from(existingRules);
    final dictionaryWords = Set<String>.from(existingWords);
    var totalTermsProcessed = 0;
    var rulesAdded = 0;

    for (final file in dictFiles) {
      final jsonText =
          utf8.decode(file.content as List<int>, allowMalformed: true);
      final termEntries = jsonDecode(jsonText);

      if (termEntries is! List) continue;

      for (final entry in termEntries) {
        if (entry is! List) continue;

        final result = WordUtils.extractLemmasFromEntry(entry);
        final term = result.term;
        final lemmas = result.lemmas;

        if (term != null) dictionaryWords.add(term);

        if (term != null && lemmas.isNotEmpty) {
          final existing = lemmatizationRules[term] ?? <String>[];
          final existingSet = Set<String>.from(existing);
          for (final l in lemmas) {
            existingSet.add(l);
            dictionaryWords.add(l);
          }
          lemmatizationRules[term] = existingSet.toList();
          rulesAdded++;
        }
        totalTermsProcessed++;
      }
    }

    return DictionaryImportResult(
      lemmatizationRules: lemmatizationRules,
      dictionaryWords: dictionaryWords,
      totalTermsProcessed: totalTermsProcessed,
      rulesAdded: rulesAdded,
    );
  }
}
