import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_header_provider.dart';

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://app.hostborneo.org/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // 1. Logging Interceptor bawaan Dio untuk print raw traffic
  dio.interceptors.add(
    LogInterceptor(
      request: true,
      requestHeader: true, // Mencetak SEMUA headers yang dikirim
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('[DIO_LOG] $obj'),
    ),
  );

  // 2. Auth & Signature Interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final headers = await ApiHeaderProvider.buildHeaders();
        options.headers.addAll(headers);

        // Cetak verifikasi sebelum benar-benar terbang ke jaringan
        print('====== RAW HEADERS SENT BY DIO ======');
        options.headers.forEach((k, v) {
          print('$k: $v');
        });
        print('=====================================');

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('[DIO_ERR] Status Code: ${e.response?.statusCode}');
        print('[DIO_ERR] Response Data: ${e.response?.data}');
        return handler.next(e);
      },
    ),
  );

  return dio;
}
