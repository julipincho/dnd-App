// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> openExternalUrl(String url) async {
  html.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}

ExternalWindowHandle openPendingExternalWindow() {
  final openedWindow = html.window.open('about:blank', '_blank');
  return ExternalWindowHandle._(openedWindow);
}

class ExternalWindowHandle {
  final html.WindowBase _window;

  const ExternalWindowHandle._(this._window);

  void navigate(String url) {
    _window.location.href = url;
  }

  void close() {
    _window.close();
  }
}
