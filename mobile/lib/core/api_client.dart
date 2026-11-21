import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'session.dart';

/// Dio HTTP client with JWT bearer auth + transparent access-token refresh.
class ApiClient {
  ApiClient(this._ref, {required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(minutes: 2),
        headers: {'Accept': 'application/json'},
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    _dio.interceptors.add(_authInterceptor());
  }

  final Ref _ref;
  late final Dio _dio;

  Dio get dio => _dio;

  void updateBaseUrl(String url) {
    final base = url.endsWith('/api') ? url : '$url/api';
    _dio.options.baseUrl = base;
  }

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final tokens = _ref.read(tokensProvider);
        if (tokens?.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${tokens!.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        // Retry once per request only, so a perpetually-rejected access token
        // can never loop forever (infinite spinner protection).
        final retried = error.requestOptions.extra['__cmRetried'] == true;
        if (status == 401 && !retried) {
          final ok = await _tryRefresh();
          if (ok) {
            error.requestOptions.extra['__cmRetried'] = true;
            final retryRes = await _retry(error.requestOptions);
            return handler.resolve(retryRes);
          }
          _ref.read(sessionProvider.notifier).logout();
        }
        handler.next(error);
      },
    );
  }

  Future<bool> _tryRefresh() async {
    final tokens = _ref.read(tokensProvider);
    if (tokens?.refreshToken == null) return false;
    try {
      final res = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (code) => code != null && code < 500,
        ),
      ).post(
        '${_dio.options.baseUrl}/auth/refresh',
        data: {'refreshToken': tokens!.refreshToken},
      );
      if (res.statusCode == 200) {
        final newTokens = AuthTokens(
          accessToken: res.data['accessToken'] as String,
          refreshToken: res.data['refreshToken'] as String,
        );
        await _ref.read(sessionProvider.notifier).saveTokens(newTokens, res.data['user'] as Map<String, dynamic>);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final tokens = _ref.read(tokensProvider);
    requestOptions.headers['Authorization'] = 'Bearer ${tokens!.accessToken}';
    // Upload requests must be reset (the stream was consumed).
    return _dio.fetch(requestOptions);
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response> post(String path, {Object? data, Map<String, dynamic>? query}) =>
      _dio.post(path, data: data, queryParameters: query);

  Future<Response> patch(String path, {Object? data}) => _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref, baseUrl: ref.read(baseUrlProvider));
});

final baseUrlProvider =
    StateProvider<String>((ref) => SessionStorage.getString('baseUrl') ?? AppConfig.defaultApiBaseUrl);
