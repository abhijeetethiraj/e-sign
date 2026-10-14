import 'package:dio/dio.dart';
import '../../services/preferences_service.dart';
import 'api_endpoints.dart';

/// Central HTTP Client powered by Dio.
/// Handles BaseOptions, timeouts, and automatic Bearer Token injection.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio dio;

  factory ApiClient() => _instance;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Auth Interceptor: Automatically injects JWT token into headers
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final String? token = await PreferencesService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Can handle 401 token expiry here if needed
          return handler.next(error);
        },
      ),
    );
  }
}
