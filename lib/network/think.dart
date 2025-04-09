import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../network/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
// import 'dart:convert';

class ThinkProvider {
  final ApiService _apiService = ApiService();
  static final ThinkProvider _instance = ThinkProvider._internal();

  factory ThinkProvider() => _instance;
  ThinkProvider._internal() {
    try {
      // Ensure background isolate messenger is initialized
      final rootIsolateToken = RootIsolateToken.instance;
      if (rootIsolateToken != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        debugPrint(
          'BackgroundIsolateBinaryMessenger initialized in ThinkProvider',
        );
      }
      debugPrint('ThinkProvider initialized successfully');
    } catch (e) {
      debugPrint('Error initializing ThinkProvider: $e');
      rethrow;
    }
  }

  // Helper method for API calls - will be used by all endpoint functions
  @protected // Mark as protected to indicate it's for internal use
  Future<Map<String, dynamic>> _callFunction(
    String functionName,
    Map<String, dynamic> params, {
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('_callFunction called with:');
      debugPrint('functionName: $functionName');
      debugPrint('params: $params');
      debugPrint('cacheDuration: $cacheDuration');
      debugPrint('forceRefresh: $forceRefresh');

      // Format request body according to API spec - include all params
      final requestBody = {
        'function': functionName,
        ...params, // Spread all parameters into the request body
      };
      debugPrint('Formatted request body: $requestBody');

      final response = await _apiService.makeRequest(
        endpoint: ApiConfig.functions,
        body: requestBody,
        cacheDuration: cacheDuration,
        forceRefresh: forceRefresh,
      );
      debugPrint('API service response: $response');

      return response;
    } catch (e, stackTrace) {
      debugPrint('Error in _callFunction for $functionName: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'status': 'error',
        'message': 'Failed to execute function: $functionName',
        'error': e.toString(),
      };
    }
  }

  ///////////////////////////////////////
  ///     FUNCTION DEFINITIONS     ///
  /// ///////////////////////////////

  // Check app version
  Future<Map<String, dynamic>> checkVersion() async {
    try {
      final response = await _callFunction(
        ApiConfig.functionCheckVersion,
        {},
        cacheDuration: ApiConfig.longCache, // Use long cache for version checks
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'latest_version': response['latest_version'],
          'minimum_version': response['minimum_version'],
          'update_mandatory': response['update_mandatory'],
          'update_url': response['update_url'],
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to check version',
        };
      }
    } catch (e) {
      debugPrint('Error in checkVersion: $e');
      return {
        'status': 'error',
        'message': 'Failed to check app version',
        'error': e.toString(),
      };
    }
  }

  // Update user location
  Future<Map<String, dynamic>> updateLocation({
    required String uuid,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _callFunction(
        ApiConfig.functionUpdateLocation,
        {'uuid': uuid, 'latitude': latitude, 'longitude': longitude},
        cacheDuration:
            ApiConfig.shortCache, // Use short cache for location updates
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'data': {
            'location': response['data']['location'],
            'timestamp': response['data']['timestamp'],
          },
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to update location',
        };
      }
    } catch (e) {
      debugPrint('Error in updateLocation: $e');
      return {
        'status': 'error',
        'message': 'Failed to update location',
        'error': e.toString(),
      };
    }
  }

  // User signup
  Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String dob,
    required String email,
    required String gender,
    required String city,
    required bool consent,
  }) async {
    try {
      // Get UUID and phone number from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString('user_uuid');
      final phoneNumber = prefs.getString('phone_number');

      if (uuid == null || phoneNumber == null) {
        return {
          'status': 'error',
          'message': 'User not authenticated. Please login first.',
        };
      }

      final response = await _callFunction(ApiConfig.signup, {
        'uuid': uuid,
        'phone_number': phoneNumber,
        'firstName': firstName,
        'lastName': lastName,
        'dob': dob,
        'email': email,
        'gender': gender,
        'city': city,
        'consent': consent,
      });

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'reg_process': response['reg_process'],
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to sign up',
        };
      }
    } catch (e) {
      debugPrint('Error in signup: $e');
      return {
        'status': 'error',
        'message': 'Failed to complete signup',
        'error': e.toString(),
      };
    }
  }

  // Check user registration status
  Future<Map<String, dynamic>> checkRegistrationStatus({
    required String uuid,
  }) async {
    try {
      final response = await _callFunction(
        ApiConfig.functionCheckRegistrationStatus,
        {'uuid': uuid},
      );

      if (response['status'] == 200) {
        return {
          'status': response['status'],
          'message': response['message'],
          'reg_process': response['reg_process'],
        };
      } else {
        return {
          'status': 'error',
          'message':
              response['message'] ?? 'Failed to check registration status',
        };
      }
    } catch (e) {
      debugPrint('Error in checkRegistrationStatus: $e');
      return {
        'status': 'error',
        'message': 'Failed to check registration status',
        'error': e.toString(),
      };
    }
  }

  // Test AWS connection
  Future<Map<String, dynamic>> testAwsConnection() async {
    try {
      final response = await _callFunction(ApiConfig.testAwsConnection, {});

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'buckets': response['buckets'],
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to test AWS connection',
        };
      }
    } catch (e) {
      debugPrint('Error in testAwsConnection: $e');
      return {
        'status': 'error',
        'message': 'Failed to test AWS connection',
        'error': e.toString(),
      };
    }
  }

  // Submit profile creation step 1
  Future<Map<String, dynamic>> pC1Submit({
    required String uuid,
    required String profileImage,
    required String mandateImage1,
    required String mandateImage2,
    required String genderOrientation,
    required String bio,
    String? optionalImage1,
    String? optionalImage2,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'uuid': uuid,
        'profile_image': profileImage,
        'mandate_image_1': mandateImage1,
        'mandate_image_2': mandateImage2,
        'gender_orientation': genderOrientation,
        'bio': bio,
      };

      // Add optional images if provided
      if (optionalImage1 != null) {
        params['optional_image_1'] = optionalImage1;
      }
      if (optionalImage2 != null) {
        params['optional_image_2'] = optionalImage2;
      }

      final response = await _callFunction(ApiConfig.pC1Submit, params);

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'uuid': response['uuid'],
          'reg_status': response['reg_status'],
        };
      } else {
        return {
          'status': 'error',
          'message':
              response['message'] ?? 'Failed to submit profile creation step 1',
        };
      }
    } catch (e) {
      debugPrint('Error in pC1Submit: $e');
      return {
        'status': 'error',
        'message': 'Failed to submit profile creation step 1',
        'error': e.toString(),
      };
    }
  }

  // Submit profile creation step 2
  Future<Map<String, dynamic>> pC2Submit({
    required String uuid,
    required dynamic genderPreference, // Can be String or List<String>
    required dynamic agePreference,
  }) async {
    try {
      // Validate gender preference format
      if (genderPreference is! String && genderPreference is! List<String>) {
        return {
          'status': 'error',
          'message': 'gender_preference must be a string or list',
        };
      }

      // Convert single string preference to list if needed
      List<String> genderPrefList;
      if (genderPreference is String) {
        if (genderPreference.toLowerCase() == 'everyone') {
          genderPrefList = ['men', 'women', 'non-binary'];
        } else {
          genderPrefList = [genderPreference];
        }
      } else {
        genderPrefList = genderPreference;
      }

      // Validate gender preference values
      final validGenders = {'men', 'women', 'non-binary', 'everyone'};
      if (!genderPrefList.every(
        (g) => validGenders.contains(g.toLowerCase()),
      )) {
        return {
          'status': 'error',
          'message': 'Invalid gender preference values',
        };
      }

      final Map<String, dynamic> params = {
        'uuid': uuid,
        'gender_preference': genderPrefList,
        'age_preference': agePreference,
      };

      final response = await _callFunction(
        ApiConfig.pC2Submit, // Make sure this constant is defined
        params,
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'uuid': response['uuid'],
          'reg_status': response['reg_status'],
        };
      } else {
        return {
          'status': 'error',
          'message':
              response['message'] ?? 'Failed to submit profile creation step 2',
        };
      }
    } catch (e) {
      debugPrint('Error in pC2Submit: $e');
      return {
        'status': 'error',
        'message': 'Failed to submit profile creation step 2',
        'error': e.toString(),
      };
    }
  }

  // Submit profile creation step 3
  Future<Map<String, dynamic>> pC3Submit({
    required String uuid,
    required List<String> selectedInterests,
  }) async {
    try {
      final response = await _callFunction(ApiConfig.pC3Submit, {
        'uuid': uuid,
        'selected_interests': selectedInterests,
      });

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'reg_process':
              response['reg_process'], // Will be 'waitlisted' on success
        };
      } else {
        return {
          'status': 'error',
          'message':
              response['message'] ?? 'Failed to submit profile creation step 3',
        };
      }
    } catch (e) {
      debugPrint('Error in pC3Submit: $e');
      return {
        'status': 'error',
        'message': 'Failed to submit profile creation step 3',
        'error': e.toString(),
      };
    }
  }

  // Get available interests
  Future<Map<String, dynamic>> getInterests({required String uuid}) async {
    try {
      final response = await _callFunction(ApiConfig.getInterests, {
        'UUID':
            uuid, // Note: Backend expects 'UUID' (uppercase) as per the request body
      });

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'data':
              response['data'], // List of interest objects with id, name, icon_name, and category
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch interests',
        };
      }
    } catch (e) {
      debugPrint('Error in getInterests: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch interests',
        'error': e.toString(),
      };
    }
  }

  // Add a custom interest
  Future<Map<String, dynamic>> addCustomInterest({
    required String uuid,
    required String interestName,
  }) async {
    try {
      final response = await _callFunction(ApiConfig.addCustomInterest, {
        'uuid': uuid,
        'interest_name': interestName,
      });

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'data': response['data'], // Contains the created interest object
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to add custom interest',
        };
      }
    } catch (e) {
      debugPrint('Error in addCustomInterest: $e');
      return {
        'status': 'error',
        'message': 'Failed to add custom interest',
        'error': e.toString(),
      };
    }
  }

  // Submit Aadhar verification information
  Future<Map<String, dynamic>> submitAadharInfo({
    required String uuid,
    required Map<String, dynamic> kycData,
  }) async {
    try {
      final Map<String, dynamic> params = {'uuid': uuid};

      // Add KYC data parameters if they exist in the kycData map
      if (kycData.containsKey('AadharImage')) {
        params['AadharImage'] = kycData['AadharImage'];
      }
      if (kycData.containsKey('SelfieImage')) {
        params['SelfieImage'] = kycData['SelfieImage'];
      }
      if (kycData.containsKey('Aadhar_pdf_file')) {
        params['Aadhar_pdf_file'] = kycData['Aadhar_pdf_file'];
      }

      final response = await _callFunction(
        ApiConfig.submitAadharInfo, // Make sure this constant is defined
        params,
      );

      if (response['status'] == 'success') {
        return {'status': 'success', 'message': response['message']};
      } else {
        return {
          'status': 'error',
          'message':
              response['message'] ?? 'Failed to submit Aadhar information',
        };
      }
    } catch (e) {
      debugPrint('Error in submitAadharInfo: $e');
      return {
        'status': 'error',
        'message': 'Failed to submit Aadhar information',
        'error': e.toString(),
      };
    }
  }

  // Submit a support ticket
  Future<Map<String, dynamic>> submitSupportTicket({
    required String uuid,
    required String screenName,
    required String supportText,
    String? image1,
    String? image2,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'uuid': uuid,
        'screen_name': screenName,
        'support_text': supportText,
      };

      // Add optional images if provided
      if (image1 != null) {
        params['image1'] = image1;
      }
      if (image2 != null) {
        params['image2'] = image2;
      }

      final response = await _callFunction(
        ApiConfig.submitSupportTicket,
        params,
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'message': response['message'],
          'ticket_id': response['ticket_id'],
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to submit support ticket',
        };
      }
    } catch (e) {
      debugPrint('Error in submitSupportTicket: $e');
      return {
        'status': 'error',
        'message': 'Failed to submit support ticket',
        'error': e.toString(),
      };
    }
  }

  // Handle user logout
  Future<Map<String, dynamic>> logout({required String uuid}) async {
    try {
      final response = await _callFunction(ApiConfig.logout, {'uuid': uuid});

      if (response['status'] == 'success') {
        return {'status': 'success', 'message': response['message']};
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to logout',
        };
      }
    } catch (e) {
      debugPrint('Error in logout: $e');
      return {
        'status': 'error',
        'message': 'Failed to logout',
        'error': e.toString(),
      };
    }
  }

  // Delete user account and all associated data
  Future<Map<String, dynamic>> deleteAccount({required String uuid}) async {
    try {
      final response = await _callFunction(ApiConfig.deleteAccount, {
        'uuid': uuid,
      });

      if (response['status'] == 'success') {
        return {'status': 'success', 'message': response['message']};
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to delete account',
        };
      }
    } catch (e) {
      debugPrint('Error in deleteAccount: $e');
      return {
        'status': 'error',
        'message': 'Failed to delete account',
        'error': e.toString(),
      };
    }
  }

  // Get FAQs
  Future<Map<String, dynamic>> getFaqs() async {
    try {
      final response = await _callFunction(
        ApiConfig.getFaqs,
        {},
        cacheDuration:
            ApiConfig.longCache, // Cache FAQs since they rarely change
      );

      if (response['status'] == 'success') {
        return {'status': 'success', 'faqs': response['faqs']};
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch FAQs',
        };
      }
    } catch (e) {
      debugPrint('Error in getFaqs: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch FAQs',
        'error': e.toString(),
      };
    }
  }

  // Get events
  Future<Map<String, dynamic>> getEvents() async {
    try {
      final response = await _callFunction(
        ApiConfig.getEvents,
        {},
        cacheDuration:
            ApiConfig.mediumCache, // Cache events for a medium duration
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'events':
              response['events'], // List of events with presigned image URLs
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch events',
        };
      }
    } catch (e) {
      debugPrint('Error in getEvents: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch events',
        'error': e.toString(),
      };
    }
  }

  // Get intro video URL
  Future<Map<String, dynamic>> getIntroVideo() async {
    try {
      final response = await _callFunction(
        ApiConfig.getIntroVideo,
        {},
        cacheDuration:
            ApiConfig.longCache, // Cache URL since video rarely changes
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'data': {'intro_video_url': response['data']['intro_video_url']},
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch intro video',
        };
      }
    } catch (e) {
      debugPrint('Error in getIntroVideo: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch intro video',
        'error': e.toString(),
      };
    }
  }

  // Update event like status or check liked events
  Future<Map<String, dynamic>> updateEventLike({
    required String uuid,
    required String action,
    String? eventId,
  }) async {
    try {
      final Map<String, dynamic> params = {'uuid': uuid, 'action': action};

      // Add event_id only for like action
      if (action == 'like' && eventId != null) {
        params['event_id'] = eventId;
      }

      final response = await _callFunction(ApiConfig.updateEventLike, params);

      if (response['status'] == 'success') {
        return {'status': 'success', 'data': response['data']};
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to update event like',
        };
      }
    } catch (e) {
      debugPrint('Error in updateEventLike: $e');
      return {
        'status': 'error',
        'message': 'Failed to update event like',
        'error': e.toString(),
      };
    }
  }

  // Get paginated feed with profile information
  Future<Map<String, dynamic>> getFeed({
    required String uuid,
    int page = 1,
    String? profileId,
  }) async {
    try {
      final Map<String, dynamic> params = {'uuid': uuid, 'page': page};

      // Add profile_id if provided
      if (profileId != null) {
        params['profile_id'] = profileId;
      }

      final response = await _callFunction(
        ApiConfig.getFeed,
        params,
        cacheDuration:
            ApiConfig.shortCache, // Short cache since feed updates frequently
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'data':
              response['data'], // Contains posts, has_more, next_page, and total_posts
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch feed',
        };
      }
    } catch (e) {
      debugPrint('Error in getFeed: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch feed',
        'error': e.toString(),
      };
    }
  }

  // Get paginated snips feed with profile information
  Future<Map<String, dynamic>> getSnips({
    required String uuid,
    int page = 1,
    String? profileId,
  }) async {
    try {
      debugPrint(
        'getSnips called with uuid: $uuid, page: $page, profileId: $profileId',
      );

      final Map<String, dynamic> params = {'uuid': uuid, 'page': page};

      // Add profile_id if provided
      if (profileId != null) {
        params['profile_id'] = profileId;
      }

      debugPrint('Making API call with params: $params');
      final response = await _callFunction(
        ApiConfig.getSnips,
        params,
        cacheDuration: ApiConfig.shortCache,
      );
      debugPrint('API response received: $response');

      if (response['status'] == 'success') {
        return {'status': 'success', 'data': response['data']};
      } else {
        debugPrint('API call failed with response: $response');
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch snips',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error in getSnips: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'status': 'error',
        'message': 'Failed to fetch snips',
        'error': e.toString(),
      };
    }
  }

  // Fetch detailed profile information
  Future<Map<String, dynamic>> fetchProfile({
    required String uuid,
    required String profileId,
  }) async {
    try {
      final response = await _callFunction(
        ApiConfig.fetchProfile,
        {'uuid': uuid, 'profile_id': profileId},
        cacheDuration:
            ApiConfig
                .mediumCache, // Medium cache since profile data changes occasionally
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'data': response['data'], // Contains complete profile information
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch profile',
        };
      }
    } catch (e) {
      debugPrint('Error in fetchProfile: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch profile',
        'error': e.toString(),
      };
    }
  }

  // Fetch comments for a specific content
  Future<Map<String, dynamic>> fetchComments({
    required String uuid,
    required String contentType,
    required String contentId,
    int page = 1, // Default to first page
    int pageSize = 10, // Default page size
  }) async {
    try {
      // Validate content type
      final validContentTypes = ['post', 'snip', 'story'];
      if (!validContentTypes.contains(contentType)) {
        return {
          'status': 'error',
          'message':
              'Invalid content type. Must be one of: ${validContentTypes.join(", ")}',
        };
      }

      // Add retry logic with exponential backoff
      int retryCount = 0;
      const maxRetries = 3;
      Duration delay = const Duration(milliseconds: 500);

      while (retryCount < maxRetries) {
        try {
          final response = await _callFunction(ApiConfig.fetchComments, {
            'uuid': uuid,
            'content_type': contentType,
            'content_id': contentId,
            'page': page,
            'page_size': pageSize,
          }, cacheDuration: ApiConfig.shortCache);

          if (response['status'] == 'success') {
            // Handle empty comments case explicitly
            if (response['data'] == null ||
                response['data']['comments'] == null) {
              return {
                'status': 'success',
                'data': {
                  'comments': [],
                  'total_comments': 0,
                  'current_page': page,
                  'total_pages': 1,
                  'has_more': false,
                },
              };
            }

            // Get all comments
            final allComments = response['data']['comments'] as List;
            final totalComments = response['data']['total_comments'] as int;

            // Calculate pagination
            final startIndex = (page - 1) * pageSize;
            final endIndex = startIndex + pageSize;
            final totalPages = (totalComments / pageSize).ceil();

            // Get paginated comments
            final paginatedComments = allComments.sublist(
              startIndex,
              endIndex > allComments.length ? allComments.length : endIndex,
            );

            return {
              'status': 'success',
              'data': {
                'comments': paginatedComments,
                'total_comments': totalComments,
                'current_page': page,
                'total_pages': totalPages,
                'has_more': page < totalPages,
              },
            };
          } else {
            // Only retry on connection errors, not on validation errors
            if (response['message']?.contains('Failed to connect') == true) {
              throw Exception('Connection error');
            }
            return response;
          }
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            rethrow;
          }
          debugPrint(
            'Retrying fetchComments after error: $e (attempt $retryCount)',
          );
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        }
      }

      throw Exception('Failed to fetch comments after $maxRetries retries');
    } catch (e) {
      debugPrint('Error in fetchComments: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch comments',
        'error': e.toString(),
      };
    }
  }

  // Fetch author profiles in batch
  Future<Map<String, dynamic>> fetchAuthorProfiles({
    required String uuid,
    required List<String> authorIds,
  }) async {
    try {
      debugPrint('Fetching author profiles for ${authorIds.length} authors');

      // Use the correct endpoint format
      final response = await _callFunction(
        ApiConfig
            .fetchProfile, // Use fetchProfile instead of fetchAuthorProfiles
        {
          'uuid': uuid,
          'author_ids': authorIds, // Pass author IDs as a parameter
        },
      );

      if (response['status'] == 'success') {
        return {
          'status': 'success',
          'data': {'profiles': response['data']['profiles'] ?? []},
        };
      } else {
        return {
          'status': 'error',
          'message': response['message'] ?? 'Failed to fetch author profiles',
        };
      }
    } catch (e) {
      debugPrint('Error fetching author profiles: $e');
      return {
        'status': 'error',
        'message': 'Failed to fetch author profiles: $e',
      };
    }
  }

  // Clean up resources
  void dispose() {
    _apiService.dispose();
  }
}
