import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/productivity/productivity_models.dart';

/// Offline-first local notification service for reminders, calendar events,
/// and task deadlines. Operates completely locally without requiring a server.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _hasPermission = false;

  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;

  /// Initializes the local notification plugin and timezone database.
  /// Handles platform differences gracefully and does not throw in headless/test environments.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('NotificationService: Timezone initialization note: $e');
    }

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService: Plugin init caught (likely testing or desktop environment): $e');
      _isInitialized = true;
    }
  }

  /// Requests notification permissions on Android (13+) and iOS/macOS.
  Future<bool> requestPermissions() async {
    try {
      if (!_isInitialized) await init();

      bool granted = false;
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final androidGranted = await androidImplementation.requestNotificationsPermission();
        granted = androidGranted ?? false;
      }

      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final iosGranted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        granted = granted || (iosGranted ?? false);
      }

      final macImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      if (macImplementation != null) {
        final macGranted = await macImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        granted = granted || (macGranted ?? false);
      }

      _hasPermission = granted;
      return granted;
    } catch (e) {
      debugPrint('NotificationService: requestPermissions failed: $e');
      return false;
    }
  }

  /// Converts a string id into a 31-bit positive integer for the notification plugin.
  int _toNotificationId(String id) {
    return id.hashCode.abs() % 2147483647;
  }

  NotificationDetails _notificationDetails({
    String channelId = 'planner_reminders',
    String channelName = 'Planner Reminders',
    String channelDescription = 'Notifications for tasks, events, and personal reminders',
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Sends an immediate test notification to verify audio and alert display.
  Future<void> showTestNotification({
    String title = 'Planner Notification Test',
    String body = 'Your local notifications are working properly offline!',
  }) async {
    try {
      if (!_isInitialized) await init();
      await _notificationsPlugin.show(
        id: 99999,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(),
        payload: 'test_notification',
      );
    } catch (e) {
      debugPrint('NotificationService: showTestNotification error: $e');
    }
  }

  /// Schedules a notification for a [ReminderItem].
  /// Handles one-time, daily, weekly, monthly, and yearly recurrences.
  Future<void> scheduleReminder(ReminderItem reminder) async {
    if (!reminder.isEnabled) return;
    try {
      if (!_isInitialized) await init();

      final id = _toNotificationId(reminder.id);
      final details = _notificationDetails();

      if (reminder.type == ReminderType.oneTime && reminder.scheduledAt.isBefore(DateTime.now())) {
        return;
      }

      tz.TZDateTime scheduledTz;
      try {
        final location = tz.local;
        scheduledTz = tz.TZDateTime.from(reminder.scheduledAt, location);
      } catch (_) {
        scheduledTz = tz.TZDateTime.from(reminder.scheduledAt, tz.UTC);
      }

      final now = tz.TZDateTime.now(scheduledTz.location);
      if (scheduledTz.isBefore(now)) {
        switch (reminder.type) {
          case ReminderType.recurringDaily:
            while (scheduledTz.isBefore(now)) {
              scheduledTz = scheduledTz.add(const Duration(days: 1));
            }
            break;
          case ReminderType.recurringWeekly:
            while (scheduledTz.isBefore(now)) {
              scheduledTz = scheduledTz.add(const Duration(days: 7));
            }
            break;
          case ReminderType.recurringMonthly:
            while (scheduledTz.isBefore(now)) {
              final nextMonth = scheduledTz.month == 12 ? 1 : scheduledTz.month + 1;
              final nextYear = scheduledTz.month == 12 ? scheduledTz.year + 1 : scheduledTz.year;
              scheduledTz = tz.TZDateTime(
                scheduledTz.location,
                nextYear,
                nextMonth,
                scheduledTz.day,
                scheduledTz.hour,
                scheduledTz.minute,
              );
            }
            break;
          case ReminderType.recurringYearly:
          case ReminderType.birthday:
            while (scheduledTz.isBefore(now)) {
              scheduledTz = tz.TZDateTime(
                scheduledTz.location,
                scheduledTz.year + 1,
                scheduledTz.month,
                scheduledTz.day,
                scheduledTz.hour,
                scheduledTz.minute,
              );
            }
            break;
          case ReminderType.oneTime:
          case ReminderType.event:
          case ReminderType.task:
            return;
        }
      }

      DateTimeComponents? matchComponents;
      switch (reminder.type) {
        case ReminderType.recurringDaily:
          matchComponents = DateTimeComponents.time;
          break;
        case ReminderType.recurringWeekly:
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case ReminderType.recurringMonthly:
          matchComponents = DateTimeComponents.dayOfMonthAndTime;
          break;
        case ReminderType.recurringYearly:
        case ReminderType.birthday:
          matchComponents = DateTimeComponents.dateAndTime;
          break;
        case ReminderType.oneTime:
        case ReminderType.event:
        case ReminderType.task:
          matchComponents = null;
          break;
      }

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
        payload: reminder.id,
      );
    } catch (e) {
      debugPrint('NotificationService: scheduleReminder error for ${reminder.id}: $e');
    }
  }

  /// Cancels a scheduled notification by reminder id.
  Future<void> cancelReminder(String reminderId) async {
    try {
      if (!_isInitialized) await init();
      final id = _toNotificationId(reminderId);
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('NotificationService: cancelReminder error: $e');
    }
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    try {
      if (!_isInitialized) await init();
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService: cancelAll error: $e');
    }
  }

  /// Reschedules all active reminders across app restart.
  Future<void> rescheduleAll(List<ReminderItem> reminders) async {
    try {
      if (!_isInitialized) await init();
      for (final r in reminders) {
        if (r.isEnabled) {
          await scheduleReminder(r);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: rescheduleAll error: $e');
    }
  }
}
