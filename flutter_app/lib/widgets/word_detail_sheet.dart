import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/highlight_engine.dart';

/// Bottom sheet showing a word's learning status and dictionary info.
class WordDetailSheet extends StatelessWidget {
  final TextSegment segment;

  const WordDetailSheet({super.key, required this.segment});

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (segment.status) {
      'mature' => 'Mature',
      'learning' => 'Learning',
      'unknown' => 'Unknown',
      _ => 'Unknown',
    };
    final statusColor = segment.color ?? AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            segment.text,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: segment.status == 'learning'
                    ? const Color(0xFF333333)
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This word is ${segment.status == 'unknown' ? 'recognized by your dictionary' : 'in your Anki deck'} with status: $statusLabel.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
