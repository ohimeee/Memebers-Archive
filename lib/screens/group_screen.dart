import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/group_service.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _groupService = GroupService();
  final _authService = AuthService();
  final _joinController = TextEditingController();
  final _createController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _joinController.dispose();
    _createController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    await _run(() => _groupService.joinGroup(_joinController.text));
  }

  Future<void> _createGroup() async {
    final name = _createController.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter a group name.');
      return;
    }
    await _run(() => _groupService.createGroup(name));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a group'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _loading ? null : _authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Enter your invite code to see your shared gallery.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _joinController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code or group ID',
              ),
              onSubmitted: (_) => _joinGroup(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _joinGroup,
              child: const Text('Join group'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Start a new group',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _createController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Group name'),
              onSubmitted: (_) => _createGroup(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loading ? null : _createGroup,
              child: const Text('Create group'),
            ),
          ],
        ),
      ),
    );
  }
}
