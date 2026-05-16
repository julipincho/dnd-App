Future<bool> openExternalUrl(String url) async => false;

ExternalWindowHandle? openPendingExternalWindow() => null;

class ExternalWindowHandle {
  const ExternalWindowHandle();

  void navigate(String url) {}

  void close() {}
}
