import "dart:convert";

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

  bool _isConnectivityError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  Future<T> _withBaseUrlFallback<T>(Future<T> Function() call) async {
    Object? lastError;

    for (final baseUrl in AppConfig.apiBaseUrlCandidates) {
      _dio.options.baseUrl = baseUrl;
      try {
        return await call();
      } on DioException catch (error) {
        lastError = error;
        if (!_isConnectivityError(error)) {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw DioException(
      requestOptions: RequestOptions(path: ""),
      type: DioExceptionType.unknown,
      error: "No API base URL candidates available.",
    );
  }

  Future<Response<T>> _get<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _withBaseUrlFallback(() => _dio.get<T>(path, data: data, options: options));
  }

  Future<Response<T>> _getWithRetry<T>(
    String path, {
    Object? data,
    Options? options,
    int attempts = 2,
  }) async {
    DioException? lastError;

    for (var i = 0; i < attempts; i++) {
      try {
        return await _get<T>(path, data: data, options: options);
      } on DioException catch (error) {
        lastError = error;
        if (!_isConnectivityError(error) || i == attempts - 1) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.unknown,
        );
  }

  Future<Response<T>> _post<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _withBaseUrlFallback(() => _dio.post<T>(path, data: data, options: options));
  }

  Future<Response<T>> _patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _withBaseUrlFallback(() => _dio.patch<T>(path, data: data, options: options));
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: "accessToken", value: token);
  }

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(
      key: "authSession",
      value: jsonEncode({
        "id": session.id,
        "fullName": session.fullName,
        "email": session.email,
        "role": session.role,
        "campusId": session.campusId,
      }),
    );
  }

  Future<AuthSession?> getSession() async {
    final raw = await _storage.read(key: "authSession");
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return AuthSession.fromJson(map);
      }
      if (map is Map) {
        return AuthSession.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: "accessToken");
    await _storage.delete(key: "authSession");
  }

  Future<String?> getToken() => _storage.read(key: "accessToken");

  Future<AuthSession> registerStudent({
    required String fullName,
    required String email,
    required String phone,
    required String campusId,
    required String password,
  }) async {
    final response = await _post(
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
    final response = await _post("/auth/login", data: {
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
    final response = await _getWithRetry(
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
    final response = await _getWithRetry(
      "/member/history",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    return (response.data["requests"] as List<dynamic>? ?? [])
        .map((item) => WasteRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WasteRequest>> getMemberAssignedRequests() async {
    final token = await getToken();
    final response = await _getWithRetry(
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
    await _post(
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
    await _patch(
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
    await _patch(
      "/requests/$requestId/accept-quote",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<void> cancelRequest(String requestId, {String reason = "Cancelled by user"}) async {
    final token = await getToken();
    await _patch(
      "/requests/$requestId/cancel",
      data: {"reason": reason},
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<String> getQrToken(String requestId) async {
    final token = await getToken();
    final response = await _get(
      "/requests/$requestId/qr",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data["qrToken"]?.toString() ?? "";
  }

  Future<void> memberScanQr(String qrToken) async {
    final token = await getToken();
    await _post(
      "/member/scan",
      data: {"qrToken": qrToken},
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }
}
