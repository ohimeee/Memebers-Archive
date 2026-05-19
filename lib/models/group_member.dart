import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final DateTime? joinedAt;

  factory GroupMember.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final joinedAt = data['joinedAt'] as Timestamp?;

    return GroupMember(
      userId: data['userId'] as String? ?? snapshot.id,
      displayName: data['displayName'] as String? ?? 'Friend',
      joinedAt: joinedAt?.toDate(),
    );
  }
}
