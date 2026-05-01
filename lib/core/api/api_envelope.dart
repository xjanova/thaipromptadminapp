/// Standard API response envelope จาก backend admin API
///
/// Backend คืน { success, data?, message?, errors?, error_code? }
class ApiEnvelope<T> {
  ApiEnvelope({
    required this.success,
    this.data,
    this.message,
    this.errors,
    this.errorCode,
  });

  final bool success;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;
  final String? errorCode;

  static ApiEnvelope<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(dynamic data)? dataParser,
  ) {
    final raw = json['data'];
    return ApiEnvelope<T>(
      success: json['success'] == true,
      data: raw == null ? null : (dataParser != null ? dataParser(raw) : raw as T),
      message: json['message'] as String?,
      errors: (json['errors'] as Map?)?.cast<String, dynamic>(),
      errorCode: json['error_code'] as String?,
    );
  }
}

/// Exception สำหรับ API error (จะถูก throw จาก ApiClient เมื่อ HTTP != 2xx
/// หรือ envelope.success == false)
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
    this.errorCode,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;
  final String? errorCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
