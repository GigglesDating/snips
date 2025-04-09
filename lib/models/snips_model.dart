import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'utils/video_quality.dart';

class VideoResolution {
  final int width;
  final int height;
  final double aspectRatio;
  final int bitrate;

  const VideoResolution({
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.bitrate,
  });

  factory VideoResolution.fromJson(Map<String, dynamic> json) {
    return VideoResolution(
      width: json['width'] as int,
      height: json['height'] as int,
      aspectRatio: json['aspect_ratio'] as double,
      bitrate: json['bitrate'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'aspect_ratio': aspectRatio,
    'bitrate': bitrate,
  };
}

// Video analytics enums and classes
enum VideoPlaybackState {
  initial,
  loading,
  buffering,
  playing,
  paused,
  error,
  completed,
}

enum CacheStatus { notCached, caching, cached, error }

class VideoAnalytics {
  final int viewCount;
  final int completeViewCount;
  final double averageWatchDuration;
  final Map<int, int> dropOffPoints; // second -> count
  final int replayCount;

  // Engagement metrics
  final double likeRatio;
  final double commentEngagementRate;
  final int shareCount;
  final int saveCount;
  final Map<int, Map<String, int>>
  interactionPoints; // second -> {action: count}

  // Performance metrics
  final int bufferEvents;
  final int qualitySwitches;
  final Map<String, Duration> networkTypePlayback; // network type -> duration
  final int errorCount;
  final Duration averageLoadTime;

  const VideoAnalytics({
    this.viewCount = 0,
    this.completeViewCount = 0,
    this.averageWatchDuration = 0.0,
    this.dropOffPoints = const {},
    this.replayCount = 0,
    this.likeRatio = 0.0,
    this.commentEngagementRate = 0.0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.interactionPoints = const {},
    this.bufferEvents = 0,
    this.qualitySwitches = 0,
    this.networkTypePlayback = const {},
    this.errorCount = 0,
    this.averageLoadTime = const Duration(),
  });

  factory VideoAnalytics.fromJson(Map<String, dynamic> json) {
    return VideoAnalytics(
      viewCount: json['view_count'] as int? ?? 0,
      completeViewCount: json['complete_view_count'] as int? ?? 0,
      averageWatchDuration: json['average_watch_duration'] as double? ?? 0.0,
      dropOffPoints:
          (json['drop_off_points'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(int.parse(k), v as int),
          ) ??
          {},
      replayCount: json['replay_count'] as int? ?? 0,
      likeRatio: json['like_ratio'] as double? ?? 0.0,
      commentEngagementRate: json['comment_engagement_rate'] as double? ?? 0.0,
      shareCount: json['share_count'] as int? ?? 0,
      saveCount: json['save_count'] as int? ?? 0,
      interactionPoints:
          (json['interaction_points'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              int.parse(k),
              (v as Map<String, dynamic>).map(
                (k2, v2) => MapEntry(k2, v2 as int),
              ),
            ),
          ) ??
          {},
      bufferEvents: json['buffer_events'] as int? ?? 0,
      qualitySwitches: json['quality_switches'] as int? ?? 0,
      networkTypePlayback:
          (json['network_type_playback'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Duration(milliseconds: v as int)),
          ) ??
          {},
      errorCount: json['error_count'] as int? ?? 0,
      averageLoadTime: Duration(
        milliseconds: json['average_load_time'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'view_count': viewCount,
    'complete_view_count': completeViewCount,
    'average_watch_duration': averageWatchDuration,
    'drop_off_points': dropOffPoints.map((k, v) => MapEntry(k.toString(), v)),
    'replay_count': replayCount,
    'like_ratio': likeRatio,
    'comment_engagement_rate': commentEngagementRate,
    'share_count': shareCount,
    'save_count': saveCount,
    'interaction_points': interactionPoints.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'buffer_events': bufferEvents,
    'quality_switches': qualitySwitches,
    'network_type_playback': networkTypePlayback.map(
      (k, v) => MapEntry(k, v.inMilliseconds),
    ),
    'error_count': errorCount,
    'average_load_time': averageLoadTime.inMilliseconds,
  };

  VideoAnalytics copyWith({
    int? viewCount,
    int? completeViewCount,
    double? averageWatchDuration,
    Map<int, int>? dropOffPoints,
    int? replayCount,
    double? likeRatio,
    double? commentEngagementRate,
    int? shareCount,
    int? saveCount,
    Map<int, Map<String, int>>? interactionPoints,
    int? bufferEvents,
    int? qualitySwitches,
    Map<String, Duration>? networkTypePlayback,
    int? errorCount,
    Duration? averageLoadTime,
  }) {
    return VideoAnalytics(
      viewCount: viewCount ?? this.viewCount,
      completeViewCount: completeViewCount ?? this.completeViewCount,
      averageWatchDuration: averageWatchDuration ?? this.averageWatchDuration,
      dropOffPoints: dropOffPoints ?? this.dropOffPoints,
      replayCount: replayCount ?? this.replayCount,
      likeRatio: likeRatio ?? this.likeRatio,
      commentEngagementRate:
          commentEngagementRate ?? this.commentEngagementRate,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
      interactionPoints: interactionPoints ?? this.interactionPoints,
      bufferEvents: bufferEvents ?? this.bufferEvents,
      qualitySwitches: qualitySwitches ?? this.qualitySwitches,
      networkTypePlayback: networkTypePlayback ?? this.networkTypePlayback,
      errorCount: errorCount ?? this.errorCount,
      averageLoadTime: averageLoadTime ?? this.averageLoadTime,
    );
  }
}

class SnipModel {
  final String snipId;
  final VideoContent video;
  final DateTime timestamp;
  final List<String> commentIds;
  final String description;
  final int likesCount;
  final int commentsCount;
  final String authorProfileId;
  final UserModel authorProfile;

  SnipModel({
    required this.snipId,
    required this.video,
    required this.timestamp,
    required this.commentIds,
    required this.description,
    required this.likesCount,
    required this.commentsCount,
    required this.authorProfileId,
    required this.authorProfile,
  });

  factory SnipModel.fromJson(Map<String, dynamic> json) {
    return SnipModel(
      snipId: json['snip_id'].toString(),
      video: VideoContent.fromJson(json['video'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      commentIds:
          (json['comment_ids'] as List).map((e) => e.toString()).toList(),
      description: json['description'] as String,
      likesCount: json['likes_count'] as int,
      commentsCount: json['comments_count'] as int,
      authorProfileId: json['author_profile_id'].toString(),
      authorProfile: UserModel.fromJson(
        json['author_profile'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snip_id': snipId,
      'video': video.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'comment_ids': commentIds,
      'description': description,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'author_profile_id': authorProfileId,
      'author_profile': authorProfile.toJson(),
    };
  }

  // Add copyWith method
  SnipModel copyWith({
    String? snipId,
    VideoContent? video,
    DateTime? timestamp,
    List<String>? commentIds,
    String? description,
    int? likesCount,
    int? commentsCount,
    String? authorProfileId,
    UserModel? authorProfile,
  }) {
    return SnipModel(
      snipId: snipId ?? this.snipId,
      video: video ?? this.video,
      timestamp: timestamp ?? this.timestamp,
      commentIds: commentIds ?? this.commentIds,
      description: description ?? this.description,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorProfile: authorProfile ?? this.authorProfile,
    );
  }
}

class VideoContent {
  final String source;
  final String? thumbnail;
  final Map<VideoQuality, String> qualityUrls;
  final VideoQuality currentQuality;
  final int duration;
  final VideoResolution resolution;
  final VideoPlaybackState playbackState;
  final CacheStatus cacheStatus;
  final VideoAnalytics analytics;
  final String? error;

  VideoContent({
    required this.source,
    this.thumbnail,
    required this.qualityUrls,
    this.currentQuality = VideoQuality.auto,
    required this.duration,
    required this.resolution,
    this.playbackState = VideoPlaybackState.initial,
    this.cacheStatus = CacheStatus.notCached,
    this.analytics = const VideoAnalytics(),
    this.error,
  });

  factory VideoContent.fromJson(Map<String, dynamic> json) {
    try {
      // Get the source URL and thumbnail
      final sourceUrl = json['source'] as String? ?? '';
      final thumbnail = json['thumbnail'] as String?;

      // Parse quality URLs if available
      final qualityUrls = <VideoQuality, String>{};
      if (json['quality_urls'] != null) {
        (json['quality_urls'] as Map<String, dynamic>).forEach((key, value) {
          final quality = VideoQuality.values.firstWhere(
            (q) =>
                q.toString().split('.').last.toLowerCase() == key.toLowerCase(),
            orElse: () => VideoQuality.auto,
          );
          qualityUrls[quality] = value as String;
        });
      }

      // If no quality URLs provided, use source URL as auto quality
      if (qualityUrls.isEmpty) {
        qualityUrls[VideoQuality.auto] = sourceUrl;
      }

      // Parse resolution if available
      VideoResolution resolution;
      if (json['resolution'] != null) {
        resolution = VideoResolution.fromJson(
          json['resolution'] as Map<String, dynamic>,
        );
      } else {
        resolution = const VideoResolution(
          width: 0,
          height: 0,
          aspectRatio: 9 / 16, // Default vertical video aspect ratio
          bitrate: 0,
        );
      }

      return VideoContent(
        source: sourceUrl,
        thumbnail: thumbnail,
        qualityUrls: qualityUrls,
        duration: json['duration'] as int? ?? 0,
        resolution: resolution,
      );
    } catch (e) {
      debugPrint('Error parsing VideoContent: $e');
      return VideoContent(
        source: '',
        qualityUrls: {VideoQuality.auto: ''},
        duration: 0,
        resolution: const VideoResolution(
          width: 0,
          height: 0,
          aspectRatio: 9 / 16,
          bitrate: 0,
        ),
        error: e.toString(),
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'thumbnail': thumbnail,
    'quality_urls': Map<String, String>.fromEntries(
      qualityUrls.entries.map(
        (e) => MapEntry(e.key.toString().split('.').last, e.value),
      ),
    ),
    'current_quality': currentQuality.toString().split('.').last,
    'duration': duration,
    'resolution': resolution.toJson(),
    'playback_state': playbackState.toString().split('.').last,
    'cache_status': cacheStatus.toString().split('.').last,
    'analytics': analytics.toJson(),
    'error': error,
  };

  VideoContent copyWith({
    String? source,
    String? thumbnail,
    Map<VideoQuality, String>? qualityUrls,
    VideoQuality? currentQuality,
    int? duration,
    VideoResolution? resolution,
    VideoPlaybackState? playbackState,
    CacheStatus? cacheStatus,
    VideoAnalytics? analytics,
    String? error,
  }) {
    return VideoContent(
      source: source ?? this.source,
      thumbnail: thumbnail ?? this.thumbnail,
      qualityUrls: qualityUrls ?? this.qualityUrls,
      currentQuality: currentQuality ?? this.currentQuality,
      duration: duration ?? this.duration,
      resolution: resolution ?? this.resolution,
      playbackState: playbackState ?? this.playbackState,
      cacheStatus: cacheStatus ?? this.cacheStatus,
      analytics: analytics ?? this.analytics,
      error: error ?? this.error,
    );
  }
}

class SnipsResponse {
  final List<SnipModel> snips;
  final bool hasMore;
  final int? nextPage;
  final int totalSnips;

  SnipsResponse({
    required this.snips,
    required this.hasMore,
    this.nextPage,
    required this.totalSnips,
  });

  factory SnipsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return SnipsResponse(
      snips:
          (data['snips'] as List)
              .map((snip) => SnipModel.fromJson(snip as Map<String, dynamic>))
              .toList(),
      hasMore: data['has_more'] as bool,
      nextPage: data['next_page'] as int?,
      totalSnips: data['total_snips'] as int,
    );
  }

  // Helper method to parse API response
  static SnipsResponse fromApiResponse(Map<String, dynamic> apiResponse) {
    if (apiResponse['status'] != 'success') {
      throw Exception(
        apiResponse['message'] ?? 'Failed to parse snips response',
      );
    }
    return SnipsResponse.fromJson(apiResponse);
  }
}
