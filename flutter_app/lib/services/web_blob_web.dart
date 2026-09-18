import 'dart:html';
import 'dart:typed_data';

/// Creates a temporary blob URL from file bytes for use with
/// VideoPlayerController.networkUrl on Flutter web.
String createBlobUrl(List<int> bytes, String mimeType) {
  final blob = Blob([Uint8List.fromList(bytes)], mimeType);
  return Url.createObjectUrl(blob);
}

void revokeBlobUrl(String url) {
  Url.revokeObjectUrl(url);
}
