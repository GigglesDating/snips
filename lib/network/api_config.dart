class ApiEndpoint {
  final String path;
  final String method;
  final bool requiresAuth;

  const ApiEndpoint({
    required this.path,
    required this.method,
    this.requiresAuth = true,
  });
}

class ApiConfig {
  // Auth endpoints
  static const login = ApiEndpoint(
    path: '/api/auth/login',
    method: 'POST',
    requiresAuth: false,
  );

  static const signup = ApiEndpoint(
    path: '/api/auth/signup',
    method: 'POST',
    requiresAuth: false,
  );

  // Snips endpoints
  static const getSnips = ApiEndpoint(path: '/api/snips', method: 'GET');

  static const getSnipVideoUrl = ApiEndpoint(
    path: '/api/snips/{snip_id}/video-url',
    method: 'GET',
  );

  // Profile endpoints
  static const getProfile = ApiEndpoint(path: '/api/profile', method: 'GET');

  static const updateProfile = ApiEndpoint(path: '/api/profile', method: 'PUT');

  // Add other endpoints as needed...
}
