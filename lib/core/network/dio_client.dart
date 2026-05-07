import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class DioClient {
  DioClient._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.addAll([
      _TokenInterceptor(),
      LogInterceptor(requestBody: false, responseBody: false),
    ]);

  static Dio get dio => _dio;

  static Future<Map<String, dynamic>?> refreshToken(
      String refreshToken) async {
    try {
      final response = await _dio.post(
        AppConfig.refreshTokenUrl,
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': ''}),
      );
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}

class _TokenInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getToken();
    if (token != null && options.headers['Authorization'] != '') {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final refresh = await SecureStorage.getRefreshToken();
      if (refresh != null) {
        final data = await DioClient.refreshToken(refresh);
        final newToken = data?['token'] as String?;
        if (newToken != null) {
          await SecureStorage.saveTokens(newToken, refresh);
          final options = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newToken';
          try {
            final response = await DioClient.dio.fetch(options);
            return handler.resolve(response);
          } catch (_) {}
        }
      }
    }
    handler.next(err);
  }
}
