import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../models/utils/comments_parser.dart';
import '../../network/think.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class _GlobalCommentsCache {
  static final Map<String, List<Comment>> _commentsCache = {};
  static final Map<String, DateTime> _commentsCacheTimestamp = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  static void cacheComments(String key, List<Comment> comments) {
    _commentsCache[key] = comments;
    _commentsCacheTimestamp[key] = DateTime.now();
  }

  static List<Comment>? getComments(String key) {
    final timestamp = _commentsCacheTimestamp[key];
    if (timestamp == null) return null;

    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      // Cache expired
      _commentsCache.remove(key);
      _commentsCacheTimestamp.remove(key);
      return null;
    }

    return _commentsCache[key];
  }

  static void _clear() {
    _commentsCache.clear();
    _commentsCacheTimestamp.clear();
  }
}

// Move _getTimeAgo to be a top-level utility function
String _getTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays > 0) {
    return '${difference.inDays}d';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m';
  } else {
    return 'now';
  }
}

class CommentsSheet extends StatefulWidget {
  final bool isDarkMode;
  final String contentId;
  final String contentType;
  final List<String> commentIds;
  final UserModel authorProfile;
  final double screenHeight;
  final double screenWidth;

  const CommentsSheet({
    super.key,
    required this.isDarkMode,
    required this.contentId,
    required this.contentType,
    required this.commentIds,
    required this.authorProfile,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToCommentId;
  String? _replyingToUsername;
  final Map<String, bool> _likedComments = {};
  bool _showHeart = false;
  AnimationController? _animationController;
  Animation<double>? _animation;

  // State variables for comments
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Enhanced caching configuration
  static const String _cacheBoxName = 'comments_cache';
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const int _maxCacheEntries = 50;
  static const int _maxCacheSize = 5 * 1024 * 1024; // 5MB max cache size

  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreComments = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController!);
    _initializeCache().then((_) => _loadComments());
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeCache() async {
    try {
      await Hive.initFlutter();

      if (!Hive.isBoxOpen(_cacheBoxName)) {
        await Hive.openBox<String>(_cacheBoxName);
        // Clean up expired cache entries and enforce limits
        await _cleanExpiredCache();
        await _enforceCacheLimits();
      }
    } catch (e) {
      debugPrint('Error initializing cache: $e');
      // Fallback to no caching if initialization fails
    }
  }

  Future<void> _cleanExpiredCache() async {
    final cache = await Hive.openBox<String>(_cacheBoxName);
    final now = DateTime.now();
    final keysToDelete = <String>[];

    for (final key in cache.keys) {
      final metadata = cache.get('${key}_metadata');
      if (metadata != null) {
        final expiryTime = DateTime.parse(jsonDecode(metadata)['expiry']);
        if (now.isAfter(expiryTime)) {
          keysToDelete.add(key);
          keysToDelete.add('${key}_metadata');
        }
      }
    }

    await cache.deleteAll(keysToDelete);
  }

  Future<void> _enforceCacheLimits() async {
    final cache = await Hive.openBox<String>(_cacheBoxName);

    // Enforce maximum entries
    if (cache.length > _maxCacheEntries) {
      final entriesToRemove = cache.length - _maxCacheEntries;
      final oldestKeys = cache.keys.take(entriesToRemove).toList();
      await cache.deleteAll(oldestKeys);
    }

    // Enforce maximum size
    int totalSize = 0;
    final keysToDelete = <dynamic>[];

    for (final key in cache.keys) {
      final value = cache.get(key);
      if (value != null) {
        totalSize += value.length;
        if (totalSize > _maxCacheSize) {
          keysToDelete.add(key);
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      await cache.deleteAll(keysToDelete);
    }
  }

  Future<void> _cacheResponse(String key, Map<String, dynamic> response) async {
    try {
      final box = await Hive.openBox<String>(_cacheBoxName);

      // Check cache size before adding
      if (await _shouldEvictCache(box)) {
        await _evictOldestEntries(box);
      }

      final now = DateTime.now();
      await box.put(key, jsonEncode(response));
      await box.put(
        '${key}_metadata',
        jsonEncode({
          'timestamp': now.toIso8601String(),
          'expiry': now.add(_cacheDuration).toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error caching response: $e');
    }
  }

  Future<bool> _shouldEvictCache(Box<String> box) async {
    int totalSize = 0;
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        totalSize += value.length;
      }
    }
    return totalSize > _maxCacheSize || box.length > _maxCacheEntries * 2;
  }

  Future<void> _evictOldestEntries(Box<String> box) async {
    final entries = <MapEntry<String, DateTime>>[];

    for (final key in box.keys) {
      if (!key.endsWith('_metadata')) continue;

      final metadata = box.get(key);
      if (metadata != null) {
        final timestamp = DateTime.parse(jsonDecode(metadata)['timestamp']);
        entries.add(MapEntry(key.replaceAll('_metadata', ''), timestamp));
      }
    }

    entries.sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest third of entries
    final entriesToRemove = entries.take(entries.length ~/ 3);
    for (final entry in entriesToRemove) {
      await box.delete(entry.key);
      await box.delete('${entry.key}_metadata');
    }
  }

  String get _cacheKey => '${widget.contentType}_${widget.contentId}_comments';

  Future<void> _loadComments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Check memory cache first
      final memoryCachedComments = _GlobalCommentsCache.getComments(_cacheKey);
      if (memoryCachedComments != null) {
        if (mounted) {
          setState(() {
            _comments = memoryCachedComments;
            _isLoading = false;
            _currentPage = 1;
          });
          // Fetch fresh data in background
          _fetchFreshComments(showLoading: false);
          return;
        }
      }

      // Check disk cache
      final cachedResponse = await _getCachedResponse('${_cacheKey}_page_1');
      if (cachedResponse != null) {
        final cachedComments = await compute(
          _parseCommentsInBackground,
          cachedResponse,
        );
        if (mounted) {
          setState(() {
            _comments = cachedComments;
            _isLoading = false;
            _currentPage = 1;
            _hasMoreComments = cachedResponse['data']['has_more'] ?? false;
          });
          // Cache in memory for faster access next time
          _GlobalCommentsCache.cacheComments(_cacheKey, cachedComments);

          // Pre-load author images
          _preloadAuthorImages(cachedComments);
        }
      }

      await _fetchFreshComments(showLoading: !_comments.isNotEmpty);
    } catch (e, stackTrace) {
      debugPrint('Error loading comments: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load comments. Please try again.';
        });
      }
    }
  }

  Future<void> _fetchFreshComments({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString('user_uuid');

      if (uuid == null) {
        throw Exception('No UUID found. Please log in again.');
      }

      debugPrint(
        'Fetching comments for content: ${widget.contentId} with comment IDs: ${widget.commentIds}',
      );

      final response = await ThinkProvider().fetchComments(
        uuid: uuid,
        contentId: widget.contentId,
        contentType: widget.contentType,
        page: 1,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to fetch comments');
      }

      // Parse in background
      final freshComments = await compute(_parseCommentsInBackground, response);

      // Pre-load author images
      _preloadAuthorImages(freshComments);

      if (!mounted) return;

      // Cache the new response only if successful
      if (freshComments.isNotEmpty || response['data']['total_comments'] == 0) {
        await _cacheResponse('${_cacheKey}_page_1', response);
        _GlobalCommentsCache.cacheComments(_cacheKey, freshComments);
      }

      setState(() {
        _comments = freshComments;
        _isLoading = false;
        _hasError = false;
        _hasMoreComments = response['data']['has_more'] ?? false;
        _currentPage = 1;
      });
    } catch (e) {
      debugPrint('Error fetching fresh comments: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (showLoading) {
          _hasError = true;
          _errorMessage = 'Failed to fetch comments. Please try again.';
        }
      });
    }
  }

  void _preloadAuthorImages(List<Comment> comments) {
    for (final comment in comments) {
      if (comment.authorProfile.profileImage.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(
            comment.authorProfile.profileImage,
            cacheKey: '${comment.authorProfile.profileImage}_thumb',
          ),
          context,
        );
      }

      // Also preload reply author images
      for (final reply in comment.replies) {
        if (reply.authorProfile.profileImage.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(
              reply.authorProfile.profileImage,
              cacheKey: '${reply.authorProfile.profileImage}_reply_thumb',
            ),
            context,
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _getCachedResponse(String key) async {
    try {
      final box = await Hive.openBox<String>(_cacheBoxName);
      final cachedData = box.get(key);
      final metadata = box.get('${key}_metadata');

      if (cachedData == null || metadata == null) return null;

      final metadataMap = jsonDecode(metadata) as Map<String, dynamic>;
      final expiryTime = DateTime.parse(metadataMap['expiry']);

      if (DateTime.now().isAfter(expiryTime)) {
        // Cache expired
        await box.delete(key);
        await box.delete('${key}_metadata');
        return null;
      }

      return jsonDecode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading cache: $e');
      return null;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreComments) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;

      // Check cache first for next page
      final cachedResponse = await _getCachedResponse(
        '${_cacheKey}_page_$nextPage',
      );

      if (cachedResponse != null) {
        final cachedComments = await compute(
          _parseCommentsInBackground,
          cachedResponse,
        );
        if (mounted) {
          setState(() {
            _comments.addAll(cachedComments);
            _currentPage = nextPage;
            _hasMoreComments = cachedResponse['data']['has_more'] ?? false;
            _isLoadingMore = false;
          });
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString('user_uuid');
      if (uuid == null) throw Exception('No UUID found');

      final response = await ThinkProvider().fetchComments(
        uuid: uuid,
        contentId: widget.contentId,
        contentType: widget.contentType,
        page: nextPage,
        pageSize: _pageSize,
      );

      final newComments = await compute(_parseCommentsInBackground, response);

      // Cache the new page
      await _cacheResponse('${_cacheKey}_page_$nextPage', response);

      if (mounted) {
        setState(() {
          _comments.addAll(newComments);
          _currentPage = nextPage;
          _hasMoreComments = response['data']['has_more'] ?? false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreComments = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _animationController?.dispose();
    // Clean up cache when disposing
    _GlobalCommentsCache._clear();
    super.dispose();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Close keyboard when tapping outside input
        FocusScope.of(context).unfocus();
      },
      child: Container(
        height: widget.screenHeight * 0.7,
        decoration: BoxDecoration(
          color: widget.isDarkMode ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(widget.screenWidth * 0.04),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: widget.screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    '${_comments.length}',
                    style: TextStyle(
                      fontSize: widget.screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color:
                          widget.isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Comments list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _hasError
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    widget.isDarkMode
                                        ? Colors.white54
                                        : Colors.black54,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadComments,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                      : _comments.isEmpty
                      ? Center(
                        child: Text(
                          'No comments yet.\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                widget.isDarkMode
                                    ? Colors.white54
                                    : Colors.black54,
                            fontSize: widget.screenWidth * 0.04,
                          ),
                        ),
                      )
                      : _buildCommentsList(),
            ),

            // Replying to indicator
            if (_replyingToCommentId != null)
              GestureDetector(
                onTap: _cancelReply,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.screenWidth * 0.04,
                    vertical: widget.screenWidth * 0.02,
                  ),
                  color:
                      widget.isDarkMode
                          ? Colors.white12
                          : Colors.black.withValues(alpha: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Replying to $_replyingToUsername',
                        style: TextStyle(
                          color:
                              widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                          fontSize: widget.screenWidth * 0.035,
                        ),
                      ),
                      Icon(
                        Icons.close,
                        size: 16,
                        color:
                            widget.isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),

            // Comment input field
            _buildCommentInput(),

            // Heart Animation with RepaintBoundary
            if (_showHeart)
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showHeart ? 1.0 : 0.0,
                    child: Center(
                      child: ScaleTransition(
                        scale: _animation!,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.white.withAlpha(255),
                          size: widget.screenWidth * 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading && _comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
            TextButton(
              onPressed: _loadComments,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'No comments yet.\nBe the first to comment!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white54 : Colors.black54,
            fontSize: widget.screenWidth * 0.04,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
      padding: EdgeInsets.symmetric(horizontal: widget.screenWidth * 0.04),
      separatorBuilder:
          (context, index) => SizedBox(height: widget.screenWidth * 0.02),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(widget.screenWidth * 0.02),
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final comment = _comments[index];
        return _CommentItem(
          comment: comment,
          isDarkMode: widget.isDarkMode,
          screenWidth: widget.screenWidth,
          onReply: () => _setReplyingTo(comment),
          isLiked: _likedComments[comment.id] ?? false,
          onLike: () => _handleCommentLike(comment.id),
          onDoubleTap: () => _handleCommentDoubleTap(comment.id),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(widget.screenWidth * 0.04),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.isDarkMode ? Colors.white24 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(
                  color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              // Handle comment/reply posting here
              _commentController.clear();
              _commentFocusNode.unfocus();
              if (_replyingToCommentId != null) {
                setState(() {
                  _replyingToCommentId = null;
                  _replyingToUsername = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _showHeartAnimation() {
    _animationController?.forward();
    setState(() {
      _showHeart = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _animationController?.reverse().then((_) {
          setState(() {
            _showHeart = false;
          });
        });
      }
    });
  }

  void _setReplyingTo(Comment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToUsername = comment.authorProfile.name;
    });
  }

  void _handleCommentLike(String commentId) {
    setState(() {
      _likedComments[commentId] = !(_likedComments[commentId] ?? false);
    });
  }

  void _handleCommentDoubleTap(String commentId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _likedComments[commentId] = !(_likedComments[commentId] ?? false);
      if (_likedComments[commentId] ?? false) {
        _showHeartAnimation();
      }
    });
  }

  // Separate compute function for parsing
  static Future<List<Comment>> _parseCommentsInBackground(
    Map<String, dynamic> response,
  ) async {
    try {
      if (response['status'] != 'success' || response['data'] == null) {
        debugPrint('Invalid response format: $response');
        return [];
      }

      final commentsData = response['data']['comments'] as List<dynamic>;
      return commentsData.map((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error parsing comments: $e');
      return [];
    }
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isDarkMode;
  final double screenWidth;
  final VoidCallback onReply;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onDoubleTap;

  const _CommentItem({
    required this.comment,
    required this.isDarkMode,
    required this.screenWidth,
    required this.onReply,
    required this.isLiked,
    required this.onLike,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (details.primaryDelta! > 0 && details.primaryDelta! < 20) {
              onReply();
            }
          },
          onDoubleTap: onDoubleTap,
          child: _buildCommentContent(),
        ),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: screenWidth * 0.12),
            child: Column(
              children:
                  comment.replies
                      .map(
                        (reply) => _ReplyItem(
                          reply: reply,
                          isDarkMode: isDarkMode,
                          screenWidth: screenWidth,
                          onReply: onReply,
                        ),
                      )
                      .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentContent() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: screenWidth * 0.04,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: CachedNetworkImage(
                imageUrl: comment.authorProfile.profileImage,
                width: screenWidth * 0.08,
                height: screenWidth * 0.08,
                fit: BoxFit.cover,
                memCacheWidth: (screenWidth * 0.16).toInt(),
                memCacheHeight: (screenWidth * 0.16).toInt(),
                maxWidthDiskCache: 200,
                maxHeightDiskCache: 200,
                cacheKey: '${comment.authorProfile.profileImage}_thumb',
                fadeInDuration: const Duration(milliseconds: 150),
                placeholderFadeInDuration: const Duration(milliseconds: 150),
                imageBuilder:
                    (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                placeholder:
                    (context, url) => Container(
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                      child: Icon(
                        Icons.person,
                        size: screenWidth * 0.05,
                        color: isDarkMode ? Colors.white30 : Colors.black26,
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                      child: Icon(
                        Icons.person,
                        size: screenWidth * 0.05,
                        color: isDarkMode ? Colors.white30 : Colors.black26,
                      ),
                    ),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorProfile.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_getTimeAgo(comment.timestamp)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    _LikeButton(
                      isDarkMode: isDarkMode,
                      initialLiked: isLiked,
                      onLike: onLike,
                    ),
                  ],
                ),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  final Comment reply;
  final bool isDarkMode;
  final double screenWidth;
  final VoidCallback onReply;

  const _ReplyItem({
    required this.reply,
    required this.isDarkMode,
    required this.screenWidth,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.primaryDelta! > 0 && details.primaryDelta! < 20) {
          onReply();
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: screenWidth * 0.035,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: CachedNetworkImage(
                  imageUrl: reply.authorProfile.profileImage,
                  width: screenWidth * 0.07,
                  height: screenWidth * 0.07,
                  fit: BoxFit.cover,
                  memCacheWidth: (screenWidth * 0.14).toInt(),
                  memCacheHeight: (screenWidth * 0.14).toInt(),
                  maxWidthDiskCache: 150,
                  maxHeightDiskCache: 150,
                  cacheKey: '${reply.authorProfile.profileImage}_reply_thumb',
                  placeholder:
                      (context, url) => CircularProgressIndicator(
                        color: isDarkMode ? Colors.white : Colors.black,
                        strokeWidth: 2,
                      ),
                  errorWidget:
                      (context, url, error) => Icon(
                        Icons.person,
                        size: screenWidth * 0.045,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reply.authorProfile.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    reply.text,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final bool isDarkMode;
  final bool initialLiked;
  final VoidCallback onLike;

  const _LikeButton({
    required this.isDarkMode,
    required this.initialLiked,
    required this.onLike,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late bool isLiked;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    isLiked = widget.initialLiked;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      isLiked = !isLiked;
    });
    widget.onLike();

    if (isLiked) {
      _controller.forward().then((_) => _controller.reverse());
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color:
              isLiked
                  ? Colors.red
                  : (widget.isDarkMode ? Colors.white70 : Colors.black54),
        ),
      ),
    );
  }
}
