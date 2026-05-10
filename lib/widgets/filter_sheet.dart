// lib/widgets/filter_sheet.dart
//
// Bottom sheet that lets users filter the crime map by:
//   • Crime type (multi-select chips populated from the API)
//   • Date range (calendar date picker)
//
// Changes are staged in local state until "Apply" is tapped, so the user
// can explore options without triggering API calls on every tap.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/crime_incident.dart';
import '../services/crime_provider.dart';
import '../theme/app_theme.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  // Staged filter values — copied from the provider on init,
  // only committed back when the user taps "Apply"
  late Set<int>       _tempTypeIds;
  DateTimeRange?      _tempDateRange;

  @override
  void initState() {
    super.initState();
    // Snapshot the current provider state so "Cancel" restores it
    final p      = context.read<CrimeProvider>();
    _tempTypeIds = Set.from(p.selectedTypeIds);
    _tempDateRange = p.dateRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final fmt      = DateFormat('dd MMM yyyy');
    final provider = context.watch<CrimeProvider>();

    // Live list of crime types fetched from /api/public/crime-types/
    final types = provider.crimeTypes;

    return Container(
      // Push the sheet above the keyboard when it's open
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text(
                  'Filter Incidents',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    // Reset both staged filters to empty
                    _tempTypeIds.clear();
                    _tempDateRange = null;
                  }),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // ── Crime type section ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Crime Type',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (types.isEmpty)
            // Show while the provider is still loading crime types
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Loading categories…',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            // Wrap wraps chips to the next line when the row is full
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types
                    .map((t) => _TypeChip(
                          type: t,
                          isSelected: _tempTypeIds.contains(t.id),
                          onToggle: (selected) {
                            setState(() {
                              // Toggle the type ID in/out of the staged set
                              if (selected) {
                                _tempTypeIds.add(t.id);
                              } else {
                                _tempTypeIds.remove(t.id);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Date range section ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Date Range',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                // Tapping this opens the Material date range picker
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          _tempDateRange == null
                              ? 'All dates'
                              : '${fmt.format(_tempDateRange!.start)} – '
                                '${fmt.format(_tempDateRange!.end)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Apply / Cancel buttons ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Row(
              children: [
                // Cancel — discard staged changes
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                // Apply — commit staged filters to the provider and close
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<CrimeProvider>().applyFilters(
                            typeIds: _tempTypeIds,
                            dateRange: _tempDateRange,
                          );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Apply${_hasChanges ? '' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date range picker ───────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _tempDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        // Tint the date picker with the brand colour
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => _tempDateRange = result);
    }
  }

  /// True if the staged filters differ from what the provider currently holds.
  bool get _hasChanges {
    final p = context.read<CrimeProvider>();
    return _tempTypeIds != p.selectedTypeIds || _tempDateRange != p.dateRange;
  }
}

// ── Crime type chip ──────────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final CrimeType type;
  final bool isSelected;
  final ValueChanged<bool> onToggle;

  const _TypeChip({
    required this.type,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Selected state uses the solid primary colour; unselected is tinted
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              type.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            // Incident count badge
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${type.incidentCount}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
