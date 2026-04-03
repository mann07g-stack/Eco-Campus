class AuthSession {
  AuthSession({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.campusId,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String campusId;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      id: json["id"]?.toString() ?? "",
      fullName: json["fullName"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      role: json["role"]?.toString() ?? "USER",
      campusId: json["campusId"]?.toString() ?? "",
    );
  }
}