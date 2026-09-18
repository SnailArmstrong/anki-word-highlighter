import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';
import '../app_model.dart';
import '../services/file_parser.dart';
import '../widgets/highlighted_text.dart';

class ReaderTab extends StatefulWidget {
  const ReaderTab({super.key});

  @override
  State<ReaderTab> createState() => _ReaderTabState();
}

class _ReaderTabState extends State<ReaderTab> {
  String? _content;
  String? _fileName;
  double _fontSize = 18;

  static const _sampleText = '''
El hombre camina por la calle mientras come una manzana. Tiene mucho trabajo que hacer hoy. Después de comer, va a estudiar español en la biblioteca. Aprende nuevas palabras cada día.

Cuando terminó de estudiar, decidió nadar en la piscina. Su amigo le dijo que era importante practicar todos los días. Hablar con personas nativas ayuda mucho. Escribir y leer también son actividades importantes para el aprendizaje.

Ellos quieren viajar a España el próximo año. Para ellos, es importante aprender el idioma antes del viaje. Él dice que viajar es la mejor manera de aprender. Ver las palabras en contexto ayuda a recordarlas mejor.

Su amigo puede ayudar con la pronunciación. Él sabe que la práctica constante es la clave. Trabajar duro y ser paciente son importantes. Cada día aprende algo nuevo y quiere seguir mejorando.
''';

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();

    return Scaffold(
      appBar: AppBar(
        leading: _content != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Close book',
                onPressed: _closeBook,
              )
            : null,
        title: Text(_fileName ?? 'Reader'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Reader settings',
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: StatefulBuilder(
                  builder: (context, setMenuState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Font Size: ${_fontSize.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.text_decrease),
                              onPressed: () {
                                setState(() => _fontSize =
                                    (_fontSize - 2).clamp(12.0, 32.0));
                                setMenuState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.text_increase),
                              onPressed: () {
                                setState(() => _fontSize =
                                    (_fontSize + 2).clamp(12.0, 32.0));
                                setMenuState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: _content == null ? _buildEmptyState(context) : _buildReader(model),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFile(context),
        icon: const Icon(Icons.folder_open),
        label: const Text('Open File'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'No file open',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _loadSample,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size(200, 46),
            ),
            child: const Text('Load Sample Text'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _openFile(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size(200, 46),
            ),
            child: const Text('Open File (EPUB/TXT)'),
          ),
        ],
      ),
    );
  }

  Widget _buildReader(AppModel model) {
    final paragraphs = _content!.split(RegExp(r'\n\s*\n'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: paragraphs.length,
      itemBuilder: (context, i) {
        final para = paragraphs[i].trim();
        if (para.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: HighlightedText(
            text: para,
            model: model,
            fontSize: _fontSize,
          ),
        );
      },
    );
  }

  void _closeBook() {
    setState(() {
      _content = null;
      _fileName = null;
    });
  }

  void _loadSample() {
    setState(() {
      _content = _sampleText;
      _fileName = 'Sample Text';
    });
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'txt', 'text'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final content = await FileParser.parse(file.name, file.bytes!);

      setState(() {
        _content = content;
        _fileName = file.name;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }
}
