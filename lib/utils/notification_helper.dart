import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification Helper
/// Mengelola local notifications untuk reminder invoice
class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize notification system
  static Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined settings
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint(
          'Notification clicked: ${response.payload}',
        );
      },
    );
  }

  /// Request notification permissions
  static Future<void> requestPermissions() async {
    // Android
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Common notification details
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'invoice_reminders',
    'Invoice Reminders',
    channelDescription: 'Notifications for invoice due date reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails();

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
  );

  /// Show instant notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id,
        title,
        body,
        _notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Show Notification Error: $e');
    }
  }

  /// Schedule notification safely
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      // Prevent scheduling in the past
      if (scheduledDate.isBefore(DateTime.now())) {
        return;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Schedule Notification Error: $e');
    }
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Cancel Notification Error: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Cancel All Notifications Error: $e');
    }
  }

  /// Schedule invoice reminders
  ///
  /// Optimized version:
  /// - Only H-1 reminder
  /// - Overdue reminder
  /// - More lightweight & smooth
  static Future<void> scheduleInvoiceReminders({
    required int invoiceId,
    required String invoiceNumber,
    required String customerName,
    required DateTime dueDate,
  }) async {
    try {
      // Validation
      if (invoiceId <= 0) return;

      final int reminderId = invoiceId * 10;
      final int overdueId = invoiceId * 10 + 1;

      // Clear previous reminders
      await cancelNotification(reminderId);
      await cancelNotification(overdueId);

      final now = DateTime.now();

      /// H-1 Reminder
      final h1 = dueDate.subtract(const Duration(days: 1));

      if (h1.isAfter(now)) {
        await scheduleNotification(
          id: reminderId,
          title: 'Pengingat Invoice',
          body: 'Invoice $invoiceNumber untuk $customerName jatuh tempo BESOK.',
          scheduledDate: h1,
          payload: 'invoice_$invoiceId',
        );
      }

      /// Overdue Reminder
      final overdue = dueDate.add(const Duration(days: 1));

      if (overdue.isAfter(now)) {
        await scheduleNotification(
          id: overdueId,
          title: 'Invoice Terlambat',
          body:
              'Invoice $invoiceNumber untuk $customerName sudah melewati jatuh tempo.',
          scheduledDate: overdue,
          payload: 'invoice_$invoiceId',
        );
      }
    } catch (e) {
      debugPrint('Invoice Reminder Error: $e');
    }
  }
}
