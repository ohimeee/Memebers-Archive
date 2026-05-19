import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/group.dart';
import '../models/group_member.dart';
import '../services/group_service.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: StreamBuilder<List<GroupMember>>(
        stream: groupService.watchMembers(group.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data ?? const <GroupMember>[];
          if (members.isEmpty) {
            return const Center(child: Text('No members yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              final joinedAt = member.joinedAt == null
                  ? 'Joined recently'
                  : 'Joined ${DateFormat('MMM d, yyyy').format(member.joinedAt!)}';

              return ListTile(
                leading: CircleAvatar(
                  child:
                      Text(member.displayName.characters.first.toUpperCase()),
                ),
                title: Text(member.displayName),
                subtitle: Text(joinedAt),
              );
            },
          );
        },
      ),
    );
  }
}
