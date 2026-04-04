import "dart:io" show Platform;

import "package:flutter/foundation.dart" show kIsWeb;

class AppConfig {
  static List<String> get apiBaseUrlCandidates {
    const fromDefine = String.fromEnvironment("FLUTTER_API_BASE_URL", defaultValue: "");
    if (fromDefine.isNotEmpty) return [fromDefine];

    if (kIsWeb) return ["http://localhost:5000/api"];

    if (Platform.isAndroid) {
      // Try localhost first (works with adb reverse), then emulator host alias.
      return [
        "http://localhost:5000/api",
        "http://10.0.2.2:5000/api",
      ];
    }

    return ["http://localhost:5000/api"];
  }

  static String get apiBaseUrl {
    return apiBaseUrlCandidates.first;
  }
}
