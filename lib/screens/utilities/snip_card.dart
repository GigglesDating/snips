import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:ui';
import '../barrel.dart';
// import '../../models/video_quality.dart';

class SnipCard extends StatefulWidget {
  final SnipModel snip;
  final bool isVisible;
  final bool autoPlay;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final Function(bool)? onVideoStateChange;
  final Function()? onVideoComplete;
  final Function(String)? onProfileTap;
  final VoidCallback? onVideoPause;
  final VoidCallback? onVideoResume;
  final VoidCallback? onSingleTap;
  final VoidCallback? onScrollBack;
  final VoidCallback? onEndReached;
  final Function(String)? onVideoError;
  final bool isProfileView;
  final double? customWidth;
  final double? customHeight;
  final VoidCallback? onSnipTap;

  const SnipCard({
    super.key,
    required this.snip,
    this.isVisible = false,
    this.autoPlay = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onVideoStateChange,
    this.onVideoComplete,
    this.onProfileTap,
    this.onVideoPause,
    this.onVideoResume,
    this.onSingleTap,
    this.onScrollBack,
    this.onEndReached,
    this.onVideoError,
    this.isProfileView = false,
    this.customWidth,
    this.customHeight,
    this.onSnipTap,
  });

  @override
  State<SnipCard> createState() => _SnipCardState();
}

class _SnipCardState extends State<SnipCard> with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isBuffering = true;
  bool _isDraggingProgress = false;
  double _progressBarHeight = 2.0;
  Timer? _controlsTimer;
  late AnimationController _animationController;
  late Animation<double> _progressBarAnimation;
  late Animation<double> _likeAnimation;
  late Animation<double> _profilePositionAnimation;

  // UI State
  bool _showProfileInfo = false;
  bool _showDescription = false;
  bool _showStats = false;
  bool _isLiked = false;
  bool _showHeart = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeVideo();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Progress bar animation
    _progressBarAnimation = Tween<double>(begin: 2.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
      ),
    );

    // Like animation
    _likeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack),
    );

    // Profile position animation
    _profilePositionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _progressBarAnimation.addListener(() {
      setState(() {
        _progressBarHeight = _progressBarAnimation.value;
      });
    });
  }

  void _updateUIVisibility(bool show) {
    setState(() {
      _showProfileInfo = show;
      _showDescription = show;
      _showStats = show;
    });
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    debugPrint('Starting video initialization...');
    debugPrint('Video URL: ${widget.snip.video.source}');
    debugPrint('Quality URLs: ${widget.snip.video.qualityUrls}');

    setState(() {
      _isBuffering = true;
      _error = null;
    });

    try {
      // Initialize video with quality management
      final controller = await VideoService.initializeController(
        url: widget.snip.video.source,
        snipId: widget.snip.snipId,
        quality: widget.snip.video.currentQuality.name,
        preBufferUrls: widget.snip.video.qualityUrls.values.toList(),
      );

      if (!mounted) return;

      if (controller != null) {
        setState(() {
          _controller = controller;
          _isBuffering = false;
          _error = null;
        });

        // Add video state listeners
        _controller?.addListener(_videoListener);

        // Play if visible and autoPlay is true
        if (widget.isVisible && widget.autoPlay) {
          debugPrint('Auto-playing video...');
          // Add a small delay to ensure controller is properly initialized
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _playVideo();
            }
          });
        }
      } else {
        throw Exception('Failed to initialize video controller');
      }
    } catch (e, stackTrace) {
      debugPrint('Final error initializing video: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isBuffering = false;
        _error = e.toString();
        _handleVideoStateChange(VideoPlaybackState.error);
      });
      widget.onVideoError?.call(e.toString());
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;

    // Handle video completion
    if (_controller!.value.position >= _controller!.value.duration) {
      widget.onVideoComplete?.call();
    }

    // Update buffering state
    final isBuffering = _controller!.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
      if (isBuffering) {
        debugPrint('Video started buffering');
      } else {
        debugPrint('Video resumed playback');
      }
    }

    // Handle state changes
    final isPlaying = _controller!.value.isPlaying;
    debugPrint('isPlaying 🥲 $isPlaying');
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
      widget.onVideoStateChange?.call(isPlaying);
      _updateUIVisibility(!isPlaying);
      debugPrint(
        'Video playback state changed: ${isPlaying ? 'playing' : 'paused'}',
      );
    }
  }

  Future<void> _playVideo() async {
    if (_controller == null) return;

    try {
      // Make sure to set volume
      await _controller!.setVolume(_isMuted ? 0.0 : 1.0);

      // Force state update before play
      setState(() => _isPlaying = true);

      // Play the video
      await _controller!.play();

      // Update UI visibility
      _updateUIVisibility(false);

      debugPrint('Video playback started');
    } catch (e) {
      debugPrint('Error playing video: $e');
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _pauseVideo() async {
    if (_controller == null) return;
    try {
      await _controller!.pause();
      setState(() => _isPlaying = false);
      _updateUIVisibility(true);
      debugPrint('Video playback paused');
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  void _onProgressDragStart(DragStartDetails details) {
    setState(() => _isDraggingProgress = true);
    _animationController.forward(from: 0.0);
  }

  void _onProgressDragUpdate(DragUpdateDetails details) {
    if (_controller == null) return;

    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final position = details.localPosition.dx.clamp(0, width);
    final duration = _controller!.value.duration;

    final newPosition = duration * (position / width);
    _controller!.seekTo(newPosition);
  }

  void _onProgressDragEnd(DragEndDetails details) {
    setState(() => _isDraggingProgress = false);
    _animationController.reverse();
  }

  @override
  void dispose() {
    debugPrint('Disposing SnipCard');
    _controller?.removeListener(_videoListener);
    VideoService.disposeController(widget.snip.video.source);
    _controlsTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarHeight = screenHeight * 0.075;

    // Use custom dimensions if provided, otherwise use default
    final cardWidth = widget.customWidth ?? screenWidth;
    final cardHeight = widget.customHeight ?? screenHeight;

    if (_controller == null) {
      debugPrint('controller is null 🥲');
      return _buildLoadingView();
    }

    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: EdgeInsets.only(
        bottom: widget.isProfileView ? 0 : screenHeight * 0.02,
        top: widget.isProfileView ? 0 : screenHeight * 0.02,
        right: widget.isProfileView ? screenWidth * 0.05 : 0,
      ),
      child: GestureDetector(
        onTap: widget.isProfileView ? widget.onSnipTap : _handleTap,
        onDoubleTap: widget.isProfileView ? null : _handleDoubleTap,
        onLongPress: widget.isProfileView ? null : _handleLongPress,
        child: Stack(
          children: [
            // Video Player
            _buildVideoPlayer(),

            // Stats Strip (Top)
            if (_showStats && !widget.isProfileView)
              Positioned(
                top: cardWidth * 0.04,
                left: cardWidth * 0.06,
                child: _buildStatsStrip(),
              ),

            // More Options Button (Top Right)
            if (!widget.isProfileView)
              Positioned(
                top: cardWidth * 0.04,
                right: cardWidth * 0.06,
                child: _buildMoreOptionsButton(),
              ),

            // Action Bar (Right)
            if (!widget.isProfileView)
              Positioned(
                right: cardWidth * 0.04,
                bottom: bottomPadding + navBarHeight,
                child: _buildActionBar(),
              ),

            // Profile Info and Description (Bottom)
            if (_showProfileInfo && !widget.isProfileView) _buildProfileInfo(),

            // Heart Animation (Center)
            if (_showHeart && !widget.isProfileView)
              Positioned.fill(child: _buildHeartAnimation()),

            // Progress Bar (Bottom)
            if (!widget.isProfileView)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: _onProgressDragStart,
                  onHorizontalDragUpdate: _onProgressDragUpdate,
                  onHorizontalDragEnd: _onProgressDragEnd,
                  child: _buildProgressBar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || _controller?.value == null) {
      return _buildLoadingView();
    }

    if (_controller?.value.hasError == true) {
      return _buildErrorView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onLongPress: _handleLongPress,
          onVerticalDragUpdate: handleScroll,
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        if (_isBuffering) _buildLoadingView(),
        if (_isMuted) _buildMuteIndicator(),
      ],
    );
  }

  Widget _buildProgressBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _progressBarHeight,
      child: Stack(
        children: [
          // Background
          Container(color: Colors.grey[800]),
          // Progress
          FractionallySizedBox(
            widthFactor:
                _controller!.value.position.inMilliseconds /
                _controller!.value.duration.inMilliseconds,
            child: Container(color: Colors.white),
          ),
          if (_isDraggingProgress) _buildTimestampBubble(),
        ],
      ),
    );
  }

  Widget _buildTimestampBubble() {
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    return Positioned(
      bottom: _progressBarHeight + 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(153), // 0.6 opacity
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${_formatDuration(position)} / ${_formatDuration(duration)}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.snip.video.thumbnail != null &&
              widget.snip.video.thumbnail!.isNotEmpty)
            Image.network(
              widget.snip.video.thumbnail!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading thumbnail: $error');
                return Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withAlpha(153),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Error loading video',
              style: TextStyle(color: Colors.white.withAlpha(153)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _error = null;
                  _isBuffering = true;
                });
                _initializeVideo();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    setState(() => _isMuted = !_isMuted);

    // Update UI visibility
    setState(() {
      _showProfileInfo = !_showProfileInfo;
      _showDescription = !_showDescription;
      _showStats = !_showStats;
    });

    // Notify parent for nav bar visibility
    widget.onSingleTap?.call();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _isLiked = !_isLiked;
      _showHeart = true;
    });

    _animationController.forward().then((_) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() => _showHeart = false);
        }
      });
    });

    widget.onLike?.call();
  }

  void _handleLongPress() {
    _pauseVideo();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildStatsStrip() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.03,
        vertical: MediaQuery.of(context).size.width * 0.015,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(153), // 0.6 opacity
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : Colors.white,
            size: MediaQuery.of(context).size.width * 0.045,
          ),
          const SizedBox(width: 4),
          Text(
            widget.snip.likesCount.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Text(
            _getTimeAgo(widget.snip.timestamp),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsButton() {
    return GestureDetector(
      onTap: _showReportSheet,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.015),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(102), // 0.4 opacity
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(51), // 0.2 opacity
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: MediaQuery.of(context).size.width * 0.045,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return ActionBar(
      isDarkMode: true,
      isLiked: _isLiked,
      onLikeTap: _handleDoubleTap,
      onCommentTap: _showCommentsSheet,
      onShareTap: _showShareSheet,
      orientation: ActionBarOrientation.vertical,
      backgroundColor: Colors.black.withAlpha(102), // 0.4 opacity
    );
  }

  Widget _buildProfileInfo() {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarHeight = screenHeight * 0.075;

    return AnimatedBuilder(
      animation: _profilePositionAnimation,
      builder: (context, child) {
        final basePosition = bottomPadding + navBarHeight + 20;
        final animatedPosition =
            basePosition + (20 * _profilePositionAnimation.value);

        return Positioned(
          bottom: animatedPosition,
          left: 0,
          right: 0,
          child: child!,
        );
      },
      child: Column(
        mainAxisSize:
            MainAxisSize
                .min, // Add this to make Column shrink-wrap its children
        children: [
          // Profile Picture
          GestureDetector(
            onTap: () => widget.onProfileTap?.call(widget.snip.authorProfileId),
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * 0.12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.width * 0.06,
                ),
                child: Image.network(
                  widget.snip.authorProfile.profileImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.width * 0.03),
          // Description - Replace Expanded with a Container that has a fixed or constrained height
          Container(
            constraints: BoxConstraints(
              maxHeight:
                  screenHeight * 0.3, // Use a percentage of screen height
            ),
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() => _showDescription = true);
              },
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.snip.authorProfile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.snip.description,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: _showDescription ? null : 3,
                      overflow: _showDescription ? null : TextOverflow.fade,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartAnimation() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _showHeart ? 1.0 : 0.0,
      child: Center(
        child: ScaleTransition(
          scale: _likeAnimation,
          child: Icon(
            Icons.favorite,
            color: Colors.white,
            size: MediaQuery.of(context).size.width * 0.3,
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CommentsSheet(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            contentId: widget.snip.snipId,
            contentType: 'snip',
            commentIds: widget.snip.commentIds,
            authorProfile: widget.snip.authorProfile,
            screenHeight: MediaQuery.of(context).size.height,
            screenWidth: MediaQuery.of(context).size.width,
          ),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ShareSheet(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            post: widget.snip.toJson(),
            screenWidth: MediaQuery.of(context).size.width,
          ),
    );
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ReportSheet(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            screenWidth: MediaQuery.of(context).size.width,
            reportType: ReportType.content,
            contentType: 'snip',
          ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
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

  void _handleVideoStateChange(VideoPlaybackState state) {
    if (!mounted) return;

    switch (state) {
      case VideoPlaybackState.paused:
        widget.onVideoPause?.call();
        setState(() => _isPlaying = false);
        break;
      case VideoPlaybackState.playing:
        widget.onVideoResume?.call();
        setState(() => _isPlaying = true);
        break;
      case VideoPlaybackState.completed:
        widget.onEndReached?.call();
        setState(() => _isPlaying = false);
        break;
      case VideoPlaybackState.error:
        setState(() {
          _isPlaying = false;
          _isBuffering = false;
        });
        break;
      default:
        break;
    }
  }

  // Add method to handle bottom sheet state
  void handleBottomSheetState(bool isShowing) {
    if (isShowing) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  // Update scroll direction handling
  void handleScroll(DragUpdateDetails details) {
    if (details.primaryDelta != null && details.primaryDelta! > 0) {
      // Scrolling down (going to previous video)
      widget.onScrollBack?.call();
    }
  }

  Widget _buildMuteIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(153), // 0.6 opacity
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.volume_off, color: Colors.white, size: 20),
      ),
    );
  }
}
