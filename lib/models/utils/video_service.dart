import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';

// Import the models
import 'video_quality.dart';

class VideoService {
  // Static maps for controller management
  static final Map<String, VideoPlayerController> _controllers = {};
  static final Map<String, Completer<void>> _initializationCompleters = {};
  static final Map<String, bool> _isInitializing = {};
  static final Map<String, VideoQuality> _currentQualities = {};
  static final Map<String, Map<VideoQuality, String>> _qualityUrls = {};
  static final Map<String, DateTime> _lastQualityCheck = {};
  static final Map<String, int> _bufferCount = {};
  static final Map<String, int> _retryCount = {};
  static final Map<String, DateTime> _lastUsed = {};
  static final Map<String, int> _loadTimes = {};
  static final Map<String, int> _loadTimeCounts = {};

  // Constants
  // static const Duration _qualityCheckInterval = Duration(seconds: 10);
  static const Duration _cleanupInterval = Duration(minutes: 30);
  // static const Duration _bufferTimeout = Duration(seconds: 5);
  // static const int _maxBufferCount = 3;
  // static const int _maxRetries = 3;
  static const int _maxRetryAttempts = 3;

  // Initialize periodic cleanup
  static void initialize() {
    _startPeriodicCleanup();
  }

  // Track video events for analytics
  static void _trackVideoEvent(
    String snipId,
    String event,
    Map<String, dynamic> properties,
  ) {
    debugPrint('🎥 VideoService: Event - $event for snip $snipId');
    debugPrint('🎥 VideoService: Properties - $properties');

    // Implement analytics tracking
    // This could be Firebase Analytics, Mixpanel, or any other analytics service
    // For now, we'll just log the events
    final timestamp = DateTime.now().toIso8601String();
    final eventData = {
      'event': event,
      'snipId': snipId,
      'timestamp': timestamp,
      ...properties,
    };

    // Log to console for debugging
    debugPrint('🎥 VideoService: Analytics Event: $eventData');

    // In a real implementation, you would send this to your analytics service
    // Example: FirebaseAnalytics.instance.logEvent(name: event, parameters: eventData);
  }

  // Update average load time
  static void _updateAverageLoadTime(int loadTime) {
    final totalLoadTime = _loadTimes['total'] ?? 0;
    final count = _loadTimeCounts['total'] ?? 0;

    _loadTimes['total'] = totalLoadTime + loadTime;
    _loadTimeCounts['total'] = count + 1;

    final average = _loadTimes['total']! / _loadTimeCounts['total']!;
    debugPrint(
      '🎥 VideoService: Average load time: ${average.toStringAsFixed(2)}ms',
    );
  }

  // Pre-buffer next videos
  static Future<void> _preBufferNextVideos(List<String> urls) async {
    for (final url in urls) {
      try {
        debugPrint('🎥 VideoService: Pre-buffering video: $url');
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await controller.initialize();
        await controller.dispose();
      } catch (e) {
        debugPrint('🎥 VideoService: Failed to pre-buffer video: $url');
        debugPrint('🎥 VideoService: Error: $e');
      }
    }
  }

  // Initialize video controller with quality management
  static Future<VideoPlayerController?> initializeController({
    required String url,
    required String snipId,
    String? quality,
    List<String>? preBufferUrls,
    bool useCache = true,
  }) async {
    debugPrint('🎥 VideoService: Initializing controller for snip $snipId');
    debugPrint('🎥 VideoService: URL: $url');
    debugPrint('🎥 VideoService: Quality: $quality');
    debugPrint('🎥 VideoService: Use cache: $useCache');

    // Early validation of URL
    if (url.isEmpty) {
      throw Exception('Video URL cannot be empty');
    }

    // Try to parse the URL first to catch basic formatting issues
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) {
        throw Exception(
          'Invalid URL structure: URL must include scheme (http/https) and host',
        );
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw Exception('Invalid URL scheme: must be http or https');
      }
    } catch (e) {
      debugPrint('🎥 VideoService: Basic URL validation failed: $e');
      throw Exception('Invalid URL format: $e');
    }

    final startTime = DateTime.now();
    int attempt = 0;
    VideoPlayerController? controller;
    Exception? lastError;

    while (attempt < _maxRetryAttempts) {
      try {
        attempt++;
        debugPrint('🎥 VideoService: Attempt $attempt of $_maxRetryAttempts');

        // Validate URL first
        debugPrint('🎥 VideoService: Validating URL...');
        _validateS3Url(url);
        debugPrint('🎥 VideoService: URL validation passed');

        // Try direct URL first
        debugPrint('🎥 VideoService: Attempting direct URL initialization...');
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );

        // Set up error listener
        controller.addListener(() {
          if (controller?.value.hasError ?? false) {
            debugPrint(
              '🎥 VideoService: Controller error: ${controller?.value.errorDescription}',
            );
          }
        });

        // Initialize with timeout
        debugPrint('🎥 VideoService: Initializing controller...');
        await controller.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('🎥 VideoService: Initialization timed out');
            throw TimeoutException('Video initialization timed out');
          },
        );
        debugPrint('🎥 VideoService: Controller initialized successfully');

        // If we get here, initialization was successful
        final loadTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('🎥 VideoService: Total initialization time: ${loadTime}ms');

        // Update analytics
        _updateAverageLoadTime(loadTime);
        _trackVideoEvent(snipId, 'initialization_success', {
          'attempt': attempt,
          'load_time': loadTime,
          'quality': quality ?? 'auto',
        });

        // Configure controller
        controller.setLooping(true);
        controller.setVolume(1.0);

        // Pre-buffer next videos if available
        if (preBufferUrls != null && preBufferUrls.isNotEmpty) {
          debugPrint(
            '🎥 VideoService: Pre-buffering ${preBufferUrls.length} videos',
          );
          _preBufferNextVideos(preBufferUrls);
        }

        return controller;
      } catch (e, stackTrace) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('🎥 VideoService: Error on attempt $attempt: $e');
        debugPrint('🎥 VideoService: Stack trace: $stackTrace');

        // Track the error
        _trackVideoEvent(snipId, 'initialization_error', {
          'attempt': attempt,
          'error': e.toString(),
          'quality': quality ?? 'auto',
        });

        // If we have a controller, dispose it
        if (controller != null) {
          debugPrint('🎥 VideoService: Disposing failed controller');
          await controller.dispose();
          controller = null;
        }

        // If this is the last attempt, throw the error
        if (attempt >= _maxRetryAttempts) {
          debugPrint('🎥 VideoService: All attempts failed');
          throw lastError;
        }

        // Wait before retrying with exponential backoff
        final delay = Duration(milliseconds: 1000 * (1 << (attempt - 1)));
        debugPrint(
          '🎥 VideoService: Waiting ${delay.inMilliseconds}ms before retry',
        );
        await Future.delayed(delay);
      }
    }

    throw lastError ?? Exception('Failed to initialize video controller');
  }

  static void _validateS3Url(String url) {
    debugPrint('🎥 VideoService: Validating URL: $url');

    if (url.isEmpty) {
      throw Exception('Video URL cannot be empty');
    }

    // First validate basic URL structure
    try {
      final uri = Uri.parse(url);
      debugPrint(
        '🎥 VideoService: Parsed URI - Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}',
      );

      if (!uri.hasScheme) {
        throw Exception('URL must include a scheme (http/https)');
      }
      if (!uri.hasAuthority) {
        throw Exception('URL must include a host');
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw Exception('URL scheme must be http or https');
      }
    } catch (e) {
      debugPrint('🎥 VideoService: URL parsing error: $e');
      throw Exception('Invalid URL format: $e');
    }

    // Then check S3-specific parameters
    final expiresMatch = RegExp(r'X-Amz-Expires=(\d+)').firstMatch(url);
    if (expiresMatch != null) {
      final expiresIn = int.parse(expiresMatch.group(1)!);
      final dateMatch = RegExp(r'X-Amz-Date=([^&]+)').firstMatch(url);
      if (dateMatch != null) {
        final dateStr = dateMatch.group(1)!;
        debugPrint(
          '🎥 VideoService: S3 URL parameters - Expires: $expiresIn, Date: $dateStr',
        );

        final signedDate = DateTime.parse(dateStr);
        final expiryDate = signedDate.add(Duration(seconds: expiresIn));

        // Check if the URL has expired
        if (DateTime.now().isAfter(expiryDate)) {
          throw Exception('Video URL has expired');
        }

        // Check if the URL is dated too far in the future (more than 7 days)
        if (signedDate.difference(DateTime.now()).inDays > 7) {
          throw Exception('Video URL has an invalid future date');
        }
      }
    }

    debugPrint('🎥 VideoService: URL validation passed successfully');
  }

  static Future<VideoPlayerController> _createControllerWithFallback(
    String url,
  ) async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();
      return controller;
    } catch (e) {
      debugPrint('Failed to initialize video: $e');
      rethrow;
    }
  }

  static Future<void> _setupHardwareAcceleration(
    VideoPlayerController controller,
  ) async {
    if (Platform.isAndroid) {
      try {
        await controller.initialize();
        await controller.setVolume(1.0);
        debugPrint('Hardware acceleration setup completed');
      } catch (e) {
        debugPrint('Failed to setup video playback: $e');
      }
    }
  }

  static Future<void> switchQuality(
    String videoUrl,
    VideoQuality newQuality,
  ) async {
    final controller = _controllers[videoUrl];
    final qualityUrls = _qualityUrls[videoUrl];

    if (controller == null || qualityUrls == null) return;

    try {
      final newUrl = qualityUrls[newQuality];
      if (newUrl == null) return;

      final position = controller.value.position;
      final wasPlaying = controller.value.isPlaying;

      // Create new controller
      final newController = await _createControllerWithFallback(newUrl);
      await _setupHardwareAcceleration(newController);

      await newController.seekTo(position);
      await newController.setLooping(true);
      await newController.setVolume(controller.value.volume);

      if (wasPlaying) {
        await newController.play();
      }

      // Switch controllers
      final oldController = _controllers[videoUrl];
      _controllers[videoUrl] = newController;
      _currentQualities[videoUrl] = newQuality;

      oldController?.dispose();

      debugPrint('Switched to quality: $newQuality');
    } catch (e) {
      debugPrint('Error switching quality: $e');
    }
  }

  static void _updateLastUsed(String videoUrl) {
    _lastUsed[videoUrl] = DateTime.now();
  }

  static void _startPeriodicCleanup() {
    Timer.periodic(_cleanupInterval, (timer) {
      final now = DateTime.now();
      _controllers.removeWhere((url, controller) {
        final lastUsed = _lastUsed[url];
        if (lastUsed == null) return false;

        if (now.difference(lastUsed) > _cleanupInterval) {
          controller.dispose();
          _cleanupController(url);
          return true;
        }
        return false;
      });
    });
  }

  static void _cleanupController(String videoUrl) {
    _controllers.remove(videoUrl);
    _initializationCompleters.remove(videoUrl);
    _isInitializing.remove(videoUrl);
    _currentQualities.remove(videoUrl);
    _qualityUrls.remove(videoUrl);
    _lastQualityCheck.remove(videoUrl);
    _bufferCount.remove(videoUrl);
    _retryCount.remove(videoUrl);
    _lastUsed.remove(videoUrl);
  }

  static VideoPlayerController? getController(String videoUrl) {
    _updateLastUsed(videoUrl);
    return _controllers[videoUrl];
  }

  static Future<void> disposeController(String videoUrl) async {
    final controller = _controllers[videoUrl];
    if (controller != null) {
      await controller.dispose();
      _cleanupController(videoUrl);
    }
  }

  static Future<void> disposeAllControllers() async {
    final controllers = List<VideoPlayerController>.from(_controllers.values);
    for (var controller in controllers) {
      await controller.dispose();
    }
    _controllers.clear();
    _initializationCompleters.clear();
    _isInitializing.clear();
    _currentQualities.clear();
    _qualityUrls.clear();
    _lastQualityCheck.clear();
    _bufferCount.clear();
    _retryCount.clear();
    _lastUsed.clear();
  }
}
