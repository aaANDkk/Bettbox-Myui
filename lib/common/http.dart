import 'dart:io';

import 'package:bett_box/state.dart';

class BettboxHttpOverrides extends HttpOverrides {
  static bool _isLoopback(String host) {
    if (host.isEmpty) return true;
    final normalized = host.toLowerCase();
    if (normalized == 'localhost') return true;
    final ip = InternetAddress.tryParse(normalized);
    return ip != null && ip.isLoopback;
  }

  static String handleFindProxy(Uri url) {
    if (_isLoopback(url.host)) {
      return 'DIRECT';
    }
    final port = globalState.config.patchClashConfig.mixedPort;
    final isStart = globalState.appState.runTime != null;
    if (!isStart) return 'DIRECT';
    return 'PROXY localhost:$port';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, _, _) => true;
    client.findProxy = handleFindProxy;
    return client;
  }
}
