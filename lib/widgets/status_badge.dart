import 'package:flutter/material.dart';
import '../models/invoice.dart';

/// Status Badge Widget
class StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  final String? labelOverride;
  final double? fontSize;
  final double? paddingH;
  final double? paddingV;

  const StatusBadge(
      {super.key,
      required this.status,
      this.labelOverride,
      this.fontSize,
      this.paddingH,
      this.paddingV});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _getColors(isDark);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: paddingH ?? 10, vertical: paddingV ?? 4),
      decoration: BoxDecoration(
          color: colors['bg'], borderRadius: BorderRadius.circular(20)),
      child: Text(
        labelOverride ?? status.label,
        style: TextStyle(
            color: colors['text'],
            fontSize: fontSize ?? 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
      ),
    );
  }

  Map<String, Color> _getColors(bool isDark) {
    switch (status) {
      case InvoiceStatus.paid:
        return {
          'bg': isDark ? const Color(0xFF1A3A2A) : const Color(0xFFE8F5E9),
          'text': isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
        };
      case InvoiceStatus.unpaid:
        return {
          'bg': isDark ? const Color(0xFF3A3A1A) : const Color(0xFFFFF8E1),
          'text': isDark ? const Color(0xFFFFCA28) : const Color(0xFFF57F17),
        };
      case InvoiceStatus.overdue:
        return {
          'bg': isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFFEBEE),
          'text': isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
        };
    }
  }
}
