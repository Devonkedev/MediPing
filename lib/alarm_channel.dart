import 'package:flutter/services.dart';

class AlarmChannel {
  static const MethodChannel _channel = MethodChannel('remedi/alarm');

  static Future<void> scheduleAlarm({
    required int id,
    required DateTime time,
    required String title,
    required String body,
    required String repeat, // none | daily | weekly
  }) async {
    await _channel.invokeMethod('schedule', {
      'id': id,
      'time': time.millisecondsSinceEpoch,
      'title': title,
      'body': body,
      'repeat': repeat,
    });
  }
  static Future<void> cancelAlarm(int id) async {
    await _channel.invokeMethod('cancel', {'id': id});
  }
}
