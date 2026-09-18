import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';
import '../app_model.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SyncCategory(),
          _AnnotationCategory(),
          _WordCategoryColors(),
          _AnkiDeckCategory(),
          _SuspendedCardsCategory(),
          _DataCategory(),
        ],
      ),
    );
  }
}

// ── Expandable section wrapper ──────────────────────────────────────────────

class _ExpandableCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ExpandableCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  late final Animation<double> _chevron =
      Tween(begin: 0.0, end: 0.5).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Icon(widget.icon, size: 22, color: AppTheme.accent),
            const SizedBox(width: 12),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        iconColor: AppTheme.textSecondary,
        collapsedIconColor: AppTheme.textSecondary,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (expanded) {
          expanded ? _controller.forward() : _controller.reverse();
        },
        children: widget.children,
      ),
    );
  }
}

// ── Sync & Dictionary ───────────────────────────────────────────────────────

class _SyncCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return _ExpandableCard(
      title: 'Sync & Dictionary',
      icon: Icons.sync,
      children: [
        _statusRow('Cached Words', model.wordCount.toString()),
        _statusRow('Status', model.syncStatus,
            valueColor: model.syncStatusColor),
        _statusRow('Dictionary Words',
            model.dictionaryWords.length.toString()),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: model.isSyncing ? null : () => model.syncFromAnki(),
          child: Text(model.isSyncing ? 'Syncing...' : 'Force Manual Sync'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _importDictionary(context, model),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: AppTheme.accent,
          ),
          child: const Text('Import Yomitan Dictionary'),
        ),
      ],
    );
  }

  Future<void> _importDictionary(BuildContext context, AppModel model) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final message = await model.importDictionary(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import failed: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }
}

// ── Annotation Settings ─────────────────────────────────────────────────────

class _AnnotationCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return _ExpandableCard(
      title: 'Annotation',
      icon: Icons.format_color_text,
      children: [
        _toggleRow(context, 'Enable Annotation', model.highlightEnabled,
            (v) => model.setHighlightEnabled(v)),
        _divider(),
        _dropdownRow(context, 'Style Mode', model.annotationStyle,
            ['highlight', 'underline', 'textcolor'],
            (v) => model.setAnnotationStyle(v)),
      ],
    );
  }
}

// ── Word Category Colors ───────────────────────────────────────────────────

class _WordCategoryColors extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return _ExpandableCard(
      title: 'Word Categories',
      icon: Icons.palette,
      children: [
        _categoryRow(context, 'Learning', model.highlightLearningEnabled,
            model.colorLearning, 'learning', model),
        _divider(),
        _categoryRow(context, 'Mature', model.highlightMatureEnabled,
            model.colorMature, 'mature', model),
        _divider(),
        _categoryRow(context, 'Unknown', model.highlightUnknownEnabled,
            model.colorUnknown, 'unknown', model),
      ],
    );
  }
}

// ── Anki Deck Settings ──────────────────────────────────────────────────────

class _AnkiDeckCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return _ExpandableCard(
      title: 'Anki Deck',
      icon: Icons.style,
      children: [
        _dropdownRow(context, 'Target Deck', model.selectedDeck,
            model.availableDecks, (v) => model.setSelectedDeck(v)),
        _divider(),
        _dropdownRow(context, 'Target Field', model.selectedField,
            model.availableFields, (v) => model.setSelectedField(v)),
      ],
    );
  }
}

// ── Suspended Card Handling ─────────────────────────────────────────────────

class _SuspendedCardsCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return _ExpandableCard(
      title: 'Suspended Cards',
      icon: Icons.block,
      children: [
        _toggleRow(context, 'Use Suspended Override',
            model.suspendedOverrideEnabled,
            (v) =>
                model.setSuspendedOverride(v, model.suspendedOverrideStatus)),
        _divider(),
        _dropdownRow(
          context,
          'Treat Suspended As',
          model.suspendedOverrideStatus,
          ['mature', 'learning', 'ignore'],
          (v) =>
              model.setSuspendedOverride(model.suspendedOverrideEnabled, v),
          enabled: model.suspendedOverrideEnabled,
        ),
      ],
    );
  }
}

// ── Data Management ─────────────────────────────────────────────────────────

class _DataCategory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return _ExpandableCard(
      title: 'Data Management',
      icon: Icons.delete_outline,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Remove all cached words, dictionary data, and lemmatization rules.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        FilledButton(
          onPressed: () => _clearData(context, model),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Clear All Data'),
        ),
      ],
    );
  }

  Future<void> _clearData(BuildContext context, AppModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will remove all cached words, dictionary data, and lemmatization rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      model.clearAllData();
    }
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

Widget _divider() =>
    const Divider(height: 24, thickness: 1, color: AppTheme.cardBorder);

Widget _statusRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}

Widget _toggleRow(BuildContext context, String label, bool value,
    ValueChanged<bool> onChanged) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _dropdownRow(BuildContext context, String label, String value,
    List<String> items, ValueChanged<String> onChanged,
    {bool enabled = true}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      DropdownButton<String>(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 14)),
                ))
            .toList(),
        onChanged: enabled ? (v) => onChanged(v!) : null,
        dropdownColor: AppTheme.card,
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
    ],
  );
}

Widget _categoryRow(BuildContext context, String label, bool enabled,
    Color color, String category, AppModel model) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      Row(
        children: [
          Switch(
            value: enabled,
            onChanged: (v) => model.setCategoryEnabled(category, v),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showColorPicker(context, category, model),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder, width: 2),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _showColorPicker(
    BuildContext context, String category, AppModel model) async {
  final palettes = <String, List<Color>>{
    'learning': [
      const Color(0xFFFFC107), const Color(0xFFFD7E14),
      const Color(0xFFE83E8C), const Color(0xFF007BFF),
      const Color(0xFF6F42C1),
    ],
    'mature': [
      const Color(0xFF28A745), const Color(0xFF20C997),
      const Color(0xFF17A2B8), const Color(0xFFDC3545),
      const Color(0xFF343A40),
    ],
    'unknown': [
      const Color(0xFF6B7280), const Color(0xFF9333EA),
      const Color(0xFF0EA5E9), const Color(0xFFF43F5E),
      const Color(0xFF78716C),
    ],
  };

  final currentColor = category == 'learning'
      ? model.colorLearning
      : category == 'mature'
          ? model.colorMature
          : model.colorUnknown;

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$category Color',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: palettes[category]!.map((color) {
                final isSelected = color == currentColor;
                return GestureDetector(
                  onTap: () {
                    model.setColor(category, color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.textPrimary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
