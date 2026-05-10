// lib/screens/home_screen.dart
//
// Main screen: interactive map with crime pin markers, app bar, filter chips,
// zoom controls, and the slide-up statistics panel.
//
// NEW FEATURES:
//   1. Google Maps-style current location indicator — pulsing blue dot with
//      accuracy ring. Rendered as a Marker on the map layer.
//   2. Full-screen centered loading spinner shown while refreshing crime data.
//
// Location strategy: the map renders immediately using Harare CBD as the
// initial centre. _fetchDeviceLocation() runs in the background and, if it
// succeeds, calls _mapController.move() to pan smoothly to the device position.
// This means there is NEVER a blocking spinner waiting for GPS.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // Device GPS / network location
import '../models/crime_incident.dart';
import '../services/crime_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/incident_detail_sheet.dart';
import '../widgets/stats_summary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // flutter_map controller — used for programmatic pan/zoom
  final MapController _mapController = MapController();

  // Fallback centre: Harare CBD (WGS-84). Used immediately on first render
  // and as a permanent fallback if location permission is denied or GPS times out.
  static const LatLng _harareCenter = LatLng(-17.8292, 31.0522);
  static const double _initialZoom  = 18.0;

  bool _showStats = false;

  // Tracks whether the user manually triggered a refresh (shows full-screen spinner)
  bool _isRefreshing = false;

  // Stores the device's current GPS coordinates once obtained.
  // null means location has not yet been fetched or was denied.
  LatLng? _deviceLocation;

  // Drives the opacity fade for the statistics panel
  late AnimationController _statsAnim;
  late Animation<double>   _statsOpacity;

  // ── Pulse animation for the "current location" blue dot ──────────────────
  // The outer accuracy ring pulses in and out to mimic Google Maps behaviour.
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Stats panel fade animation
    _statsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _statsOpacity = CurvedAnimation(
      parent: _statsAnim,
      curve: Curves.easeInOut,
    );

    // Pulse animation: scales the accuracy ring from 1.0x → 2.5x repeatedly.
    // Duration of 1800 ms gives a relaxed, Google Maps-like cadence.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(); // repeat forever while the screen is visible

    _pulseAnim = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Fetch device location in the background AFTER the first frame is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDeviceLocation();
    });
  }

  @override
  void dispose() {
    _statsAnim.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Device location ─────────────────────────────────────────────────────────
  // Runs entirely in the background. On success it:
  //   • updates _deviceLocation (triggers map marker rebuild via setState)
  //   • pans the already-visible map to the device coordinates
  // On any failure it does nothing — Harare stays.
  Future<void> _fetchDeviceLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      // LocationAccuracy.medium uses cell/wifi as well as GPS — faster fix.
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('GPS timeout'),
      );

      if (!mounted) return;

      // Save the coordinates and rebuild the widget tree so the location
      // marker appears on the map.
      setState(() {
        _deviceLocation = LatLng(position.latitude, position.longitude);
      });

      // Pan the map to show the device's position
      _mapController.move(_deviceLocation!, _initialZoom);
    } catch (_) {
      // Silently ignore all errors — the map already shows Harare.
    }
  }

  // ── Manual refresh ──────────────────────────────────────────────────────────
  // Sets _isRefreshing = true (shows the full-screen spinner), waits for the
  // provider to reload, then hides the spinner.
  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      // Re-fetch both location and crime data concurrently
      await Future.wait([
        context.read<CrimeProvider>().refresh(),
        _fetchDeviceLocation(),
      ]);
    } finally {
      // Always hide the spinner, even on error
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ── Toggle stats panel ──────────────────────────────────────────────────────
  void _toggleStats() {
    setState(() => _showStats = !_showStats);
    _showStats ? _statsAnim.forward() : _statsAnim.reverse();
  }

  // ── Marker builder for crime incidents ─────────────────────────────────────
  Marker _buildMarker(CrimeIncident incident, String icon) {
    return Marker(
      point: LatLng(incident.latitude, incident.longitude),
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _showIncidentDetail(incident, icon),
        child: _EmojiMarker(emoji: icon),
      ),
    );
  }

  // ── Current location marker ─────────────────────────────────────────────────
  // Builds a Google Maps-style "current position" marker:
  //   • Pulsing semi-transparent blue ring (accuracy / attention indicator)
  //   • Solid white-outlined blue dot in the centre
  //   • White shadow for contrast on any map tile colour
  Marker _buildLocationMarker(LatLng position) {
    return Marker(
      point: position,
      // Make the marker area large enough to fit the pulsing ring comfortably
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Pulsing accuracy ring ────────────────────────────────────
              // Scales outward and fades with the pulse animation.
              // The opacity decreases as the ring grows so it disappears
              // smoothly at the outer edge, just like Google Maps.
              Opacity(
                opacity: (1.0 - (_pulseAnim.value - 1.0) / 1.5).clamp(0.0, 0.35),
                child: Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      // Semi-transparent Google blue
                      color: const Color(0xFF4285F4).withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4285F4).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Static inner dot ─────────────────────────────────────────
              // White border + shadow ensures visibility on light AND dark tiles.
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4), // Google Maps blue
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Bottom sheet helpers ────────────────────────────────────────────────────
  void _showIncidentDetail(CrimeIncident incident, String icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncidentDetailSheet(incident: incident, typeIcon: icon),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map layer ─────────────────────────────────────────────────────
          Consumer<CrimeProvider>(
            builder: (context, provider, _) {
              return FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _harareCenter,
                  initialZoom:   _initialZoom,
                  minZoom: 9,
                  maxZoom: 18,
                ),
                children: [
                  // OpenStreetMap raster tiles
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.zimcrimewatch.app',
                  ),

                  // Crime incident markers (only when data is loaded)
                  if (!provider.isLoading)
                    MarkerLayer(
                      markers: provider.incidents
                          .map((i) => _buildMarker(
                                i,
                                provider.iconFor(i.crimeTypeName),
                              ))
                          .toList(),
                    ),

                  // ── Current location marker layer ────────────────────────
                  // Only rendered once we have valid GPS coordinates.
                  // Placed ABOVE the crime markers so it is always visible.
                  if (_deviceLocation != null)
                    MarkerLayer(
                      markers: [_buildLocationMarker(_deviceLocation!)],
                    ),
                ],
              );
            },
          ),

          // ── Full-screen centred loading spinner ───────────────────────────
          // Shown in two situations:
          //   1. Initial crime data load (provider.isLoading, background fetch)
          //   2. Manual refresh triggered by the user (_isRefreshing)
          //
          // The semi-transparent scrim dims the map slightly so the spinner
          // stands out clearly without fully obscuring the UI.
          Consumer<CrimeProvider>(
            builder: (_, provider, __) {
              // Show spinner for either the initial load OR a manual refresh
              final bool showSpinner = _isRefreshing ||
                  (provider.isLoading && provider.incidents.isEmpty);

              if (!showSpinner) return const SizedBox.shrink();

              return Container(
                // Full-screen semi-transparent overlay
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Themed circular progress indicator
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRefreshing ? 'Refreshing…' : 'Loading incidents…',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Error banner ──────────────────────────────────────────────────
          Consumer<CrimeProvider>(
            builder: (_, provider, __) {
              if (provider.errorMessage == null) return const SizedBox.shrink();
              return Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: _ErrorBanner(message: provider.errorMessage!),
              );
            },
          ),

          // ── App bar ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildAppBar(),
          ),

          // ── Active filter chips row ───────────────────────────────────────
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 4,
            left: 0, right: 0,
            child: _buildFilterChips(),
          ),

          // ── Map controls: zoom in / out / re-centre ───────────────────────
          Positioned(
            bottom: 24, right: 16,
            child: _buildMapControls(),
          ),

          // ── Stats panel (slides up from the bottom-left) ──────────────────
          Positioned(
            bottom: 24, left: 0, right: 72,
            child: FadeTransition(
              opacity: _statsOpacity,
              child: _showStats ? const StatsSummary() : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar widget ──────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Consumer<CrimeProvider>(
      builder: (_, provider, __) {
        return Container(
          color: AppTheme.primaryColor.withOpacity(0.93),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Row(
              children: [
                Text('🛡️', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text(
                  'ZimCrimeWatch',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _toggleStats,
                icon: Icon(
                  _showStats ? Icons.bar_chart : Icons.bar_chart_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Statistics',
              ),

              // Refresh button — calls _handleRefresh() which shows the
              // full-screen centred spinner until the data reload completes.
              IconButton(
                onPressed: _isRefreshing ? null : _handleRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),

              Stack(
                children: [
                  IconButton(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    tooltip: 'Filter',
                  ),
                  if (provider.hasActiveFilters)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  // ── Active filter chips ─────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Consumer<CrimeProvider>(
      builder: (_, provider, __) {
        if (!provider.hasActiveFilters) return const SizedBox.shrink();

        final chips = <Widget>[];

        for (final typeId in provider.selectedTypeIds) {
          final type = provider.crimeTypes.where((t) => t.id == typeId).toList();
          final label = type.isNotEmpty
              ? '${type.first.icon} ${type.first.name}'
              : 'Type $typeId';
          chips.add(_FilterChip(label: label));
        }

        if (provider.dateRange != null) {
          final start = provider.dateRange!.start;
          final end   = provider.dateRange!.end;
          chips.add(_FilterChip(
            label: '${start.day}/${start.month} – ${end.day}/${end.month}',
          ));
        }

        chips.add(
          GestureDetector(
            onTap: provider.clearFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✕ Clear',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: chips),
        );
      },
    );
  }

  // ── Map controls: zoom in / zoom out / re-centre on device location ─────────
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapButton(
          icon: Icons.add,
          tooltip: 'Zoom in',
          onTap: () {
            final current = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, current + 1);
          },
        ),
        const SizedBox(height: 8),
        _MapButton(
          icon: Icons.remove,
          tooltip: 'Zoom out',
          onTap: () {
            final current = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, current - 1);
          },
        ),
        const SizedBox(height: 8),

        // ── "My Location" button ───────────────────────────────────────────
        // If _deviceLocation is already known, pan there instantly.
        // Otherwise re-run the full permission + GPS fetch.
        _MapButton(
          icon: Icons.my_location,
          tooltip: 'My location',
          // Highlight the button in blue when location is active
          color: _deviceLocation != null
              ? const Color(0xFF4285F4)
              : null,
          onTap: () {
            if (_deviceLocation != null) {
              // We already have a fix — just pan to it
              _mapController.move(_deviceLocation!, _initialZoom);
            } else {
              // Re-request permission and GPS
              _fetchDeviceLocation();
            }
          },
        ),
      ],
    );
  }
}

// ── Private helper widgets ───────────────────────────────────────────────────

class _EmojiMarker extends StatelessWidget {
  final String emoji;
  const _EmojiMarker({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}

// ── Map control button ────────────────────────────────────────────────────────
// Generic circular FAB-style button used for zoom and location controls.
// Optional [color] tints the icon; defaults to AppTheme.primaryColor.
class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// When non-null the icon takes this colour (e.g. Google blue for active location)
  final Color? color;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            // Use supplied colour or fall back to app primary
            color: color ?? AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}