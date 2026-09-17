import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';
import '../app_model.dart';

class SyncTab extends StatelessWidget {
  const SyncTab({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Anki Spanish Sync')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: Border.all(color: AppTheme.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _statusRow('Cached Words', model.wordCount.toString()),
                const SizedBox(height: 14),
                _statusRow('Status', model.syncStatus,
                    valueColor: model.syncStatusColor),
                const SizedBox(height: 14),
                _statusRow('Dictionary Words', model.dictionaryWords.length.toString()),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: Border.all(color: AppTheme.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Configuration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _infoRow('Deck', model.selectedDeck),
                _infoRow('Field', model.selectedField),
                _infoRow('Annotation', model.highlightEnabled ? 'On' : 'Off'),
                _infoRow('Style', model.annotationStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, {Color? valueColor}) {
    return Row(
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
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
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
          SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}
