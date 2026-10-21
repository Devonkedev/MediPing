import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../alarm_channel.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final String uid;
  late final ReminderService service;

  // True on Android (native AlarmManager), false everywhere else (flutter_local_notifications)
  static bool get _useNativeAlarm => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    service = ReminderService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowBatteryGuide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _addReminder,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('reminders')
            .orderBy('scheduledAt')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No reminders yet',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'Reminder';
              final description = data['description'] ?? '';
              final repeat = data['repeat'] ?? 'none';
              final scheduledAt = data['scheduledAt'];
              // Use the persisted alarmId — stable across app sessions
              final alarmId = ReminderService.alarmIdFromData(data, doc.id);

              final time = DateTime.tryParse(scheduledAt ?? '');
              if (time == null) return const SizedBox.shrink();

              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) Text(description),
                      const SizedBox(height: 4),
                      Text(
                        '${time.toLocal()} • ${repeat.toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editReminder(
                            doc, alarmId, title, description, time, repeat);
                      } else if (value == 'delete') {
                        _deleteReminder(doc, alarmId);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ======================================================
  // ADD REMINDER
  // ======================================================

  void _addReminder() {
    _showReminderDialog(
      onSave: (title, desc, time, repeat) async {
        // create() stores the stable alarmId in Firestore and returns the docId
        final docId = await service.create(uid, title, desc, time, repeat);

        // ✅ Use the SAME deterministic hash that was stored in Firestore
        final alarmId = ReminderService.computeAlarmId(docId);

        if (_useNativeAlarm) {
          // Android — native AlarmManager (plays sound, works when app is killed)
          await AlarmChannel.scheduleAlarm(
            id: alarmId,
            time: time,
            title: title,
            body: desc,
            repeat: repeat,
          );
        } else {
          // iOS / other — flutter_local_notifications with full repeat support
          await NotificationService().schedule(
            id: alarmId,
            title: title,
            body: desc,
            time: time,
            repeat: repeat,
          );
        }
      },
    );
  }

  // ======================================================
  // EDIT REMINDER
  // ======================================================

  void _editReminder(
    QueryDocumentSnapshot doc,
    int alarmId,
    String title,
    String desc,
    DateTime time,
    String repeat,
  ) {
    _showReminderDialog(
      title: title,
      description: desc,
      time: time,
      repeat: repeat,
      onSave: (newTitle, newDesc, newTime, newRepeat) async {
        if (_useNativeAlarm) {
          // Android — cancel old native alarm, schedule new one
          await AlarmChannel.cancelAlarm(alarmId);
          await AlarmChannel.scheduleAlarm(
            id: alarmId,
            time: newTime,
            title: newTitle,
            body: newDesc,
            repeat: newRepeat,
          );
        } else {
          // iOS — cancel old notification, schedule new one
          await NotificationService().cancel(alarmId);
          await NotificationService().schedule(
            id: alarmId,
            title: newTitle,
            body: newDesc,
            time: newTime,
            repeat: newRepeat,
          );
        }

        await doc.reference.update({
          'title': newTitle,
          'description': newDesc,
          'scheduledAt': newTime.toIso8601String(),
          'repeat': newRepeat,
        });
      },
    );
  }

  // ======================================================
  // DELETE REMINDER
  // ======================================================

  Future<void> _deleteReminder(
      QueryDocumentSnapshot doc, int alarmId) async {
    if (_useNativeAlarm) {
      await AlarmChannel.cancelAlarm(alarmId);
    } else {
      await NotificationService().cancel(alarmId);
    }
    await doc.reference.delete();
  }

  // ======================================================
  // REMINDER DIALOG
  // ======================================================

  void _showReminderDialog({
    String title = '',
    String description = '',
    DateTime? time,
    String repeat = 'none',
    required Function(
      String title,
      String description,
      DateTime time,
      String repeat,
    ) onSave,
  }) {
    final titleCtrl = TextEditingController(text: title);
    final descCtrl = TextEditingController(text: description);
    DateTime selectedTime =
        time ?? DateTime.now().add(const Duration(minutes: 1));
    String repeatValue = repeat;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Take tablet',
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: repeatValue,
                items: const [
                  DropdownMenuItem(
                      value: 'none', child: Text('No repeat')),
                  DropdownMenuItem(
                      value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(
                      value: 'weekly', child: Text('Weekly')),
                ],
                onChanged: (v) => repeatValue = v ?? 'none',
                decoration:
                    const InputDecoration(labelText: 'Repeat'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                child: Text(
                  '${selectedTime.toLocal().toString().split(' ')[0]}  '
                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: selectedTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;

                  final t = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay.fromDateTime(selectedTime),
                  );
                  if (t == null) return;

                  setDialogState(() {
                    selectedTime = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      t.hour,
                      t.minute,
                    );
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final titleText = titleCtrl.text.trim();
                if (titleText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reminder title'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                onSave(
                  titleText,
                  descCtrl.text.trim(),
                  selectedTime,
                  repeatValue,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // BATTERY OPTIMIZATION GUIDE  (Android only)
  // ======================================================

  Future<void> _maybeShowBatteryGuide() async {
    if (!_useNativeAlarm) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('battery_guide_shown') ?? false) return;

    final info = await DeviceInfoPlugin().androidInfo;
    final m = info.manufacturer.toLowerCase();

    if (!(m.contains('samsung') ||
        m.contains('xiaomi') ||
        m.contains('oppo') ||
        m.contains('vivo'))) {
      return;
    }

    await prefs.setBool('battery_guide_shown', true);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Allow background alarms'),
        content: const Text(
          'To ensure alarms work reliably, please allow background activity.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
