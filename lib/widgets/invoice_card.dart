import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../utils/helpers.dart';
import 'status_badge.dart';

/// Invoice Card Widget
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const InvoiceCard({super.key, required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5),
          ),
        ),
        child: Row(
          children: [
            _buildIcon(context, isDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFF9999AA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoice.customerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: isDark
                              ? const Color(0xFF6666AA)
                              : const Color(0xFFBBBBCC)),
                      const SizedBox(width: 4),
                      Text(
                        Helpers.formatDate(invoice.date),
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF6666AA)
                                : const Color(0xFFBBBBCC)),
                      ),
                    ],
                  ),
                  if (invoice.isOverdue) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${Helpers.formatOverdueDuration(invoice.dueDate)} terlambat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  status: invoice.status == InvoiceStatus.paid
                      ? InvoiceStatus.paid
                      : InvoiceStatus.unpaid,
                ),
                if (invoice.isOverdue) ...[
                  const SizedBox(height: 4),
                  const StatusBadge(
                    status: InvoiceStatus.overdue,
                    labelOverride: 'Late',
                    paddingH: 10,
                    paddingV: 4,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  Helpers.formatCurrency(invoice.total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, bool isDark) {
    Color iconBg;
    Color iconColor;

    switch (invoice.status) {
      case InvoiceStatus.paid:
        iconBg = isDark ? const Color(0xFF1A3A2A) : const Color(0xFFE8F5E9);
        iconColor = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
        break;
      case InvoiceStatus.unpaid:
        iconBg = isDark ? const Color(0xFF1A1A3A) : const Color(0xFFE8EAF6);
        iconColor = isDark ? const Color(0xFF7986CB) : const Color(0xFF3F51B5);
        break;
      case InvoiceStatus.overdue:
        iconBg = isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFFEBEE);
        iconColor = isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
        break;
    }

    return Container(
      width: 46,
      height: 46,
      decoration:
          BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.receipt_long_outlined, color: iconColor, size: 22),
    );
  }
}
