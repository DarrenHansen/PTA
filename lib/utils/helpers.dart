import 'package:intl/intl.dart';

/// Helper class untuk formatting
class Helpers {
  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');
  static final DateFormat _dateFormatterFull = DateFormat('dd MMMM yyyy');
  static final DateFormat _dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _dbDateFormatter = DateFormat('yyyy-MM-dd');

  /// Format mata uang Rupiah
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Format tanggal singkat
  static String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _dateFormatter.format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Format tanggal lengkap
  static String formatDateFull(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _dateFormatterFull.format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Format tanggal dan waktu
  static String formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _dateTimeFormatter.format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Format tanggal untuk disimpan ke database
  static String dateToDb(DateTime date) {
    return _dbDateFormatter.format(date);
  }

  /// Hitung hari tersisa sebelum jatuh tempo
  static int daysUntilDue(String dueDate) {
    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      return dueDay.difference(today).inDays;
    } catch (_) {
      return 0;
    }
  }

  /// Format lama keterlambatan sebagai selisih kalender tahun, bulan, dan hari.
  static String formatOverdueDuration(String dueDate, {DateTime? asOf}) {
    final parsedDueDate = DateTime.tryParse(dueDate);
    if (parsedDueDate == null) return '';

    final due = DateTime(
      parsedDueDate.year,
      parsedDueDate.month,
      parsedDueDate.day,
    );
    final now = asOf ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isAfter(due)) return '0 tahun, 0 bulan, 0 hari';

    var months = (today.year - due.year) * 12 + today.month - due.month;
    var monthAnchor = _addCalendarMonths(due, months);
    if (monthAnchor.isAfter(today)) {
      months--;
      monthAnchor = _addCalendarMonths(due, months);
    }

    final years = months ~/ 12;
    final remainingMonths = months % 12;
    final days = today.difference(monthAnchor).inDays;
    return '$years tahun, $remainingMonths bulan, $days hari';
  }

  static DateTime _addCalendarMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      date.day.clamp(1, lastDayOfMonth).toInt(),
    );
  }

  /// Mendapatkan greeting berdasarkan waktu
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 17) {
      return 'Selamat Siang';
    } else {
      return 'Selamat Malam';
    }
  }

  /// Truncate string dengan ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
