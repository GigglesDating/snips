class VideoAnalytics {
  final int viewCount;
  final int completeViewCount;
  final double averageWatchDuration;
  final Map<int, int> dropOffPoints; // second -> count
  final int replayCount;
  final int bufferEvents;
  final int qualitySwitches;
  final Map<String, Duration> networkTypePlayback; // network type -> duration
  final int errorCount;
  final Duration averageLoadTime;
  final DateTime? lastBufferTime;

  const VideoAnalytics({
    this.viewCount = 0,
    this.completeViewCount = 0,
    this.averageWatchDuration = 0.0,
    this.dropOffPoints = const {},
    this.replayCount = 0,
    this.bufferEvents = 0,
    this.qualitySwitches = 0,
    this.networkTypePlayback = const {},
    this.errorCount = 0,
    this.averageLoadTime = const Duration(),
    this.lastBufferTime,
  });

  VideoAnalytics copyWith({
    int? viewCount,
    int? completeViewCount,
    double? averageWatchDuration,
    Map<int, int>? dropOffPoints,
    int? replayCount,
    int? bufferEvents,
    int? qualitySwitches,
    Map<String, Duration>? networkTypePlayback,
    int? errorCount,
    Duration? averageLoadTime,
    DateTime? lastBufferTime,
  }) {
    return VideoAnalytics(
      viewCount: viewCount ?? this.viewCount,
      completeViewCount: completeViewCount ?? this.completeViewCount,
      averageWatchDuration: averageWatchDuration ?? this.averageWatchDuration,
      dropOffPoints: dropOffPoints ?? this.dropOffPoints,
      replayCount: replayCount ?? this.replayCount,
      bufferEvents: bufferEvents ?? this.bufferEvents,
      qualitySwitches: qualitySwitches ?? this.qualitySwitches,
      networkTypePlayback: networkTypePlayback ?? this.networkTypePlayback,
      errorCount: errorCount ?? this.errorCount,
      averageLoadTime: averageLoadTime ?? this.averageLoadTime,
      lastBufferTime: lastBufferTime ?? this.lastBufferTime,
    );
  }
}
