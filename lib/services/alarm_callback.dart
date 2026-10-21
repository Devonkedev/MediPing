import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> reminderAlarmCallback(int alarmId) async {
  // This entry-point is only triggered natively on Android.
  // On iOS, flutter_local_notifications handles background delivery directly.
  if (!kIsWeb && !Platform.isAndroid) return;

  final notifications = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

  await notifications.initialize(initSettings);

  await notifications.show(
    alarmId,
    'Remedi Reminder',
    'It\'s time for your scheduled reminder',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',          // ✅ matches NotificationService channel
        'Reminders',
        channelDescription: 'Medicine & health reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}
