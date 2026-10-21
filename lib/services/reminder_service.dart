import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderService {
  final _db = FirebaseFirestore.instance;

  /// Creates a reminder and returns the Firestore document ID.
  /// Also persists a stable [alarmId] (int) so it can be used across sessions.
  Future<String> create(
      String uid,
      String title,
      String description,
      DateTime time,
      String repeat,
      ) async {
    // Reserve a document ref to know the ID before writing
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('reminders')
        .doc();

    // Stable integer derived from the doc ID — consistent across app sessions
    final alarmId = _stableHash(ref.id);

    await ref.set({
      'title': title,
      'description': description,
      'scheduledAt': time.toIso8601String(),
      'repeat': repeat,
      'delivered': false,
      'alarmId': alarmId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Simple djb2-style hash that is deterministic (unlike Dart's hashCode).
  static int _stableHash(String s) {
    int h = 5381;
    for (final c in s.codeUnits) {
      h = ((h << 5) + h + c) & 0x7FFFFFFF; // keep positive 31-bit int
    }
    return h == 0 ? 1 : h; // AlarmManager doesn't like id=0
  }

  /// Public convenience — same hash that create() stores in Firestore.
  /// Use this after create() returns the docId to get the matching alarmId.
  static int computeAlarmId(String docId) => _stableHash(docId);

  /// Reads the persisted alarmId for a document, falling back to stableHash.
  static int alarmIdFromData(Map<String, dynamic> data, String docId) {
    final stored = data['alarmId'];
    if (stored is int && stored > 0) return stored;
    return _stableHash(docId); // fallback for old reminders without the field
  }
}
