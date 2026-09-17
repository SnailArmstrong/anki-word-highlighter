/// Ported from the Chrome extension's background.js / options.js.
/// Spanish word extraction, reflexive-variant generation, and
/// Yomitan dictionary lemma parsing.

class WordUtils {
  /// Extract individual Spanish words from a raw Anki field value.
  static List<String> extractSpanishWords(String rawFieldText) {
    if (rawFieldText.isEmpty) return [];

    var text = rawFieldText;
    text = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    text = text.replaceAll(RegExp(r'\([^)]*\)'), ' ');

    final rawTokens = text.split(RegExp(r'[/,;\n\r]+'));
    final results = <String>[];

    for (final token in rawTokens) {
      var clean = token.toLowerCase().trim();
      clean = clean.replaceFirst(
        RegExp(r'^(el|la|los|las|un|una|unos|unas)\s+', caseSensitive: false),
        '',
      );

      for (final word in clean.split(RegExp(r'\s+'))) {
        final cleanWord = word.replaceAll(
          RegExp(r'[^\p{L}\p{M}\p{N}_]', unicode: true),
          '',
        );
        if (cleanWord.length > 1) results.add(cleanWord);
      }
    }

    return results;
  }

  /// Generate reflexive-verb variants (e.g. "tener" ↔ "tenerse").
  static List<String> getWordVariants(String word) {
    final clean = word.toLowerCase().trim();
    final variants = <String>{clean};

    if (clean.endsWith('se') && clean.length > 4) {
      variants.add(clean.substring(0, clean.length - 2));
    } else if (clean.endsWith('ar') ||
        clean.endsWith('er') ||
        clean.endsWith('ir')) {
      variants.add('${clean}se');
    }

    return variants.toList();
  }

  /// Add a word and its reflexive variant to a set.
  static void addRootAndReflexiveVariants(String word, Set<String> target) {
    if (word.isEmpty) return;
    final clean = word.toLowerCase().trim();
    if (clean.length <= 1) return;
    target.add(clean);

    if (clean.endsWith('se') && clean.length > 4) {
      target.add(clean.substring(0, clean.length - 2));
    } else if (clean.endsWith('ar') ||
        clean.endsWith('er') ||
        clean.endsWith('ir')) {
      target.add('${clean}se');
    }
  }

  /// Extract lemma roots from definition text via arrow and
  /// grammatical-relation patterns.
  static List<String> extractLemmasFromDefinitions(dynamic definitions) {
    final roots = <String>{};
    final defsArray = definitions is List ? definitions : [definitions];

    for (final def in defsArray) {
      final defText = (def is String ? def : def.toString()).toLowerCase();

      for (final match
          in RegExp(r'->\s*([\p{L}]+)', unicode: true).allMatches(defText)) {
        if (match.group(1) != null) {
          addRootAndReflexiveVariants(match.group(1)!, roots);
        }
      }

      final pattern = RegExp(
        r'(?:indicative|present|past|future|subjunctive|imperative|singular|'
        r'plural|person|form|conjugation|reflexive|pronominal)\s+'
        r'(?:form\s+|verb\s+)?(?:of|from)\s+([\p{L}]+)',
        unicode: true,
      );
      for (final match in pattern.allMatches(defText)) {
        if (match.group(1) != null) {
          addRootAndReflexiveVariants(match.group(1)!, roots);
        }
      }
    }

    return roots.toList();
  }

  /// Extract the headword term and its lemma mappings from a Yomitan
  /// term-bank entry (a JSON array).
  static ({String? term, List<String> lemmas}) extractLemmasFromEntry(
    List<dynamic> entry,
  ) {
    if (entry.isEmpty) return (term: null, lemmas: []);

    final rawTerm = entry[0];
    if (rawTerm is! String || rawTerm.isEmpty) {
      return (term: null, lemmas: []);
    }

    final cleanTerm = rawTerm.toLowerCase().trim();
    final roots = <String>{};

    if (entry.length > 5 && entry[5] != null) {
      final field5 = entry[5];

      if (field5 is List) {
        var containsTuples = false;

        for (final item in field5) {
          if (item is List && item.isNotEmpty && item[0] is String) {
            containsTuples = true;
            addRootAndReflexiveVariants(item[0] as String, roots);
          } else if (item is Map && item['headword'] != null) {
            containsTuples = true;
            addRootAndReflexiveVariants(item['headword'] as String, roots);
          }
        }

        if (!containsTuples) {
          for (final l in extractLemmasFromDefinitions(field5)) {
            addRootAndReflexiveVariants(l, roots);
          }
        }
      } else {
        for (final l in extractLemmasFromDefinitions(field5)) {
          addRootAndReflexiveVariants(l, roots);
        }
      }
    }

    return (term: cleanTerm, lemmas: roots.toList());
  }
}
