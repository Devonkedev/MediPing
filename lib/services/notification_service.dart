import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ─────────────────────────────────────────────
  // INIT  (call once from main.dart)
  // ─────────────────────────────────────────────
  Future<void> init() async {
    tz.initializeTimeZones();

    // Android init
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init — requests permission at launch
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onAction,
    );

    // Android: runtime notification permission + channel
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminders',
        'Reminders',
        description: 'Health & medication reminders',
        importance: Importance.max,
      ),
    );
  }

  void _onAction(NotificationResponse response) {
    // Future: handle snooze actions here
  }

  // ─────────────────────────────────────────────
  // SCHEDULE  (Android uses native AlarmChannel;
  //            iOS uses this directly)
  // ─────────────────────────────────────────────
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime time,
    String repeat = 'none', // 'none' | 'daily' | 'weekly'
  }) async {
    // Ensure the alarm is at least 5 s in the future
    final safeTime = time.isBefore(
      DateTime.now().add(const Duration(seconds: 5)),
    )
        ? DateTime.now().add(const Duration(seconds: 5))
        : time;

    // Map repeat string → DateTimeComponents for iOS repeating
    DateTimeComponents? matchComponents;
    if (repeat == 'daily') matchComponents = DateTimeComponents.time;
    if (repeat == 'weekly') {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(safeTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('SNOOZE_10', 'Snooze 10 min'),
            AndroidNotificationAction('SNOOZE_30', 'Snooze 30 min'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
    );
  }

  // ─────────────────────────────────────────────
  // CANCEL a scheduled notification by id
  // ─────────────────────────────────────────────
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  // ─────────────────────────────────────────────
  // SHOW NOW  (immediate notification, any platform)
  // ─────────────────────────────────────────────
  Future<void> showNow(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
