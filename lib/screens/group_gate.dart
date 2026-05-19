import 'package:flutter/material.dart';

import '../services/group_service.dart';
import 'group_screen.dart';
import 'home_screen.dart';

class GroupGate extends StatelessWidget {
  const GroupGate({super.key});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return StreamBuilder(
      stream: groupService.currentGroup(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final group = snapshot.data;
        if (group == null) {
          return const GroupScreen();
        }

        return HomeScreen(group: group);
      },
    );
  }
}
