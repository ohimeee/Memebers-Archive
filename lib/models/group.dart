import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  final String id;
  final String name;
  final String inviteCode;

  factory Group.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return Group(
      id: snapshot.id,
      name: data['name'] as String? ?? 'Shared Gallery',
      inviteCode: data['inviteCode'] as String? ?? snapshot.id,
    );
  }
}
