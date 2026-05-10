// lib/models/crime_incident.dart
//
// Data transfer objects that mirror the Django REST serializers:
//   • CrimeIncident  ← PublicCrimeIncidentSerializer
//   • CrimeType      ← CrimeTypeSerializer

// ── CrimeType ──────────────────────────────────────────────────────────────
// Represents one row from /api/public/crime-types/
class CrimeType {
  final int id;
  final String name;
  final String description;

  // Unicode emoji sent by the backend, e.g. "🎒" for Theft
  final String icon;

  // Total incidents of this type in the DB (used for the stats bar chart)
  final int incidentCount;

  const CrimeType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.incidentCount,
  });

  /// Deserialize from the JSON shape returned by CrimeTypeSerializer.
  factory CrimeType.fromJson(Map<String, dynamic> json) {
    return CrimeType(
      id: json['id'] as int,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      icon: (json['icon'] as String?) ?? '📍',
      // incident_count may be null when the crime type has no incidents yet
      incidentCount: (json['incident_count'] as int?) ?? 0,
    );
  }
}

// ── CrimeIncident ──────────────────────────────────────────────────────────
// Represents one row from /api/public/crimes/
// Deliberately anonymized — no witness names, exact addresses, or IDs
// that could re-identify individuals.
class CrimeIncident {
  final int id;

  // Foreign key integer — used to look up the full CrimeType object
  final int crimeTypeId;

  // Denormalized name so we can display it without a second lookup
  final String crimeTypeName;

  // ISO-8601 timestamp from the backend; stored as Dart DateTime
  final DateTime timestamp;

  // WGS-84 coordinates from the PostGIS PointField
  final double latitude;
  final double longitude;

  // Human-readable area description, e.g. "Near Rezende St, CBD"
  final String suburb;

  // Bucketed time of day: "Morning" | "Afternoon" | "Evening" | "Night"
  final String timeOfDay;

  // Full day name: "Monday" .. "Sunday"
  final String dayOfWeek;

  const CrimeIncident({
    required this.id,
    required this.crimeTypeId,
    required this.crimeTypeName,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.suburb,
    required this.timeOfDay,
    required this.dayOfWeek,
  });

  /// Deserialize from the JSON shape returned by PublicCrimeIncidentSerializer.
  factory CrimeIncident.fromJson(Map<String, dynamic> json) {
    return CrimeIncident(
      id: json['id'] as int,
      crimeTypeId: json['crime_type'] as int,
      crimeTypeName: (json['crime_type_name'] as String?) ?? 'Unknown',
      // DateTime.parse handles the "Z" suffix (UTC) and any offset formats
      timestamp: DateTime.parse(json['timestamp'] as String),
      // latitude/longitude come as JSON numbers; cast to double safely
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      suburb: (json['suburb'] as String?) ?? 'Unknown area',
      timeOfDay: (json['time_of_day'] as String?) ?? 'Unknown',
      dayOfWeek: (json['day_of_week'] as String?) ?? 'Unknown',
    );
  }
}
