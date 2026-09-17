import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        padding: const EdgeInsets.all(18),
        children: [
          _sectionTitle('Configuration'),
          _card(
            children: [
              _toggleRow(context, 'Enable Annotation', model.highlightEnabled,
                  (v) => model.setHighlightEnabled(v)),
              _dropdownRow(context, 'Style Mode', model.annotationStyle,
                  ['highlight', 'underline', 'textcolor'],
                  (v) => model.setAnnotationStyle(v)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('Word Categories'),
          _card(
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
          ),
          const SizedBox(height: 16),
          _sectionTitle('Anki Deck Settings'),
          _card(
            children: [
              _dropdownRow(context, 'Target Deck', model.selectedDeck,
                  model.availableDecks, (v) => model.setSelectedDeck(v)),
              _divider(),
              _dropdownRow(context, 'Target Field', model.selectedField,
                  model.availableFields, (v) => model.setSelectedField(v)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('Suspended Card Handling'),
          _card(
            children: [
              _toggleRow(context, 'Use Suspended Override',
                  model.suspendedOverrideEnabled,
                  (v) => model.setSuspendedOverride(
                      v, model.suspendedOverrideStatus)),
              _dropdownRow(
                context,
                'Treat Suspended As',
                model.suspendedOverrideStatus,
                ['mature', 'learning', 'ignore'],
                (v) => model.setSuspendedOverride(
                    model.suspendedOverrideEnabled, v),
                enabled: model.suspendedOverrideEnabled,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _clearData(context, model),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() =>
      const Divider(height: 24, thickness: 1, color: AppTheme.cardBorder);

  Widget _toggleRow(BuildContext context, String label, bool value,
      ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
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
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
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
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
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
