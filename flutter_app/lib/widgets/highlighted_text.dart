import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme.dart';
import '../app_model.dart';
import '../services/highlight_engine.dart';
import 'word_detail_sheet.dart';

/// Renders text with inline word highlighting.
/// Tapping a highlighted word shows a detail bottom sheet.
class HighlightedText extends StatefulWidget {
  final String text;
  final AppModel model;
  final double fontSize;

  const HighlightedText({
    super.key,
    required this.text,
    required this.model,
    this.fontSize = 18,
  });

  @override
  State<HighlightedText> createState() => _HighlightedTextState();
}

class _HighlightedTextState extends State<HighlightedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final segments = HighlightEngine.process(
      text: widget.text,
      wordCache: widget.model.wordCache,
      dictionaryWords: widget.model.dictionaryWords,
      highlightEnabled: widget.model.highlightEnabled,
      annotationStyle: widget.model.annotationStyle,
      colorLearning: widget.model.colorLearning,
      colorMature: widget.model.colorMature,
      colorUnknown: widget.model.colorUnknown,
      learningEnabled: widget.model.highlightLearningEnabled,
      matureEnabled: widget.model.highlightMatureEnabled,
      unknownEnabled: widget.model.highlightUnknownEnabled,
    );

    final spans = <InlineSpan>[];

    for (final seg in segments) {
      if (seg.highlighted) {
        final recognizer = TapGestureRecognizer();
        _recognizers.add(recognizer);
        recognizer.onTap = () {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppTheme.card,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => WordDetailSheet(segment: seg),
          );
        };

        spans.add(TextSpan(
          text: seg.text,
          style: _styleForSegment(seg),
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(
          text: seg.text,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: widget.fontSize,
            height: 1.8,
          ),
        ));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }

  TextStyle _styleForSegment(TextSegment seg) {
    final base = TextStyle(
      fontSize: widget.fontSize,
      height: 1.8,
      color: AppTheme.textPrimary,
    );

    switch (widget.model.annotationStyle) {
      case 'underline':
        return base.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: seg.color,
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2.0,
        );
      case 'textcolor':
        return base.copyWith(color: seg.color);
      default:
        return base.copyWith(
          backgroundColor: seg.color,
          color: seg.status == 'learning'
              ? const Color(0xFF333333)
              : Colors.white,
        );
    }
  }
}
