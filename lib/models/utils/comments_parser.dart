import '../user_model.dart';
import 'package:flutter/foundation.dart';

class Comment {
  final String id;
  final String text;
  final DateTime timestamp;
  final int likesCount;
  final String authorProfileId;
  final UserModel authorProfile;
  final String? replyToCommentId;
  final List<Comment> replies;
  final String contentId;
  final String contentType;

  Comment({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.likesCount,
    required this.authorProfileId,
    required this.authorProfile,
    this.replyToCommentId,
    this.replies = const [],
    required this.contentId,
    required this.contentType,
  });

  // Parse a single comment from JSON
  factory Comment.fromJson(Map<String, dynamic> json, {bool isReply = false}) {
    try {
      debugPrint('Parsing comment: $json');

      final replies =
          isReply
              ? const <Comment>[]
              : (json['replies'] as List?)
                      ?.map(
                        (reply) => Comment.fromJson(
                          reply as Map<String, dynamic>,
                          isReply: true,
                        ),
                      )
                      .toList() ??
                  const [];

      // Handle different ID field names
      final id =
          json['comment_id']?.toString() ??
          json['reply_id']?.toString() ??
          json['id']?.toString() ??
          '';

      // Handle different timestamp formats
      DateTime timestamp;
      try {
        timestamp = DateTime.parse(json['timestamp']?.toString() ?? '');
      } catch (e) {
        debugPrint('Error parsing timestamp: $e');
        timestamp = DateTime.now();
      }

      // Handle missing or malformed author_profile
      Map<String, dynamic> authorProfileJson;
      if (json['author_profile'] is Map) {
        authorProfileJson = json['author_profile'] as Map<String, dynamic>;
      } else {
        debugPrint('Invalid author_profile format: ${json['author_profile']}');
        authorProfileJson = {
          'name': 'Unknown User',
          'profile_image': '',
          // Add other required fields with default values
        };
      }

      return Comment(
        id: id,
        text: json['text']?.toString() ?? '',
        timestamp: timestamp,
        likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
        authorProfileId: json['author_profile_id']?.toString() ?? '',
        authorProfile: UserModel.fromJson(authorProfileJson),
        replyToCommentId:
            isReply ? json['replytocomment_id']?.toString() : null,
        replies: replies,
        contentId: json['content_id']?.toString() ?? '',
        contentType: json['content_type']?.toString() ?? '',
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing comment: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  // Convert comment to JSON
  Map<String, dynamic> toJson({bool isReply = false}) {
    return {
      if (isReply) 'reply_id': id else 'comment_id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'likes_count': likesCount,
      'author_profile_id': authorProfileId,
      'author_profile': authorProfile.toJson(),
      if (isReply && replyToCommentId != null)
        'replytocomment_id': replyToCommentId,
      'content_id': contentId,
      'content_type': contentType,
      if (!isReply)
        'replies': replies.map((r) => r.toJson(isReply: true)).toList(),
    };
  }

  // Helper method to parse a list of comments
  static List<Comment> parseCommentsList(List<dynamic> jsonList) {
    final List<Comment> comments = [];
    for (var json in jsonList) {
      try {
        if (json is Map<String, dynamic>) {
          comments.add(Comment.fromJson(json));
        } else {
          debugPrint('Invalid comment format: $json');
        }
      } catch (e) {
        debugPrint('Error parsing comment in list: $e');
        // Continue parsing other comments
        continue;
      }
    }
    return comments;
  }

  // Parse the complete comments API response
  static Map<String, dynamic> parseFromApi(Map<String, dynamic> apiResponse) {
    try {
      debugPrint('Parsing API response: $apiResponse');

      if (apiResponse['status'] != 'success') {
        debugPrint(
          'API response status is not success: ${apiResponse['status']}',
        );
        return {
          'status': 'error',
          'message': apiResponse['message'] ?? 'Invalid response format',
          'data': {'comments': [], 'total_comments': 0},
        };
      }

      final data = apiResponse['data'] as Map<String, dynamic>? ?? {};
      final commentsList = data['comments'] as List? ?? [];

      return {
        'status': 'success',
        'data': {
          'comments': parseCommentsList(commentsList),
          'total_comments':
              (data['total_comments'] as num?)?.toInt() ?? commentsList.length,
          'has_more': data['has_more'] ?? false,
          'next_page': data['next_page'],
        },
      };
    } catch (e, stackTrace) {
      debugPrint('Error parsing API response: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('API Response: $apiResponse');
      return {
        'status': 'error',
        'message': 'Error parsing comments: $e',
        'data': {
          'comments': [],
          'total_comments': 0,
          'has_more': false,
          'next_page': null,
        },
      };
    }
  }
}
