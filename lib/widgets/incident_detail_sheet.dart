// lib/widgets/incident_detail_sheet.dart
//
// Shown when a user taps a crime map marker.
// Displays anonymized incident metadata: suburb, time of day, day of week,
// and the crime type — no exact address, no personal data.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/crime_incident.dart';
import '../theme/app_theme.dart';

class IncidentDetailSheet extends StatelessWidget {
  final CrimeIncident incident;
  final String typeIcon;

  const IncidentDetailSheet({
    super.key,
    required this.incident,
    required this.typeIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Format the ISO-8601 timestamp into a human-readable string
    final dateStr = DateFormat('EEE dd MMM yyyy • HH:mm')
        .format(incident.timestamp.toLocal());

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // DraggableScrollableSheet would be overkill for this fixed-height sheet
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 0,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ───────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Crime type header ─────────────────────────────────────────
          Row(
            children: [
              // Large emoji icon in a green circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(typeIcon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.crimeTypeName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Detail rows ───────────────────────────────────────────────
          // Each row uses a leading icon, a label, and the value
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Area',
            value: incident.suburb,
          ),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Time of day',
            value: incident.timeOfDay,
          ),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Day of week',
            value: incident.dayOfWeek,
          ),

          const SizedBox(height: 20),

          // ── Anonymization notice ──────────────────────────────────────
          // Makes it clear to users that location data is approximate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Exact location is anonymized to protect privacy.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private detail row ────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
