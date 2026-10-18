import 'package:flutter/material.dart';

/// Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle = '',
      this.actionIcon,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon,
                  size: 44,
                  color: isDark
                      ? const Color(0xFF6666AA)
                      : const Color(0xFF9999BB)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                textAlign: TextAlign.center),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF6666AA)
                          : const Color(0xFF9999BB)),
                  textAlign: TextAlign.center),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
