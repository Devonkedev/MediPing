import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  String name;
  DateTime dob;
  double heightCm;
  double weightKg;

  UserProfile({
    required this.uid,
    this.name = '',
    DateTime? dob,
    this.heightCm = 0,
    this.weightKg = 0,
  }) : dob = dob ?? DateTime(1990);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'dob': dob.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
      };

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      dob: DateTime.tryParse(data['dob'] ?? '') ?? DateTime(1990),
      heightCm: (data['heightCm'] ?? 0).toDouble(),
      weightKg: (data['weightKg'] ?? 0).toDouble(),
    );
  }
}
