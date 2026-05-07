import "dart:io" show Platform;

import "package:flutter_dotenv/flutter_dotenv.dart" as dotenv;
import "package:flutter/foundation.dart" show kIsWeb;

class AppConfig {
  static List<String> get apiBaseUrlCandidates {
    final fromEnv = dotenv.dotenv.env["FLUTTER_API_BASE_URL"] ?? "";
    if (fromEnv.isNotEmpty) return [fromEnv];

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
