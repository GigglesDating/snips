import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utilities/snip_card.dart';
import '../utilities/nav_bar.dart';
import '../../models/snips_model.dart';
import '../../models/utils/snip_parser.dart';
import '../../models/utils/snip_cache_manager.dart';
import '../../models/utils/video_quality.dart';
import '../../network/think.dart';
import 'dart:async'; // Add this import for Timer
import 'dart:ui';
import 'dart:collection'; // Add this import for Queue
import 'package:shared_preferences/shared_preferences.dart';

class LifecycleAwareMemoryMonitor extends WidgetsBindingObserver {
  final VoidCallback onMemoryPressure;
  final VoidCallback onMemoryRecover;

  LifecycleAwareMemoryMonitor({
    required this.onMemoryPressure,
    required this.onMemoryRecover,
  });

  @override
  void didHaveMemoryPressure() {
    onMemoryPressure();
  }
}

class SnipsScreen extends StatefulWidget {
  final String? uuid;
  const SnipsScreen({super.key, this.uuid});

  @override
  State<SnipsScreen> createState() => _SnipsScreenState();
}

class _SnipsScreenState extends State<SnipsScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ThinkProvider _thinkProvider = ThinkProvider();
  final SnipCacheManager _cacheManager = SnipCacheManager();

  List<SnipModel> _snips = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hasMore = true;
  int? _nextPage;
  String? _error;

  // Navigation bar visibility control
  bool _isNavBarVisible = false;
  Timer? _navBarTimer;

  // Swipe gesture control
  final double _minSwipeDistance =
      50.0; // Minimum distance for horizontal swipe
  double _horizontalDragStart = 0.0;
  double _horizontalDragVelocity = 0.0;
  static const double _minSwipeVelocity = 300.0;

  // Add to class variables
  final Queue<String> _preloadQueue = Queue();
  bool _isPreloading = false;
  final Map<String, int> _videoRetryCount = {};
  static const int _maxRetryAttempts = 3;
  bool _isLowMemoryMode = false;

  @override
  void initState() {
    super.initState();
    _initializeSnips();
    _monitorMemoryUsage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check if the current video should be playing
    if (_snips.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _snips.length) {
      // This will ensure the current visible video is playing
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {}); // Trigger rebuild
        }
      });
    }
  }

  Future<void> _initializeSnips() async {
    try {
      // Get UUID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString('user_uuid');

      debugPrint('Initializing snips with UUID: $uuid');

      if (uuid == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      debugPrint('Making API call to getSnips...');
      final response = await _thinkProvider.getSnips(uuid: uuid, page: 1);
      debugPrint('Raw API Response: $response');

      debugPrint('Parsing snip response...');
      final parsedResponse = await SnipParser.parseSnipResponse(response);
      debugPrint('Parsed Response: $parsedResponse');

      if (parsedResponse['status'] == 'success') {
        final data = parsedResponse['data'];
        debugPrint('Snips data received:');
        debugPrint('Total snips: ${data['total_snips']}');
        debugPrint('Has more: ${data['has_more']}');
        debugPrint('Next page: ${data['next_page']}');

        final snips = List<SnipModel>.from(data['snips']);
        debugPrint('First snip video URL: ${snips.first.video.source}');

        setState(() {
          _snips = snips;
          _hasMore = data['has_more'] ?? false;
          _nextPage = data['next_page'];
          _isLoading = false;
        });

        // Preload first video and its thumbnail
        if (_snips.isNotEmpty) {
          debugPrint('Starting preload of first video...');
          _preloadVideo(0);
        }
      } else {
        debugPrint('API call failed with status: ${parsedResponse['status']}');
        debugPrint('Error message: ${parsedResponse['message']}');
        setState(() {
          _error = parsedResponse['message'] ?? 'Failed to load snips';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _initializeSnips: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error = 'Error loading snips: $e';
        _isLoading = false;
      });
    }
  }

  void _preloadVideo(int index) {
    if (index >= 0 && index < _snips.length) {
      final snip = _snips[index];
      final quality = _getOptimalQuality();

      // Add current video to queue
      final currentVideoUrl = snip.video.qualityUrls[quality] ?? '';
      if (currentVideoUrl.isNotEmpty) {
        _preloadQueue.add(currentVideoUrl);
      }

      // Add thumbnail to queue
      if (snip.video.thumbnail != null) {
        _preloadQueue.add(snip.video.thumbnail!);
      }

      // Add next video to queue if available
      if (index + 1 < _snips.length) {
        final nextSnip = _snips[index + 1];
        final nextVideoUrl = nextSnip.video.qualityUrls[quality] ?? '';
        if (nextVideoUrl.isNotEmpty) {
          _preloadQueue.add(nextVideoUrl);
        }
      }

      // Start preloading if not already in progress
      _processPreloadQueue();
    }
  }

  Future<void> _processPreloadQueue() async {
    if (_isPreloading || _preloadQueue.isEmpty) return;

    _isPreloading = true;
    try {
      while (_preloadQueue.isNotEmpty) {
        final url = _preloadQueue.removeFirst();
        if (url.contains('.mp4')) {
          await _cacheManager.preloadVideo(url);
        } else {
          await _cacheManager.preloadThumbnail(url);
        }
      }
    } catch (e) {
      debugPrint('Error in preload queue: $e');
    } finally {
      _isPreloading = false;
    }
  }

  void _showNavBar() {
    setState(() => _isNavBarVisible = true);
    _navBarTimer?.cancel();
    _navBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isNavBarVisible = false);
      }
    });
  }

  void _handleVideoStateChange(VideoPlaybackState state) {
    if (state == VideoPlaybackState.paused) {
      _showNavBar();
    }
  }

  void _handleScrollBack() {
    _showNavBar();
  }

  void _handleHapticFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }

  void _handleVideoError(String snipId, String error) {
    _videoRetryCount[snipId] = (_videoRetryCount[snipId] ?? 0) + 1;

    if (_videoRetryCount[snipId]! <= _maxRetryAttempts) {
      _showRetrySnackBar(snipId);
      _preloadVideo(_currentIndex);
    } else {
      _showErrorDialog(snipId, error);
    }
  }

  void _showRetrySnackBar(String snipId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Retrying video playback...'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Cancel',
          onPressed: () => _videoRetryCount.remove(snipId),
        ),
      ),
    );
  }

  void _showErrorDialog(String snipId, String error) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Playback Error'),
            content: Text(
              'Unable to play this video. Would you like to retry?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _videoRetryCount.remove(snipId);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _videoRetryCount.remove(snipId);
                  _preloadVideo(_currentIndex);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            ElevatedButton(
              onPressed: _initializeSnips,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // PageView for Snips
          GestureDetector(
            onHorizontalDragStart: (details) {
              _horizontalDragStart = details.localPosition.dx;
              _horizontalDragVelocity = 0.0;
            },
            onHorizontalDragUpdate: (details) {
              _horizontalDragVelocity = details.primaryDelta ?? 0;
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              _horizontalDragVelocity = velocity;
              final dragDistance = _horizontalDragVelocity;
              final dragDifference = dragDistance - _horizontalDragStart;

              if (dragDifference.abs() > _minSwipeDistance ||
                  _horizontalDragVelocity.abs() > _minSwipeVelocity) {
                _handleHapticFeedback();
                if (dragDifference > 0 ||
                    _horizontalDragVelocity > _minSwipeVelocity) {
                  _showUploadSheet();
                } else {
                  NavigationController.navigateToTab(context, 4);
                }
              }
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _preloadVideo(index);
                if (index == _snips.length - 2 &&
                    _hasMore &&
                    _nextPage != null) {
                  _loadMoreSnips();
                }
              },
              itemCount: _snips.length,
              itemBuilder: (context, index) {
                final snip = _snips[index];
                return SnipCard(
                  snip: snip,
                  isVisible: _currentIndex == index,
                  autoPlay: _currentIndex == index, // Ensure autoPlay is set
                  onVideoPause:
                      () => _handleVideoStateChange(VideoPlaybackState.paused),
                  onScrollBack: _handleScrollBack,
                  onEndReached: () {
                    if (index == _snips.length - 1) {
                      setState(() => _isNavBarVisible = true);
                    }
                  },
                  onVideoError:
                      (error) => _handleVideoError(snip.snipId, error),
                );
              },
            ),
          ),

          // Upload Icon Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + screenHeight * 0.02,
            left: screenWidth * 0.05,
            child: GestureDetector(
              onTap: _showUploadSheet,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.025),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(38),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                        width: 0.5,
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/snip_upload.svg',
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Navigation Bar
          if (_isNavBarVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const NavigationController(),
            ),

          // Loading Indicator
          Positioned(
            top: screenHeight * 0.4,
            left: screenWidth * 0.4,
            child: _buildLoadingIndicator(),
          ),

          // Network Indicator
          Positioned(
            top: screenHeight * 0.5,
            left: screenWidth * 0.4,
            child: _buildNetworkIndicator(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreSnips() async {
    if (!_hasMore || _nextPage == null) return;

    try {
      // Get UUID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString('user_uuid');

      if (uuid == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final response = await _thinkProvider.getSnips(
        uuid: uuid,
        page: _nextPage!,
      );

      final parsedResponse = await SnipParser.parseSnipResponse(response);

      if (parsedResponse['status'] == 'success') {
        final data = parsedResponse['data'];
        setState(() {
          _snips.addAll(List<SnipModel>.from(data['snips']));
          _hasMore = data['has_more'] ?? false;
          _nextPage = data['next_page'];
        });
      }
    } catch (e) {
      debugPrint('Error loading more snips: $e');
    }
  }

  void _showUploadSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.35,
                decoration: BoxDecoration(
                  color:
                      isDarkMode
                          ? Colors.black.withAlpha(230)
                          : Colors.white.withAlpha(230),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                  border: Border.all(
                    color:
                        isDarkMode
                            ? Colors.white.withAlpha(38)
                            : Colors.black.withAlpha(26),
                  ),
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.02,
                        ),
                        width: screenWidth * 0.1,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              isDarkMode
                                  ? Colors.white.withAlpha(77)
                                  : Colors.black.withAlpha(77),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Upload Snip',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildUploadOption(
                          context: context,
                          icon: Icons.camera_alt_rounded,
                          label: 'Camera',
                          onTap: () {
                            // Pending API Implementation: Camera upload
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Camera upload coming soon'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        _buildUploadOption(
                          context: context,
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          onTap: () {
                            // Pending API Implementation: Gallery upload
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gallery upload coming soon'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildUploadOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.white.withAlpha(38)
                      : Colors.black.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDarkMode ? Colors.white : Colors.black,
              size: screenWidth * 0.06,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: screenWidth * 0.035,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clear all caches and queues
    _preloadQueue.clear();
    _videoRetryCount.clear();
    _cacheManager.cleanCacheIfNeeded();

    // Cancel timers
    _navBarTimer?.cancel();

    // Dispose controllers
    _pageController.dispose();

    super.dispose();
  }

  void _monitorMemoryUsage() {
    final observer = LifecycleAwareMemoryMonitor(
      onMemoryPressure: () {
        setState(() => _isLowMemoryMode = true);
        _cacheManager.cleanCacheIfNeeded();
      },
      onMemoryRecover: () {
        setState(() => _isLowMemoryMode = false);
      },
    );
    WidgetsBinding.instance.addObserver(observer);
  }

  VideoQuality _getOptimalQuality() {
    if (_isLowMemoryMode) return VideoQuality.low;
    // Can add network speed check here
    return VideoQuality.auto;
  }

  Widget _buildLoadingIndicator() {
    return ShaderMask(
      shaderCallback:
          (bounds) => LinearGradient(
            colors: [Colors.blue.withAlpha(100), Colors.blue],
            stops: const [0.0, 1.0],
          ).createShader(bounds),
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildNetworkIndicator() {
    return AnimatedOpacity(
      opacity: _isLowMemoryMode ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.network_check, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Low Quality',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
