class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    "FLUTTER_API_BASE_URL",
    defaultValue: "http://localhost:5000/api",
  );
}
