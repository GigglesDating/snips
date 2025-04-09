class ApiConfig {
  // Base URLs
  static const String baseUrl = 'https://backend.gigglesdating.com/api';

  // Endpoints
  static const String requestOtp = '$baseUrl/request-otp';
  static const String verifyOtp = '$baseUrl/verify-otp';
  static const String database = '$baseUrl/database';
  static const String functions = '$baseUrl/functions/';

  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
  };

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Phone number configuration
  static const String countryCode = '+91';
  static const int phoneNumberLength = 10;
  static const int otpLength = 4;

  // Cache durations
  static const Duration shortCache = Duration(minutes: 5);
  static const Duration mediumCache = Duration(minutes: 15);
  static const Duration longCache = Duration(hours: 1);
  static const Duration veryLongCache = Duration(days: 1);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  // Function names (to avoid typos and maintain consistency)
  static const String functionCheckVersion = 'check_version';
  static const String functionUpdateLocation = 'update_location';
  static const String functionCheckRegistrationStatus =
      'check_registration_status';
  static const String signup = 'signup';
  static const String RequestOtp = 'request_otp';
  static const String VerifyOtp = 'verify_otp';
  static const String testAwsConnection = 'test_aws_connection';
  static const String pC1Submit = 'p_c1_submit';
  static const String pC2Submit = 'p_c2_submit';
  static const String pC3Submit = 'p_c3_submit';
  static const String getInterests = 'get_interests';
  static const String addCustomInterest = 'add_custom_interest';
  static const String submitAadharInfo = 'submit_aadhar_info';
  static const String submitSupportTicket = 'submit_support_ticket';
  static const String logout = 'logout';
  static const String deleteAccount = 'delete_account';
  static const String getFaqs = 'get_faqs';
  static const String getEvents = 'get_events';
  static const String getIntroVideo = 'get_intro_video';
  static const String updateEventLike = 'update_event_like';
  static const String getFeed = 'get_feed';
  static const String getSnips = 'get_snips';
  static const String fetchProfile = 'fetch_profile';
  static const String fetchComments = 'fetch_comments';
  static const String fetchAuthorProfiles = 'fetch_author_profiles';

  // Add more function names as needed

  // Response status codes
  static const int statusSuccess = 200;
  static const int statusCreated = 201;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusServerError = 500;

  // Generate endpoint URL
  static String getFunctionEndpoint(String functionName) {
    return functions;
  }

  // Helper method to check if response is successful
  static bool isSuccessfulResponse(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  // Helper method to get appropriate cache duration based on function
  static Duration getCacheDuration(String functionName) {
    switch (functionName) {
      case functionCheckVersion:
        return longCache;
      case functionCheckRegistrationStatus:
        return shortCache;
      case RequestOtp:
      case VerifyOtp:
        return Duration.zero; // No cache for OTP functions
      default:
        return mediumCache;
    }
  }
}
