import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../storage/secure_storage.dart';
import 'api_envelope.dart';

/// Default base URL สำหรับ Admin API
///
/// Production: https://main.thaiprompt.online/api/admin
/// Override ผ่าน --dart-define=API_BASE_URL=...
const String _defaultBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'https://main.thaiprompt.online/api/admin');

/// Dio instance พร้อม interceptors:
/// - แนบ Bearer token อัตโนมัติ
/// - Log request ใน debug mode
/// - แปลง response error เป็น ApiException
class ApiClient {
  ApiClient({String? baseUrl}) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // ส่ง Accept-Language ตาม locale ของอุปกรณ์
        options.headers['Accept-Language'] = options.headers['Accept-Language'] ?? 'th';
        handler.next(options);
      },
      onError: (err, handler) {
        handler.next(err);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
        maxWidth: 100,
      ));
    }
  }

  final Dio _dio;

  Dio get dio => _dio;

  /// GET helper ที่ unwrap envelope แล้ว
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    return _unwrap<T>(res, parser);
  }

  /// POST helper ที่ unwrap envelope แล้ว
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: query,
    );
    return _unwrap<T>(res, parser);
  }

  T _unwrap<T>(Response<Map<String, dynamic>> res, T Function(dynamic)? parser) {
    final json = res.data ?? const {};
    final envelope = ApiEnvelope.fromJson<dynamic>(json, parser);

    if (!envelope.success || (res.statusCode != null && res.statusCode! >= 400)) {
      throw ApiException(
        statusCode: res.statusCode ?? 0,
        message: envelope.message ?? 'Unknown error',
        errors: envelope.errors,
        errorCode: envelope.errorCode,
      );
    }

    return envelope.data as T;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
