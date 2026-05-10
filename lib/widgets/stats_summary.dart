// lib/widgets/stats_summary.dart
//
// Compact floating card showing a horizontal bar chart of incident counts
// per crime type. Uses only core Flutter painting — no chart library needed
// for this simple visualization.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/crime_provider.dart';
import '../theme/app_theme.dart';

class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CrimeProvider>(
      builder: (_, provider, __) {
        // Total incident count across all types (used to compute percentages)
        final total = provider.incidents.length;

        // Count incidents per crime type name
        // Map<typeName, count> built by iterating the incidents list once
        final Map<String, int> countByType = {};
        for (final inc in provider.incidents) {
          countByType[inc.crimeTypeName] =
              (countByType[inc.crimeTypeName] ?? 0) + 1;
        }

        // Sort descending by count so the highest bars appear at the top
        final sorted = countByType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Show at most 5 types to keep the card compact
        final topTypes = sorted.take(5).toList();

        return Container(
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.bar_chart,
                      size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  const Text(
                    'Incident Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Total count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$total total',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (topTypes.isEmpty)
                const Text(
                  'No incidents to display.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                )
              else
                // ── Bar chart rows ─────────────────────────────────────────
                ...topTypes.map((entry) {
                  // Find the emoji icon for this type from the provider
                  final icon = provider.iconFor(entry.key);

                  // Bar width as a fraction of the max count in the top-5 list
                  // so the highest bar always fills its container
                  final maxCount = topTypes.first.value;
                  final fraction = maxCount > 0
                      ? entry.value / maxCount
                      : 0.0;

                  return _BarRow(
                    emoji: icon,
                    label: entry.key,
                    count: entry.value,
                    fraction: fraction,
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

// ── Single bar row ────────────────────────────────────────────────────────────
class _BarRow extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;

  /// Proportion of the bar to fill, 0.0 – 1.0 (relative to the max bar)
  final double fraction;

  const _BarRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Emoji icon
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),

          // Label truncated to 12 chars to keep the card narrow
          SizedBox(
            width: 90,
            child: Text(
              label.length > 12 ? '${label.substring(0, 10)}…' : label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 6),

          // Animated bar — uses LayoutBuilder to fill available width
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Background track
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Filled portion — width is proportional to fraction
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      height: 8,
                      width: constraints.maxWidth * fraction,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 6),

          // Numeric count label on the right
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
