/// Non-web stub — blob URLs are only needed for Flutter web.
String createBlobUrl(List<int> bytes, String mimeType) {
  throw UnsupportedError('Blob URLs are only supported on web.');
}

void revokeBlobUrl(String url) {
  // no-op on non-web
}
