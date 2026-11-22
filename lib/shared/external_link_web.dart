import 'package:web/web.dart' as web;

Future<bool> openExternalUrlImpl(String url) async {
  web.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}
