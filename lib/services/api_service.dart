import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../network/config.dart';
import 'cache_serivce.dart';

// Custom exception for API errors
class ApiError implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiError(this.message, {this.statusCode, this.data});

  @override
  String toString() =>
      'ApiError: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

// Token for cancelling requests
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final http.Client _client;
  final List<Function(Map<String, dynamic>)> _requestInterceptors = [];
  final List<Function(Map<String, dynamic>)> _responseInterceptors = [];
  final Map<String, CancelToken> _activeRequests = {};

  ApiService._internal() {
    // Ensure background isolate messenger is initialized
    final rootIsolateToken = RootIsolateToken.instance;
    if (rootIsolateToken != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    }

    // In development, use a client that accepts self-signed certificates
    if (kDebugMode) {
      final httpClient =
          HttpClient()
            ..badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;
      _client = IOClient(httpClient);
    } else {
      _client = http.Client();
    }
  }

  // Add request interceptor
  void addRequestInterceptor(Function(Map<String, dynamic>) interceptor) {
    _requestInterceptors.add(interceptor);
  }

  // Add response interceptor
  void addResponseInterceptor(Function(Map<String, dynamic>) interceptor) {
    _responseInterceptors.add(interceptor);
  }

  // Generate cache key from request details
  String _generateCacheKey(String endpoint, Map<String, dynamic> body) {
    return '${endpoint}_${json.encode(body)}';
  }

  // Check if response is HTML
  bool _isHtmlResponse(String body) {
    return body.trim().toLowerCase().startsWith('<!doctype html') ||
        body.trim().toLowerCase().startsWith('<html');
  }

  // Sign request (implement your signing logic)
  String _signRequest(Map<String, dynamic> body) {
    // TODO: Implement request signing
    return '';
  }

  // Validate response (implement your validation logic)
  bool _validateResponse(Map<String, dynamic> response) {
    // TODO: Implement response validation
    return true;
  }

  // Make API call with caching
  Future<Map<String, dynamic>> makeRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    Duration? cacheDuration,
    bool forceRefresh = false,
    String? requestId,
  }) async {
    // Check for cancellation
    if (requestId != null) {
      if (_activeRequests[requestId]?.isCancelled ?? false) {
        throw ApiError('Request cancelled');
      }
      _activeRequests[requestId]?.cancel();
      _activeRequests[requestId] = CancelToken();
    }

    final cacheKey = _generateCacheKey(endpoint, body);

    try {
      // Check cache first if not forcing refresh and caching is enabled
      if (!forceRefresh && cacheDuration != null) {
        try {
          final cachedData = await CacheService.getCachedData(cacheKey);
          if (cachedData != null) {
            debugPrint('Cache hit for $endpoint');
            return cachedData;
          }
        } catch (e) {
          debugPrint('Cache error, proceeding with API call: $e');
        }
      }

      // Apply request interceptors
      final interceptedBody = Map<String, dynamic>.from(body);
      for (var interceptor in _requestInterceptors) {
        interceptor(interceptedBody);
      }

      // Add request signature
      final signature = _signRequest(interceptedBody);
      if (signature.isNotEmpty) {
        interceptedBody['signature'] = signature;
      }

      // Make API call
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              ...ApiConfig.headers,
              'X-Requested-With': 'XMLHttpRequest',
              'Accept': 'application/json',
            },
            body: json.encode(interceptedBody),
          )
          .timeout(Duration(milliseconds: ApiConfig.connectionTimeout));

      // Check for HTML response
      if (_isHtmlResponse(response.body)) {
        throw ApiError(
          'Received HTML response instead of JSON. Possible authentication issue.',
        );
      }

      // Parse response
      final decodedResponse = json.decode(response.body);

      // Apply response interceptors
      final interceptedResponse = Map<String, dynamic>.from(decodedResponse);
      for (var interceptor in _responseInterceptors) {
        interceptor(interceptedResponse);
      }

      // Validate response
      if (!_validateResponse(interceptedResponse)) {
        throw ApiError('Invalid response format');
      }

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw ApiError(
          decodedResponse['message'] ?? 'Unknown error',
          statusCode: response.statusCode,
          data: decodedResponse,
        );
      }

      // Try to cache successful responses if caching is enabled
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          cacheDuration != null) {
        try {
          await CacheService.cacheData(
            key: cacheKey,
            data: interceptedResponse,
            duration: cacheDuration,
          );
        } catch (e) {
          debugPrint('Failed to cache response: $e');
        }
      }

      return interceptedResponse;
    } catch (e) {
      debugPrint('API Error for $endpoint: $e');

      // Try cache again in case of network error
      if (cacheDuration != null) {
        try {
          final cachedData = await CacheService.getCachedData(cacheKey);
          if (cachedData != null) {
            debugPrint('Using cached data after error for $endpoint');
            return {...cachedData, 'fromCache': true, 'error': e.toString()};
          }
        } catch (cacheError) {
          debugPrint('Cache error during fallback: $cacheError');
        }
      }

      throw ApiError('Failed to connect to server', data: e.toString());
    } finally {
      // Clean up request token
      if (requestId != null) {
        _activeRequests.remove(requestId);
      }
    }
  }

  // Batch multiple API calls
  Future<List<Map<String, dynamic>>> batchRequests({
    required List<Map<String, dynamic>> requests,
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    final futures = requests.map(
      (request) => makeRequest(
        endpoint: request['endpoint'],
        body: request['body'],
        cacheDuration: cacheDuration,
        forceRefresh: forceRefresh,
        requestId: request['requestId'],
      ),
    );

    return await Future.wait(futures);
  }

  // Cancel a specific request
  void cancelRequest(String requestId) {
    _activeRequests[requestId]?.cancel();
  }

  // Clean up resources
  void dispose() {
    _client.close();
    _activeRequests.clear();
  }
}
