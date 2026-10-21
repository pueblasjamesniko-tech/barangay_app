import 'dart:async';

import 'package:dio/dio.dart';
import 'config.dart';
import 'device_service.dart';
import 'json.dart';

class ApiResult {
  final bool ok;
  final int httpStatus;
  final String message;
  final dynamic data;
  final String? token;
  const ApiResult({
    required this.ok,
    required this.httpStatus,
    required this.message,
    this.data,
    this.token,
  });
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    // Never throw on 400/403/500: the API puts a readable message in the body.
    validateStatus: (s) => s != null && s < 600,
  ));

  void Function()? onUnauthorized;

  // ---- session token ----
  // Setting a token starts the heartbeat that keeps this phone's session alive.
  // Clearing it (logout / expired) tells the server so the account is freed.
  String? _token;
  Timer? _heartbeat;

  String? get token => _token;

  set token(String? value) {
    final old = _token;
    _token = value;
    _heartbeat?.cancel();
    _heartbeat = null;

    if (value != null) {
      _ping();
      _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) => _ping());
    } else if (old != null) {
      _logoutOnServer(old);
    }
  }

  /// A 401 here means the session was replaced or expired; _run() then calls onUnauthorized.
  Future<void> _ping() async {
    if (_token == null) return;
    await postJson('/api/Login/heartbeat');
  }

  /// Fire and forget; uses the old token because _token is already cleared.
  Future<void> _logoutOnServer(String oldToken) async {
    try {
      await _dio.post<dynamic>(
        '/api/Login/logout',
        options: Options(headers: {'Authorization': 'Bearer $oldToken'}),
      );
    } catch (_) {}
  }

  Options _options() => Options(
      headers: _token == null ? null : {'Authorization': 'Bearer $_token'});

  static bool _isLoginPath(String p) =>
      p.toLowerCase().replaceAll(RegExp(r'^/+|/+$'), '') == 'api/login';

  Future<ApiResult> get(String path) =>
      _run(() => _dio.get<dynamic>(path, options: _options()));

  Future<ApiResult> postJson(String path, [Object? body]) async {
    var payload = body;
    // The login request always carries this phone's id and name.
    if (_isLoginPath(path) && body is Map) {
      payload = {
        ...body,
        'deviceId': await DeviceService.id(),
        'deviceName': await DeviceService.name(),
      };
    }
    return _run(
        () => _dio.post<dynamic>(path, data: payload, options: _options()));
  }

  Future<ApiResult> putJson(String path, Object body) =>
      _run(() => _dio.put<dynamic>(path, data: body, options: _options()));

  Future<ApiResult> delete(String path) =>
      _run(() => _dio.delete<dynamic>(path, options: _options()));

  Future<ApiResult> postForm(String path, FormData form) =>
      _run(() => _dio.post<dynamic>(path, data: form, options: _options()));

  Future<ApiResult> _run(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final code = res.statusCode ?? 0;
      final raw = res.data;

      Map<String, dynamic>? m;
      if (raw is Map) m = norm(raw) as Map<String, dynamic>;

      if (code == 401) {
        // Token expired (the API issues 60-minute tokens), invalid, or the account
        // was logged in on another device
        if (_token != null) onUnauthorized?.call();
        return const ApiResult(
          ok: false,
          httpStatus: 401,
          message: 'Your session has expired. Please log in again.',
        );
      }

      final ok = code >= 200 && code < 300;
      return ApiResult(
        ok: ok,
        httpStatus: code,
        message: _message(m, code, ok),
        data: m?['data'],
        token: m?['token']?.toString(),
      );
    } on DioException {
      return ApiResult(
        ok: false,
        httpStatus: 0,
        message: 'Cannot reach the server (${AppConfig.baseUrl}).\n'
            'Make sure the API is running, the firewall allows it, '
            'and both devices are on the same hotspot.',
      );
    } catch (e) {
      return ApiResult(
          ok: false, httpStatus: 0, message: 'Something went wrong: $e');
    }
  }

  String _message(Map<String, dynamic>? m, int code, bool ok) {
    final msg = m?['message'];
    if (msg is String && msg.trim().isNotEmpty) return msg;

    // Automatic [ApiController] validation errors: { errors: { Field: [messages] } }
    final errors = m?['errors'];
    if (errors is Map) {
      final all = errors.values
          .expand<dynamic>((v) => v is List ? v : [v])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (all.isNotEmpty) return all.join('\n');
    }
    final title = m?['title'];
    if (title is String && title.isNotEmpty) return title;

    if (ok) return 'Success';
    switch (code) {
      case 404:
        return 'Not found.';
      case 413:
        return 'The file is too large.';
      case 500:
        return 'Server error. Please try again.';
      default:
        return 'Request failed ($code).';
    }
  }
}
