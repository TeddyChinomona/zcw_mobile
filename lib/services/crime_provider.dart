// lib/services/crime_provider.dart
//
// Central state container for the app.
// Extends ChangeNotifier so any Consumer<CrimeProvider> widget rebuilds
// automatically when notifyListeners() is called.
//
// Performance notes:
//   • _loadAll() fetches crime types and incidents in parallel (Future.wait).
//   • _fetchIncidents() only refetches incidents (crime types are stable).
//   • notifyListeners() is called only after both fetches complete, so the
//     UI never redraws with partially updated state.
//   • iconFor() is O(n) but crimeTypes is small (<20) and is called only
//     on tap events or legend builds — never during map rendering.

import 'package:flutter/material.dart';
import '../models/crime_incident.dart';
import 'api_service.dart';

class CrimeProvider extends ChangeNotifier {
  // ── Dependencies ────────────────────────────────────────────────────────────
  final ApiService _api;

  CrimeProvider({ApiService? api})
      : _api = api ?? ApiService() {
    // Kick off the initial data load immediately.
    // Fire-and-forget is intentional here — errors are captured internally.
    _loadAll();
  }

  // ── State ────────────────────────────────────────────────────────────────────
  List<CrimeIncident> _incidents  = [];
  List<CrimeType>     _crimeTypes = [];
  bool                _isLoading  = false;
  String?             _errorMessage;

  Set<int>       _selectedTypeIds = {};
  DateTimeRange? _dateRange;

  // ── Public getters ────────────────────────────────────────────────────────────
  List<CrimeIncident> get incidents    => _incidents;
  List<CrimeType>     get crimeTypes   => _crimeTypes;
  bool                get isLoading    => _isLoading;
  String?             get errorMessage => _errorMessage;
  Set<int>            get selectedTypeIds => _selectedTypeIds;
  DateTimeRange?      get dateRange    => _dateRange;

  bool get hasActiveFilters =>
      _selectedTypeIds.isNotEmpty || _dateRange != null;

  // ── Icon lookup ───────────────────────────────────────────────────────────────
  // Returns the emoji icon for a crime type name.
  // NOTE: For actual map-marker differentiation use CrimeIconWidget directly
  // (lib/utils/crime_icons.dart) — it uses colour-coded Canvas pins that
  // don't cause emoji font layout passes on the UI thread.
  // This method is kept for the IncidentDetailSheet bottom sheet header.
  String iconFor(String typeName) {
    // Try exact match first (fast path for small lists)
    for (final t in _crimeTypes) {
      if (t.name == typeName) return t.icon.isNotEmpty ? t.icon : '📍';
    }
    // Fallback
    return '📍';
  }

  // ── Filter mutations ──────────────────────────────────────────────────────────
  void applyFilters({
    required Set<int> typeIds,
    DateTimeRange? dateRange,
  }) {
    _selectedTypeIds = typeIds;
    _dateRange       = dateRange;
    notifyListeners(); // Update filter chips immediately
    _fetchIncidents(); // Then reload incidents with new params
  }

  void clearFilters() => applyFilters(typeIds: {}, dateRange: null);

  // ── Data loading ──────────────────────────────────────────────────────────────

  /// Load both crime types and incidents in parallel.
  /// Neither fetch blocks the other — whichever finishes last triggers the rebuild.
  Future<void> _loadAll() async {
    _setLoading(true);
    try {
      final results = await Future.wait([
        _api.fetchCrimeTypes(),
        _api.fetchPublicCrimes(),
      ]);
      _crimeTypes   = results[0] as List<CrimeType>;
      _incidents    = results[1] as List<CrimeIncident>;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _setLoading(false);
    }
  }

  /// Refetch incidents only, applying the active filter state.
  /// Crime types are stable and not re-requested.
  Future<void> _fetchIncidents() async {
    _setLoading(true);
    try {
      // When multiple type IDs are selected we pass the first one.
      // A future backend version may accept comma-separated IDs.
      final typeId = _selectedTypeIds.isNotEmpty
          ? _selectedTypeIds.first
          : null;

      _incidents = await _api.fetchPublicCrimes(
        crimeTypeId: typeId,
        startDate:   _dateRange?.start,
        endDate:     _dateRange?.end,
      );
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _setLoading(false);
    }
  }

  /// Public refresh — called by the refresh button in the app bar.
  Future<void> refresh() => _loadAll();

  // ── Internal helpers ──────────────────────────────────────────────────────────
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
