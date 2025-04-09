import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:flutter/services.dart';

// Cache priority levels
enum CachePriority {
  low, // Thumbnails, old videos
  medium, // Regular videos
  high, // Currently playing video and next in queue
  urgent, // User explicitly requested content
}

// Cache analytics data
class CacheAnalytics {
  final int hitCount;
  final int missCount;
  final int evictionCount;
  final double hitRate;
  final int totalSize;
  final int itemCount;
  final Map<CachePriority, int> priorityDistribution;
  final DateTime timestamp;

  CacheAnalytics({
    this.hitCount = 0,
    this.missCount = 0,
    this.evictionCount = 0,
    this.hitRate = 0.0,
    this.totalSize = 0,
    this.itemCount = 0,
    Map<CachePriority, int>? priorityDistribution,
    DateTime? timestamp,
  }) : priorityDistribution = priorityDistribution ?? {},
       timestamp = timestamp ?? DateTime.now();

  CacheAnalytics copyWith({
    int? hitCount,
    int? missCount,
    int? evictionCount,
    double? hitRate,
    int? totalSize,
    int? itemCount,
    Map<CachePriority, int>? priorityDistribution,
    DateTime? timestamp,
  }) {
    return CacheAnalytics(
      hitCount: hitCount ?? this.hitCount,
      missCount: missCount ?? this.missCount,
      evictionCount: evictionCount ?? this.evictionCount,
      hitRate: hitRate ?? this.hitRate,
      totalSize: totalSize ?? this.totalSize,
      itemCount: itemCount ?? this.itemCount,
      priorityDistribution: priorityDistribution ?? this.priorityDistribution,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class SnipCacheManager extends CacheManager {
  static const key = 'snipCache';
  static const Duration stalePeriod = Duration(days: 7);
  static const int maxNrOfCacheObjects = 20;
  static const int maxCacheSize = 500 * 1024 * 1024; // 500MB
  static const double _lowDiskSpaceThreshold = 0.1; // 10% free space threshold

  static SnipCacheManager? _instance;

  // Cache analytics
  static CacheAnalytics _analytics = CacheAnalytics();
  static final Map<String, CachePriority> _priorities = {};
  static Timer? _diskMonitorTimer;
  static bool _isPrewarming = false;
  static String? _cacheDir;

  factory SnipCacheManager() {
    _instance ??= SnipCacheManager._();
    return _instance!;
  }

  SnipCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: stalePeriod,
          maxNrOfCacheObjects: maxNrOfCacheObjects,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      ) {
    try {
      // Ensure background isolate messenger is initialized
      final rootIsolateToken = RootIsolateToken.instance;
      if (rootIsolateToken != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        debugPrint(
          'BackgroundIsolateBinaryMessenger initialized in SnipCacheManager',
        );
      } else {
        debugPrint('Warning: RootIsolateToken is null in SnipCacheManager');
      }

      _initialize();
      debugPrint('SnipCacheManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing SnipCacheManager: $e');
      rethrow;
    }

    // Start disk space monitoring
    _startDiskMonitoring();
  }

  // Get current cache analytics
  CacheAnalytics get analytics => _analytics;

  // Start disk space monitoring
  void _startDiskMonitoring() {
    _diskMonitorTimer?.cancel();
    _diskMonitorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkDiskSpace();
    });
  }

  // Check disk space and clean if needed
  Future<void> _checkDiskSpace() async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      final stat = await dir.stat();
      final total = stat.size;
      final free = await _getFreeDiskSpace();

      if (free <= 0 || total <= 0) return;

      final freeRatio = free / total;
      if (freeRatio < _lowDiskSpaceThreshold) {
        debugPrint(
          'Low disk space detected (${(freeRatio * 100).toStringAsFixed(1)}% free)',
        );
        await _cleanupLowPriorityCache();
      }
    } catch (e) {
      debugPrint('Error checking disk space: $e');
    }
  }

  // Get free disk space (platform specific implementation needed)
  Future<int> _getFreeDiskSpace() async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      final stat = await dir.stat();
      return stat.size;
    } catch (e) {
      debugPrint('Error getting free disk space: $e');
      return 0;
    }
  }

  // Clean low priority cache items
  Future<void> _cleanupLowPriorityCache() async {
    try {
      final lowPriorityItems =
          _priorities.entries
              .where((e) => e.value == CachePriority.low)
              .map((e) => e.key)
              .toList();

      for (final key in lowPriorityItems) {
        await removeFile(key);
        _priorities.remove(key);
        _updateAnalytics(evictionCount: _analytics.evictionCount + 1);
      }
    } catch (e) {
      debugPrint('Error cleaning low priority cache: $e');
    }
  }

  // Prewarm cache with frequently accessed content
  Future<void> prewarmCache(
    List<String> urls, {
    CachePriority priority = CachePriority.medium,
    bool force = false,
  }) async {
    if (_isPrewarming && !force) return;

    _isPrewarming = true;
    try {
      await cleanCacheIfNeeded();

      for (final url in urls) {
        final fileInfo = await getFileFromCache(url);
        if (fileInfo == null || !(await _isFileValid(fileInfo))) {
          await preloadWithPriority(url, priority);
        }
      }
    } finally {
      _isPrewarming = false;
    }
  }

  // Preload with priority
  Future<void> preloadWithPriority(String url, CachePriority priority) async {
    if (url.isEmpty) return;

    try {
      final fileInfo = await getFileFromCache(url);
      if (fileInfo != null && await _isFileValid(fileInfo)) {
        _updateAnalytics(hitCount: _analytics.hitCount + 1);
        _priorities[url] = priority;
        return;
      }

      _updateAnalytics(missCount: _analytics.missCount + 1);
      await downloadFile(url);
      _priorities[url] = priority;
    } catch (e) {
      debugPrint('Error preloading with priority: $e');
    }
  }

  // Update analytics
  void _updateAnalytics({
    int? hitCount,
    int? missCount,
    int? evictionCount,
    int? totalSize,
    int? itemCount,
  }) {
    final total =
        (hitCount ?? _analytics.hitCount) + (missCount ?? _analytics.missCount);

    _analytics = _analytics.copyWith(
      hitCount: hitCount ?? _analytics.hitCount,
      missCount: missCount ?? _analytics.missCount,
      evictionCount: evictionCount ?? _analytics.evictionCount,
      hitRate: total > 0 ? (hitCount ?? _analytics.hitCount) / total : 0.0,
      totalSize: totalSize ?? _analytics.totalSize,
      itemCount: itemCount ?? _analytics.itemCount,
      priorityDistribution: Map.fromEntries(
        _priorities.values
            .fold<Map<CachePriority, int>>(
              {},
              (map, priority) =>
                  map
                    ..update(priority, (count) => count + 1, ifAbsent: () => 1),
            )
            .entries,
      ),
      timestamp: DateTime.now(),
    );
  }

  // Override methods to track analytics
  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    final result = await super.getFileFromCache(
      key,
      ignoreMemCache: ignoreMemCache,
    );
    _updateAnalytics(
      hitCount: result != null ? _analytics.hitCount + 1 : _analytics.hitCount,
      missCount:
          result == null ? _analytics.missCount + 1 : _analytics.missCount,
    );
    return result;
  }

  @override
  Future<void> removeFile(String key) async {
    await super.removeFile(key);
    _priorities.remove(key);
    _updateAnalytics(evictionCount: _analytics.evictionCount + 1);
  }

  // Batch preload with priority
  Future<void> preloadBatch({
    required List<String> videoUrls,
    List<String?> thumbnailUrls = const [],
    CachePriority videoPriority = CachePriority.medium,
    CachePriority thumbnailPriority = CachePriority.low,
  }) async {
    try {
      await cleanCacheIfNeeded();

      // Process videos in batches of 3
      for (final batch in _createBatches(videoUrls, 3)) {
        await Future.wait(
          batch.map((url) => preloadWithPriority(url, videoPriority)),
          eagerError: false,
        );
      }

      // Process thumbnails in batches of 5
      if (thumbnailUrls.isNotEmpty) {
        final validThumbnails =
            thumbnailUrls
                .where((url) => url != null && url.isNotEmpty)
                .cast<String>()
                .toList();

        for (final batch in _createBatches(validThumbnails, 5)) {
          await Future.wait(
            batch.map((url) => preloadWithPriority(url, thumbnailPriority)),
            eagerError: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error in preloadBatch: $e');
    }
  }

  // Preload video into cache
  Future<void> preloadVideo(String videoUrl) async {
    if (videoUrl.isEmpty) return;

    try {
      final fileInfo = await getFileFromCache(videoUrl);
      if (fileInfo != null && await _isFileValid(fileInfo)) {
        debugPrint('Video already cached: $videoUrl');
        return;
      }

      debugPrint('Preloading video: $videoUrl');
      await downloadFile(videoUrl);
    } catch (e) {
      debugPrint('Error preloading video: $e');
    }
  }

  // Preload thumbnail
  Future<void> preloadThumbnail(String? thumbnailUrl) async {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) return;

    try {
      final fileInfo = await getFileFromCache(thumbnailUrl);
      if (fileInfo != null && await _isFileValid(fileInfo)) {
        debugPrint('Thumbnail already cached: $thumbnailUrl');
        return;
      }

      debugPrint('Preloading thumbnail: $thumbnailUrl');
      await downloadFile(thumbnailUrl);
    } catch (e) {
      debugPrint('Error preloading thumbnail: $e');
    }
  }

  // Check if file is valid
  Future<bool> _isFileValid(FileInfo fileInfo) async {
    final file = fileInfo.file;
    final validTill = fileInfo.validTill;

    return file.existsSync() &&
        // ignore: unnecessary_null_comparison
        (validTill == null || validTill.isAfter(DateTime.now()));
  }

  // Get cache size
  Future<int> _getCacheSize() async {
    try {
      final cacheDir = await path_provider.getTemporaryDirectory();
      final snipCacheDir = Directory(p.join(cacheDir.path, key));

      if (!await snipCacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in snipCacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  // Clean cache if needed
  Future<void> cleanCacheIfNeeded() async {
    try {
      final currentSize = await _getCacheSize();
      if (currentSize > maxCacheSize) {
        await emptyCache();
        debugPrint(
          'Cache cleaned. Previous size: ${currentSize ~/ (1024 * 1024)}MB',
        );
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }

  // Create batches for concurrent processing
  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await path_provider.getApplicationDocumentsDirectory();
      if (appDir.path.isEmpty) {
        throw Exception('Application documents directory path is empty');
      }

      _cacheDir = '${appDir.path}/snip_cache';
      debugPrint('Initializing SnipCacheManager with path: $_cacheDir');

      final cacheDir = Directory(_cacheDir!);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      _startDiskMonitoring();

      _isInitialized = true;
      debugPrint('SnipCacheManager initialization complete');
    } catch (e) {
      debugPrint('Error in SnipCacheManager._initialize: $e');
      rethrow;
    }
  }

  static bool _isInitialized = false;
}
