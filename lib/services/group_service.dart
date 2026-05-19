import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/group.dart';
import '../models/group_member.dart';

class GroupService {
  GroupService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in.');
    }
    return user;
  }

  Stream<Group?> currentGroup() {
    final userId = _user.uid;

    return _firestore.collection('users').doc(userId).snapshots().asyncMap(
      (snapshot) async {
        final groupId = snapshot.data()?['currentGroupId'] as String?;
        if (groupId == null || groupId.isEmpty) return null;

        final groupSnapshot =
            await _firestore.collection('groups').doc(groupId).get();
        if (!groupSnapshot.exists) return null;
        return Group.fromSnapshot(groupSnapshot);
      },
    );
  }

  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(GroupMember.fromSnapshot)
              .toList(growable: false),
        );
  }

  Future<Group> createGroup(String name) async {
    final groupId = _uuid.v4();
    final inviteCode = _generateInviteCode();
    final user = _user;

    final groupRef = _firestore.collection('groups').doc(groupId);
    final memberRef = groupRef.collection('members').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      transaction.set(groupRef, {
        'name': name.trim(),
        'inviteCode': inviteCode,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(memberRef, {
        'userId': user.uid,
        'displayName':
            user.displayName ?? user.email?.split('@').first ?? 'Friend',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
          userRef,
          {
            'currentGroupId': groupId,
            'displayName':
                user.displayName ?? user.email?.split('@').first ?? 'Friend',
            'email': user.email,
            'photoUrl': user.photoURL,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    return Group(
      id: groupId,
      name: name.trim(),
      inviteCode: inviteCode,
      createdBy: user.uid,
    );
  }

  Future<Group> joinGroup(String inviteCodeOrGroupId) async {
    final input = inviteCodeOrGroupId.trim();
    if (input.isEmpty) {
      throw ArgumentError('Enter an invite code or group ID.');
    }

    final byCode = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: input.toUpperCase())
        .limit(1)
        .get();

    final groupDoc = byCode.docs.isNotEmpty
        ? byCode.docs.first
        : await _firestore.collection('groups').doc(input).get();

    if (!groupDoc.exists) {
      throw StateError('No group found for that code.');
    }

    final user = _user;
    final groupRef = _firestore.collection('groups').doc(groupDoc.id);
    final memberRef = groupRef.collection('members').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      transaction.set(
          memberRef,
          {
            'userId': user.uid,
            'displayName':
                user.displayName ?? user.email?.split('@').first ?? 'Friend',
            'joinedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      transaction.set(
          userRef,
          {
            'currentGroupId': groupDoc.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    return Group.fromSnapshot(groupDoc);
  }

  Future<LeaveGroupResult> leaveGroup(Group group) async {
    final user = _user;
    final groupRef = _firestore.collection('groups').doc(group.id);
    final memberRef = groupRef.collection('members').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);
    final membersSnapshot = await groupRef.collection('members').limit(2).get();
    final shouldDeleteGroup =
        membersSnapshot.docs.length <= 1 && group.createdBy == user.uid;

    await _firestore.runTransaction((transaction) async {
      transaction.delete(memberRef);
      transaction.set(
        userRef,
        {
          'currentGroupId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (shouldDeleteGroup) {
        transaction.delete(groupRef);
      }
    });

    return LeaveGroupResult(deletedGroup: shouldDeleteGroup);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

class LeaveGroupResult {
  const LeaveGroupResult({required this.deletedGroup});

  final bool deletedGroup;
}
