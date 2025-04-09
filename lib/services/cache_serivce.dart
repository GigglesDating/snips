import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/utils/snip_cache_manager.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

class CacheService {
  static const String apiCacheBox = 'apiCache';
  static const Duration defaultCacheDuration = Duration(hours: 1);
  static SnipCacheManager? _snipCacheManager;
  static bool _isInitialized = false;
  static Box? _apiCacheBox;
  static Future<void>? _initFuture;
  static bool _isInitializing = false;
  static int _initializationAttempts = 0;
  static const int _maxInitializationAttempts = 3;
  static bool _useFallbackMode = false;
  static Map<String, dynamic> _fallbackCache = {};

  // Initialize Hive and open boxes
  static Future<void> init() async {
    if (_isInitialized) return;

    // If initialization is in progress, wait for it
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    // Prevent multiple simultaneous initialization attempts
    if (_isInitializing) {
      debugPrint('CacheService initialization already in progress, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
      return init(); // Retry after a short delay
    }

    _isInitializing = true;
    _initFuture = _initializeCache();

    try {
      await _initFuture;
    } finally {
      _initFuture = null;
      _isInitializing = false;
    }
  }

  static Future<void> _initializeCache() async {
    _initializationAttempts++;

    try {
      // Ensure background isolate messenger is initialized
      final rootIsolateToken = RootIsolateToken.instance;
      if (rootIsolateToken != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        debugPrint(
          'BackgroundIsolateBinaryMessenger initialized in SnipCacheManager',
        );
      } else {
        debugPrint('Warning: RootIsolateToken is null in CacheService');
        // Continue with fallback mode
        _useFallbackMode = true;
        _isInitialized = true;
        return;
      }

      // Get application documents directory with error handling
      final appDir = await path_provider.getApplicationDocumentsDirectory();
      if (appDir.path.isEmpty) {
        throw Exception('Application documents directory path is empty');
      }

      debugPrint('Initializing Hive with path: ${appDir.path}');
      await Hive.initFlutter(appDir.path);

      // Open box and store reference
      _apiCacheBox = await Hive.openBox(apiCacheBox);
      _snipCacheManager = SnipCacheManager();
      _isInitialized = true;
      _initializationAttempts = 0; // Reset attempts counter on success
      debugPrint('CacheService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing CacheService: $e');

      // If we haven't exceeded max attempts, try to recover
      if (_initializationAttempts < _maxInitializationAttempts) {
        debugPrint(
          'Attempting to recover CacheService (attempt $_initializationAttempts)',
        );
        try {
          // Try to delete and recreate the box
          await Hive.deleteBoxFromDisk(apiCacheBox);
          _apiCacheBox = await Hive.openBox(apiCacheBox);
          _snipCacheManager = SnipCacheManager();
          _isInitialized = true;
          _initializationAttempts = 0; // Reset attempts counter on success
          debugPrint('CacheService recovered after error');
        } catch (recoveryError) {
          debugPrint('Failed to recover CacheService: $recoveryError');
          // Switch to fallback mode
          _useFallbackMode = true;
          _isInitialized = true;
          debugPrint('Switching to fallback cache mode');
        }
      } else {
        debugPrint(
          'Fatal error initializing CacheService after $_initializationAttempts attempts',
        );
        // Switch to fallback mode
        _useFallbackMode = true;
        _isInitialized = true;
        debugPrint('Switching to fallback cache mode');
      }
    }
  }

  // Ensure cache is initialized before any operation
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // Cache data with expiration
  static Future<void> cacheData({
    required String key,
    required dynamic data,
    Duration? duration,
  }) async {
    await _ensureInitialized();

    if (_useFallbackMode) {
      // Use in-memory fallback cache
      final expiryTime = DateTime.now().add(duration ?? defaultCacheDuration);
      _fallbackCache[key] = {
        'data': data,
        'expiry': expiryTime.toIso8601String(),
      };
      debugPrint('Cached data in fallback mode for key: $key');
      return;
    }

    if (_apiCacheBox == null) {
      debugPrint('CacheService box not available');
      return;
    }

    try {
      final expiryTime = DateTime.now().add(duration ?? defaultCacheDuration);
      final cacheData = {'data': data, 'expiry': expiryTime.toIso8601String()};

      await _apiCacheBox!.put(key, json.encode(cacheData));
    } catch (e) {
      debugPrint('Error caching data for key $key: $e');
      // Don't rethrow, just log the error
    }
  }

  // Get cached data if not expired
  static Future<dynamic> getCachedData(String key) async {
    await _ensureInitialized();

    if (_useFallbackMode) {
      // Check fallback cache
      final cached = _fallbackCache[key];
      if (cached != null) {
        final expiry = DateTime.parse(cached['expiry']);
        if (DateTime.now().isBefore(expiry)) {
          return cached['data'];
        } else {
          // Clean up expired cache
          _fallbackCache.remove(key);
          return null;
        }
      }
      return null;
    }

    if (_apiCacheBox == null) {
      debugPrint('CacheService box not available');
      return null;
    }

    try {
      final cachedJson = _apiCacheBox!.get(key);
      if (cachedJson == null) return null;

      final cached = json.decode(cachedJson);
      final expiry = DateTime.parse(cached['expiry']);

      if (DateTime.now().isBefore(expiry)) {
        return cached['data'];
      } else {
        // Clean up expired cache
        await _apiCacheBox!.delete(key);
        return null;
      }
    } catch (e) {
      debugPrint('Error reading cache for key $key: $e');
      return null;
    }
  }

  // Clear specific cache
  static Future<void> clearCache(String key) async {
    await _ensureInitialized();

    if (_useFallbackMode) {
      _fallbackCache.remove(key);
      return;
    }

    if (!_isInitialized || _apiCacheBox == null) {
      debugPrint('CacheService not initialized');
      return;
    }

    try {
      await _apiCacheBox!.delete(key);
    } catch (e) {
      debugPrint('Error clearing cache for key $key: $e');
    }
  }

  // Clear all cache
  static Future<void> clearAllCache() async {
    await _ensureInitialized();

    if (_useFallbackMode) {
      _fallbackCache.clear();
      return;
    }

    if (!_isInitialized || _apiCacheBox == null) {
      debugPrint('CacheService not initialized');
      return;
    }

    try {
      await _apiCacheBox!.clear();
      await _snipCacheManager?.emptyCache();
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
    }
  }

  // Clean expired cache entries
  static Future<void> cleanExpiredCache() async {
    await _ensureInitialized();

    if (_useFallbackMode) {
      // Clean expired entries from fallback cache
      final keysToRemove = <String>[];
      for (var key in _fallbackCache.keys) {
        final cached = _fallbackCache[key];
        if (cached != null) {
          try {
            final expiry = DateTime.parse(cached['expiry']);
            if (DateTime.now().isAfter(expiry)) {
              keysToRemove.add(key);
            }
          } catch (e) {
            keysToRemove.add(key);
          }
        }
      }

      for (var key in keysToRemove) {
        _fallbackCache.remove(key);
      }

      debugPrint(
        'Cleaned ${keysToRemove.length} expired entries from fallback cache',
      );
      return;
    }

    if (!_isInitialized || _apiCacheBox == null) {
      debugPrint('CacheService not initialized');
      return;
    }

    try {
      final keys = _apiCacheBox!.keys.toList();
      int cleanedCount = 0;

      for (var key in keys) {
        final cachedJson = _apiCacheBox!.get(key);
        if (cachedJson != null) {
          try {
            final cached = json.decode(cachedJson);
            final expiry = DateTime.parse(cached['expiry']);

            if (DateTime.now().isAfter(expiry)) {
              await _apiCacheBox!.delete(key);
              cleanedCount++;
            }
          } catch (e) {
            debugPrint('Error cleaning cache for key $key: $e');
            await _apiCacheBox!.delete(key);
            cleanedCount++;
          }
        }
      }

      // Clean SnipCacheManager if needed
      await _snipCacheManager?.cleanCacheIfNeeded();

      debugPrint('Cleaned $cleanedCount expired cache entries');
    } catch (e) {
      debugPrint('Error cleaning expired cache: $e');
    }
  }

  // Get combined cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();

    if (_useFallbackMode) {
      return {
        'apiCache': {
          'totalEntries': _fallbackCache.length,
          'validEntries': _fallbackCache.length,
          'expiredEntries': 0,
        },
        'mediaCache': null,
      };
    }

    if (!_isInitialized || _apiCacheBox == null) {
      debugPrint('CacheService not initialized');
      return {};
    }

    try {
      int totalEntries = _apiCacheBox!.length;
      int expiredEntries = 0;
      int validEntries = 0;

      for (var key in _apiCacheBox!.keys) {
        final cachedJson = _apiCacheBox!.get(key);
        if (cachedJson != null) {
          try {
            final cached = json.decode(cachedJson);
            final expiry = DateTime.parse(cached['expiry']);

            if (DateTime.now().isAfter(expiry)) {
              expiredEntries++;
            } else {
              validEntries++;
            }
          } catch (e) {
            expiredEntries++;
          }
        }
      }

      // Get SnipCacheManager analytics
      final snipAnalytics = _snipCacheManager?.analytics;

      return {
        'apiCache': {
          'totalEntries': totalEntries,
          'validEntries': validEntries,
          'expiredEntries': expiredEntries,
        },
        'mediaCache':
            snipAnalytics != null
                ? {
                  'hitCount': snipAnalytics.hitCount,
                  'missCount': snipAnalytics.missCount,
                  'evictionCount': snipAnalytics.evictionCount,
                  'hitRate': snipAnalytics.hitRate,
                  'totalSize': snipAnalytics.totalSize,
                  'itemCount': snipAnalytics.itemCount,
                  'priorityDistribution': snipAnalytics.priorityDistribution,
                }
                : null,
      };
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }

  // Preload media content
  static Future<void> preloadMedia({
    List<String> videoUrls = const [],
    List<String> thumbnailUrls = const [],
    CachePriority priority = CachePriority.medium,
  }) async {
    await _ensureInitialized();

    if (_useFallbackMode || _snipCacheManager == null) {
      debugPrint('Media preloading not available in fallback mode');
      return;
    }

    // Use a microtask to avoid blocking the UI thread
    Future.microtask(() async {
      try {
        // Process videos and thumbnails in parallel
        await Future.wait([
          _preloadVideos(videoUrls, priority),
          _preloadThumbnails(thumbnailUrls),
        ]);
      } catch (e) {
        debugPrint('Error preloading media: $e');
      }
    });
  }

  static Future<void> _preloadVideos(
    List<String> urls,
    CachePriority priority,
  ) async {
    for (var url in urls) {
      try {
        await _snipCacheManager?.preloadVideo(url);
      } catch (e) {
        debugPrint('Error preloading video $url: $e');
      }
    }
  }

  static Future<void> _preloadThumbnails(List<String> urls) async {
    for (var url in urls) {
      try {
        await _snipCacheManager?.preloadThumbnail(url);
      } catch (e) {
        debugPrint('Error preloading thumbnail $url: $e');
      }
    }
  }

  // Clean media cache
  static Future<void> cleanMediaCache() async {
    await _ensureInitialized();

    if (_useFallbackMode || _snipCacheManager == null) {
      debugPrint('Media cache cleaning not available in fallback mode');
      return;
    }

    // Use a microtask to avoid blocking the UI thread
    Future.microtask(() async {
      try {
        await _snipCacheManager?.emptyCache();
      } catch (e) {
        debugPrint('Error cleaning media cache: $e');
      }
    });
  }
}
