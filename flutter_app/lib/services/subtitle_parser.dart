/// A single subtitle cue with timing and text.
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  bool isActiveAt(Duration position) =>
      position >= start && position < end;
}

/// Parses SRT and VTT subtitle files into a list of [SubtitleCue]s.
class SubtitleParser {
  static final _timingRegex =
      RegExp(r'(\d{1,2}:\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[.,]\d{3})');

  static List<SubtitleCue> parse(String content) {
    final cues = <SubtitleCue>[];

    // Normalize line endings, split into blocks separated by blank lines.
    final blocks = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim()
        .split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      // Skip WEBVTT header block.
      if (lines[0].startsWith('WEBVTT')) continue;

      // First line may be a cue number (no "-->"); skip it if so.
      int timingLineIndex = lines[0].contains('-->') ? 0 : 1;
      if (timingLineIndex >= lines.length) continue;

      final match = _timingRegex.firstMatch(lines[timingLineIndex]);
      if (match == null) continue;

      final start = _parseDuration(match.group(1)!);
      final end = _parseDuration(match.group(2)!);
      final text = lines
          .sublist(timingLineIndex + 1)
          .join(' ')
          .replaceAll(RegExp(r'<[^>]+>'), '') // strip inline tags
          .trim();

      if (text.isNotEmpty) {
        cues.add(SubtitleCue(start: start, end: end, text: text));
      }
    }

    return cues;
  }

  static Duration _parseDuration(String s) {
    s = s.replaceAll(',', '.');
    final parts = s.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final secParts = parts[2].split('.');
    final sec = int.parse(secParts[0]);
    final ms = secParts.length > 1 ? int.parse(secParts[1].padRight(3, '0').substring(0, 3)) : 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
  }
}
