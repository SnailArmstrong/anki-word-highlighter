import 'package:flutter/material.dart';

/// A segment of text with optional highlighting status.
class TextSegment {
  final String text;
  final String? status; // 'learning' | 'mature' | 'unknown'
  final Color? color;
  final bool highlighted;

  const TextSegment({
    required this.text,
    this.status,
    this.color,
    this.highlighted = false,
  });
}

/// Ported from content.js — tokenizes text and produces annotated
/// segments with color-coded learning status.
class HighlightEngine {
  static final _wordRegex = RegExp(r'[\p{L}\p{M}\p{N}_]+', unicode: true);

  static List<TextSegment> process({
    required String text,
    required Map<String, String> wordCache,
    required Set<String> dictionaryWords,
    required bool highlightEnabled,
    required String annotationStyle,
    required Color colorLearning,
    required Color colorMature,
    required Color colorUnknown,
    required bool learningEnabled,
    required bool matureEnabled,
    required bool unknownEnabled,
  }) {
    if (!highlightEnabled) {
      return [TextSegment(text: text)];
    }

    final segments = <TextSegment>[];
    int lastIndex = 0;

    for (final match in _wordRegex.allMatches(text)) {
      final word = match.group(0)!;
      final normalized = word.toLowerCase();

      if (match.start > lastIndex) {
        segments.add(TextSegment(text: text.substring(lastIndex, match.start)));
      }

      final status = wordCache[normalized] ??
          (dictionaryWords.contains(normalized) ? 'unknown' : null);

      final categoryEnabled = status == 'mature'
          ? matureEnabled
          : status == 'unknown'
              ? unknownEnabled
              : status == 'learning'
                  ? learningEnabled
                  : false;

      if (status != null && categoryEnabled) {
        final color = status == 'mature'
            ? colorMature
            : status == 'unknown'
                ? colorUnknown
                : colorLearning;
        segments.add(TextSegment(
          text: word,
          status: status,
          color: color,
          highlighted: true,
        ));
      } else {
        segments.add(TextSegment(text: word));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      segments.add(TextSegment(text: text.substring(lastIndex)));
    }

    return segments;
  }
}
