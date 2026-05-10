// lib/config/app_config.dart
//
// Central place for all backend connection settings.
// Edit baseUrl to point at the correct ZCW-BACKEND instance.

class AppConfig {
  AppConfig._(); // private constructor — this class is never instantiated

  // ── Base URL ────────────────────────────────────────────────────────────────
  // Uncomment the line that matches your environment.

  // Android emulator reaches the host machine via 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:8000';

  // iOS simulator / macOS uses localhost directly
  // static const String baseUrl = 'http://127.0.0.1:8000';

  // Production Django backend
  // static const String baseUrl = 'https://zcw-backend.example.com';

  // ── API prefix ─────────────────────────────────────────────────────────────
  // All endpoints live under /api/ — matches Django urls.py include()
  static const String _apiPrefix = '/api';

  // ── Public endpoints (no authentication required) ──────────────────────────
  // Returns anonymized crime pins for the map
  static const String publicCrimesPath = '$_apiPrefix/public/crimes/';

  // Returns the list of crime categories with emoji icons and counts
  static const String publicCrimeTypesPath = '$_apiPrefix/public/crime-types/';

  // ── Request timeout ────────────────────────────────────────────────────────
  // How long ApiService waits before throwing a TimeoutException
  static const Duration requestTimeout = Duration(seconds: 15);
}
