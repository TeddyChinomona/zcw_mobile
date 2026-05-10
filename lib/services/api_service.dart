// lib/services/api_service.dart
//
// Thin HTTP client that wraps dart:io/package:http to talk to ZCW-BACKEND.
// All methods throw [ApiException] on error so the UI only handles one type.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/crime_incident.dart';

// ── Custom exception ─────────────────────────────────────────────────────────
// Wraps network errors, HTTP error codes, and JSON parse failures into a
// single exception type so CrimeProvider.catch() stays simple.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

// ── ApiService ───────────────────────────────────────────────────────────────
class ApiService {
  // Reuse a single http.Client across calls to benefit from keep-alive
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // ── Private helper ──────────────────────────────────────────────────────────
  // Performs a GET request, validates the status code, and decodes JSON.
  // [queryParams] are appended as a query string, e.g. ?crime_type_id=3
  Future<dynamic> _get(String path, [Map<String, String>? queryParams]) async {
    // Build the full URI — Uri handles query-string encoding automatically
    final uri = Uri.parse('${AppConfig.baseUrl}$path').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(AppConfig.requestTimeout); // throws TimeoutException if exceeded

      if (response.statusCode == 200) {
        // utf8.decode handles non-ASCII characters (e.g. Shona suburb names)
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw ApiException(
          'HTTP ${response.statusCode} from $path',
        );
      }
    } on ApiException {
      rethrow; // already wrapped — pass through unchanged
    } catch (e) {
      // Covers SocketException (no network), TimeoutException, FormatException, etc.
      throw ApiException('Request failed: $e');
    }
  }

  // ── Public API methods ──────────────────────────────────────────────────────

  /// Fetches anonymized crime incident pins from /api/public/crimes/.
  ///
  /// Optional filters are forwarded as query params — the backend does the
  /// filtering, so we receive only the data we intend to display.
  Future<List<CrimeIncident>> fetchPublicCrimes({
    int? crimeTypeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Build the query param map only with non-null values
    final params = <String, String>{};
    if (crimeTypeId != null) {
      params['crime_type_id'] = crimeTypeId.toString();
    }
    if (startDate != null) {
      // Backend expects YYYY-MM-DD; toIso8601String() returns YYYY-MM-DDTHH:MM:SS.mmmZ
      params['start_date'] = startDate.toIso8601String().substring(0, 10);
    }
    if (endDate != null) {
      params['end_date'] = endDate.toIso8601String().substring(0, 10);
    }

    final data = await _get(
      AppConfig.publicCrimesPath,
      params.isEmpty ? null : params,
    );

    // Cast the decoded JSON array and deserialize each element
    return (data as List)
        .map((json) => CrimeIncident.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetches all crime type categories from /api/public/crime-types/.
  /// Used to populate the filter chip list and icon lookups.
  Future<List<CrimeType>> fetchCrimeTypes() async {
    final data = await _get(AppConfig.publicCrimeTypesPath);
    return (data as List)
        .map((json) => CrimeType.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
