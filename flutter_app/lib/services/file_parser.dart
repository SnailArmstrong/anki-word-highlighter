import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Parses EPUB and TXT files into plain text for the reader.
class FileParser {
  static Future<String> parse(String fileName, Uint8List bytes) async {
    final name = fileName.toLowerCase();
    if (name.endsWith('.epub')) return _parseEpub(bytes);
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _parseEpub(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final htmlFiles = archive
        .where((f) =>
            f.isFile &&
            (f.name.endsWith('.xhtml') ||
                f.name.endsWith('.html') ||
                f.name.endsWith('.htm')))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final buffer = StringBuffer();
    for (final file in htmlFiles) {
      final content =
          utf8.decode(file.content as List<int>, allowMalformed: true);
      buffer.writeln(_stripHtml(content));
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static String _stripHtml(String html) {
    var text = html.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&aacute;', 'á')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&uacute;', 'ú')
        .replaceAll('&ntilde;', 'ñ')
        .replaceAll('&Aacute;', 'Á')
        .replaceAll('&Eacute;', 'É')
        .replaceAll('&Iacute;', 'Í')
        .replaceAll('&Oacute;', 'Ó')
        .replaceAll('&Uacute;', 'Ú')
        .replaceAll('&Ntilde;', 'Ñ')
        .replaceAll('&iexcl;', '¡')
        .replaceAll('&iquest;', '¿');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
