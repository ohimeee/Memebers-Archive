import 'package:flutter/material.dart';

import '../models/group.dart';
import '../models/photo_post.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import 'members_screen.dart';
import '../widgets/photo_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.group, super.key});

  final Group group;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _photoService = PhotoService();

  bool _uploading = false;

  Future<void> _uploadPhoto() async {
    setState(() => _uploading = true);
    try {
      await _photoService.pickCompressAndUpload(widget.group.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name),
            Text(
              'Invite code: ${widget.group.inviteCode}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Members',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MembersScreen(group: widget.group),
                ),
              );
            },
            icon: const Icon(Icons.group_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<PhotoPost>>(
        stream: _photoService.watchGroupPosts(widget.group.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? const <PhotoPost>[];
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No photos yet. Upload the first memory from your gallery.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {},
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.76,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) => PhotoTile(post: posts[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _uploadPhoto,
        icon: _uploading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.photo_library_outlined),
        label: Text(_uploading ? 'Uploading' : 'Upload'),
      ),
    );
  }
}
