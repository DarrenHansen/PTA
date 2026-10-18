import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

/// Filter Chip Widget untuk status invoice
class StatusFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const StatusFilterChips(
      {super.key, required this.selectedFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final filters = [
      {'label': loc.get('all'), 'value': 'all', 'icon': Icons.list},
      {'label': loc.get('unpaid'), 'value': 'unpaid', 'icon': Icons.schedule},
      {'label': loc.get('paid'), 'value': 'paid', 'icon': Icons.check_circle},
      {'label': loc.get('overdue'), 'value': 'overdue', 'icon': Icons.warning},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter['value'];

          return _buildChip(
            context,
            label: filter['label'] as String,
            icon: filter['icon'] as IconData,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onFilterChanged(filter['value'] as String),
          );
        },
      ),
    );
  }

  Widget _buildChip(BuildContext context,
      {required String label,
      required IconData icon,
      required bool isSelected,
      required bool isDark,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E))
                : (isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E))
                  : (isDark
                      ? const Color(0xFF2A2A4A)
                      : const Color(0xFFEEEEF5)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFF9999AA))),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFF9999AA)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
