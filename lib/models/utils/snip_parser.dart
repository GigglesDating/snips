import 'package:flutter/foundation.dart';
import '../../models/snips_model.dart';
import 'comments_parser.dart' as comments_parser;
import 'dart:collection';

class ParseResult<T> {
  final T data;
  final DateTime timestamp;
  final bool isError;
  final String? errorMessage;

  ParseResult({
    required this.data,
    required this.timestamp,
    this.isError = false,
    this.errorMessage,
  });

  bool get isValid => !isError && data != null;
}

class ParserAnalytics {
  final int parseAttempts;
  final int parseErrors;
  final double averageParseTime;
  final Map<String, int> errorTypes;
  final DateTime timestamp;

  ParserAnalytics({
    this.parseAttempts = 0,
    this.parseErrors = 0,
    this.averageParseTime = 0.0,
    Map<String, int>? errorTypes,
    DateTime? timestamp,
  }) : errorTypes = errorTypes ?? {},
       timestamp = timestamp ?? DateTime.now();

  ParserAnalytics copyWith({
    int? parseAttempts,
    int? parseErrors,
    double? averageParseTime,
    Map<String, int>? errorTypes,
    DateTime? timestamp,
  }) {
    return ParserAnalytics(
      parseAttempts: parseAttempts ?? this.parseAttempts,
      parseErrors: parseErrors ?? this.parseErrors,
      averageParseTime: averageParseTime ?? this.averageParseTime,
      errorTypes: errorTypes ?? this.errorTypes,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class SnipParser {
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // LRU Cache for parse results
  static final LinkedHashMap<String, ParseResult<dynamic>> _parseCache =
      LinkedHashMap();

  // Analytics tracking
  static ParserAnalytics _analytics = ParserAnalytics();

  // Get current analytics
  static ParserAnalytics get analytics => _analytics;

  // Update analytics with new parse attempt
  static void _updateAnalytics(Duration parseTime, [String? errorType]) {
    final newAttempts = _analytics.parseAttempts + 1;
    final newErrors =
        errorType != null ? _analytics.parseErrors + 1 : _analytics.parseErrors;

    final newAvgTime =
        (_analytics.averageParseTime * (_analytics.parseAttempts) +
            parseTime.inMilliseconds) /
        newAttempts;

    final newErrorTypes = Map<String, int>.from(_analytics.errorTypes);
    if (errorType != null) {
      newErrorTypes.update(errorType, (count) => count + 1, ifAbsent: () => 1);
    }

    _analytics = _analytics.copyWith(
      parseAttempts: newAttempts,
      parseErrors: newErrors,
      averageParseTime: newAvgTime,
      errorTypes: newErrorTypes,
      timestamp: DateTime.now(),
    );
  }

  // Cache management
  static void _addToCache<T>(
    String key,
    T data, {
    bool isError = false,
    String? errorMessage,
  }) {
    if (_parseCache.length >= _maxCacheSize) {
      _parseCache.remove(_parseCache.keys.first);
    }

    _parseCache[key] = ParseResult<T>(
      data: data,
      timestamp: DateTime.now(),
      isError: isError,
      errorMessage: errorMessage,
    );
  }

  static ParseResult<T>? _getFromCache<T>(String key) {
    final result = _parseCache[key];
    if (result == null) return null;

    if (DateTime.now().difference(result.timestamp) > _cacheExpiry) {
      _parseCache.remove(key);
      return null;
    }

    return result as ParseResult<T>;
  }

  // Parse comments with caching and error recovery
  static Future<List<comments_parser.Comment>> parseComments(
    Map<String, dynamic> commentsData,
  ) async {
    final cacheKey = 'comments_${commentsData.hashCode}';
    final stopwatch = Stopwatch()..start();

    try {
      // Check cache first
      final cached = _getFromCache<List<comments_parser.Comment>>(cacheKey);
      if (cached != null && cached.isValid) {
        return cached.data;
      }

      // Parse in isolate
      final result = await compute(_parseCommentsSync, commentsData);

      stopwatch.stop();
      _updateAnalytics(stopwatch.elapsed);

      // Cache successful result
      _addToCache(cacheKey, result);

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _updateAnalytics(stopwatch.elapsed, 'comment_parse_error');

      debugPrint('Error parsing comments: $e');
      debugPrint('Stack trace: $stackTrace');

      // Cache error result
      final fallbackResult = _handleCommentParseError(commentsData);
      _addToCache(
        cacheKey,
        fallbackResult,
        isError: true,
        errorMessage: e.toString(),
      );

      return fallbackResult;
    }
  }

  // Error recovery for comments
  static List<comments_parser.Comment> _handleCommentParseError(
    Map<String, dynamic> data,
  ) {
    try {
      // Attempt to salvage partial data
      final commentsList = data['comments'] as List?;
      if (commentsList != null) {
        return commentsList
            .whereType<Map<String, dynamic>>()
            .map((comment) {
              try {
                return comments_parser.Comment.fromJson(comment);
              } catch (_) {
                return null;
              }
            })
            .whereType<comments_parser.Comment>()
            .toList();
      }
    } catch (_) {
      // If all recovery attempts fail, return empty list
    }
    return [];
  }

  // Parse snip response with caching and error recovery
  static Future<Map<String, dynamic>> parseSnipResponse(
    Map<String, dynamic> responseData,
  ) async {
    final cacheKey = 'snip_${responseData.hashCode}';
    final stopwatch = Stopwatch()..start();

    try {
      // Check cache first
      final cached = _getFromCache<Map<String, dynamic>>(cacheKey);
      if (cached != null && cached.isValid) {
        return cached.data;
      }

      // Parse in isolate
      final result = await compute(_parseSnipResponseSync, responseData);

      stopwatch.stop();
      _updateAnalytics(stopwatch.elapsed);

      // Cache successful result
      _addToCache(cacheKey, result);

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _updateAnalytics(stopwatch.elapsed, 'snip_parse_error');

      debugPrint('Error parsing snip response: $e');
      debugPrint('Stack trace: $stackTrace');

      // Cache error result
      final fallbackResult = _handleSnipParseError(responseData);
      _addToCache(
        cacheKey,
        fallbackResult,
        isError: true,
        errorMessage: e.toString(),
      );

      return fallbackResult;
    }
  }

  // Error recovery for snip response
  static Map<String, dynamic> _handleSnipParseError(Map<String, dynamic> data) {
    try {
      // Attempt to salvage partial data
      if (data['data'] != null && data['data'] is Map<String, dynamic>) {
        final snipsData = data['data'] as Map<String, dynamic>;
        final snipsList = snipsData['snips'] as List?;

        if (snipsList != null) {
          final validSnips =
              snipsList
                  .whereType<Map<String, dynamic>>()
                  .map((snip) {
                    try {
                      return SnipModel.fromJson(snip);
                    } catch (_) {
                      return null;
                    }
                  })
                  .whereType<SnipModel>()
                  .toList();

          return {
            'status': 'partial_success',
            'data': {
              'snips': validSnips,
              'has_more': snipsData['has_more'] ?? false,
              'next_page': snipsData['next_page'],
              'total_snips': validSnips.length,
            },
          };
        }
      }
    } catch (_) {
      // If all recovery attempts fail, return error response
    }

    return {
      'status': 'error',
      'message': 'Failed to parse snips with recovery',
      'data': {
        'snips': [],
        'has_more': false,
        'next_page': null,
        'total_snips': 0,
      },
    };
  }

  // Parse snip comments with caching
  static Future<Map<String, dynamic>> parseSnipComments(
    Map<String, dynamic> commentsData,
    String snipId,
  ) async {
    final cacheKey = 'snip_comments_${snipId}_${commentsData.hashCode}';
    final stopwatch = Stopwatch()..start();

    try {
      // Check cache first
      final cached = _getFromCache<Map<String, dynamic>>(cacheKey);
      if (cached != null && cached.isValid) {
        return cached.data;
      }

      // Add content type for snips
      if (commentsData['data'] != null &&
          commentsData['data']['comments'] != null) {
        final commentsList = commentsData['data']['comments'] as List;
        for (var comment in commentsList) {
          comment['content_type'] = 'snip';
          comment['content_id'] = snipId;
        }
      }

      // Use the comments parser
      final result = comments_parser.Comment.parseFromApi(commentsData);

      stopwatch.stop();
      _updateAnalytics(stopwatch.elapsed);

      // Cache successful result
      _addToCache(cacheKey, result);

      return result;
    } catch (e) {
      stopwatch.stop();
      _updateAnalytics(stopwatch.elapsed, 'snip_comments_parse_error');

      debugPrint('Error parsing snip comments: $e');

      // Cache error result
      final fallbackResult = {
        'status': 'error',
        'message': 'Failed to parse comments: $e',
        'data': {'comments': [], 'total_comments': 0},
      };

      _addToCache(
        cacheKey,
        fallbackResult,
        isError: true,
        errorMessage: e.toString(),
      );

      return fallbackResult;
    }
  }

  // Helper method to format timestamps
  static String getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  // Synchronous parsing for compute isolation
  static List<comments_parser.Comment> _parseCommentsSync(
    Map<String, dynamic> data,
  ) {
    final commentsList = data['comments'] as List;
    return commentsList
        .map(
          (comment) =>
              comments_parser.Comment.fromJson(comment as Map<String, dynamic>),
        )
        .toList();
  }

  // Synchronous parsing for compute isolation
  static Map<String, dynamic> _parseSnipResponseSync(
    Map<String, dynamic> data,
  ) {
    try {
      if (data['status'] != 'success' || data['data'] == null) {
        return {
          'status': 'error',
          'message': 'Invalid snip response format',
          'data': null,
        };
      }

      final snipsData = data['data'] as Map<String, dynamic>;
      final snips =
          (snipsData['snips'] as List)
              .map((snip) => SnipModel.fromJson(snip as Map<String, dynamic>))
              .toList();

      return {
        'status': 'success',
        'data': {
          'snips': snips,
          'has_more': snipsData['has_more'] ?? false,
          'next_page': snipsData['next_page'],
          'total_snips': snipsData['total_snips'] ?? 0,
        },
      };
    } catch (e, stackTrace) {
      debugPrint('Error in _parseSnipResponseSync: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'status': 'error',
        'message': 'Failed to parse snips: $e',
        'data': null,
      };
    }
  }
}
