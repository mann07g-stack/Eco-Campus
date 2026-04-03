import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../config/app_config.dart";
import "../models/auth_session.dart";
import "../models/request_model.dart";

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: "accessToken", value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: "accessToken");
  }

  Future<String?> getToken() => _storage.read(key: "accessToken");

  Future<AuthSession> registerStudent({
    required String fullName,
    required String email,
    required String phone,
    required String campusId,
    required String password,
  }) async {
    final response = await _dio.post(
      "/auth/register-user",
      data: {
        "fullName": fullName,
        "email": email,
        "phone": phone,
        "campusId": campusId,
        "password": password,
      },
    );

    return AuthSession.fromJson(response.data["user"] as Map<String, dynamic>);
  }

  Future<Response<dynamic>> login({required String email, required String password}) async {
    final response = await _dio.post("/auth/login", data: {
      "email": email,
      "password": password,
    });

    final token = response.data["accessToken"]?.toString();
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }

    return response;
  }

  Future<List<WasteRequest>> getMyRequests() async {
    final token = await getToken();
    final response = await _dio.get(
      "/requests/my",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    final list = (response.data["requests"] as List<dynamic>? ?? [])
        .map((item) => WasteRequest.fromJson(item as Map<String, dynamic>))
        .toList();

    return list;
  }

  Future<List<WasteRequest>> getMemberHistory() async {
    final token = await getToken();
    final response = await _dio.get(
      "/member/history",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    return (response.data["requests"] as List<dynamic>? ?? [])
        .map((item) => WasteRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WasteRequest>> getMemberAssignedRequests() async {
    final token = await getToken();
    final response = await _dio.get(
      "/member/assigned",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    return (response.data["requests"] as List<dynamic>? ?? [])
        .map((item) => WasteRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRequest({
    required List<String> imageUrls,
    required String description,
    required List<String> categories,
  }) async {
    final token = await getToken();
    await _dio.post(
      "/requests",
      data: {
        "imageUrl": imageUrls.isNotEmpty ? imageUrls.first : "",
        "imageUrls": imageUrls,
        "description": description,
        "categoriesDetected": categories,
      },
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<void> counterOffer({required String requestId, required double amount, String message = ""}) async {
    final token = await getToken();
    await _dio.patch(
      "/requests/$requestId/counter-offer",
      data: {
        "amount": amount,
        "message": message,
      },
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<void> acceptQuote(String requestId) async {
    final token = await getToken();
    await _dio.patch(
      "/requests/$requestId/accept-quote",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<void> cancelRequest(String requestId, {String reason = "Cancelled by user"}) async {
    final token = await getToken();
    await _dio.patch(
      "/requests/$requestId/cancel",
      data: {"reason": reason},
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<String> getQrToken(String requestId) async {
    final token = await getToken();
    final response = await _dio.get(
      "/requests/$requestId/qr",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data["qrToken"]?.toString() ?? "";
  }

  Future<void> memberScanQr(String qrToken) async {
    final token = await getToken();
    await _dio.post(
      "/member/scan",
      data: {"qrToken": qrToken},
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }
}
