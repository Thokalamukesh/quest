import 'external_link_stub.dart'
    if (dart.library.js_interop) 'external_link_web.dart';

/// Opens an http/https URL in a new browser tab on web. Returns `true` if
/// launched directly, or `false` on platforms where callers should fall back
/// to copying the link.
Future<bool> openExternalUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasAuthority ||
      !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
    return Future.value(false);
  }
  return openExternalUrlImpl(trimmed);
}
