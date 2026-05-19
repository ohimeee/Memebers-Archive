import 'package:flutter/material.dart';

import '../models/group.dart';
import '../models/photo_post.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import 'members_screen.dart';
import '../widgets/photo_tile.dart';

enum PhotoSortField { uploadedAt, takenOn }

enum PhotoSortDirection { descending, ascending }

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
  PhotoSortField _sortField = PhotoSortField.uploadedAt;
  PhotoSortDirection _sortDirection = PhotoSortDirection.descending;

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

  List<PhotoPost> _sortPosts(List<PhotoPost> posts) {
    final sorted = List<PhotoPost>.from(posts);
    sorted.sort((a, b) {
      final aDate = _sortDate(a);
      final bDate = _sortDate(b);
      final comparison = aDate.compareTo(bDate);
      if (comparison == 0) {
        return a.uploadedAt.compareTo(b.uploadedAt);
      }
      return comparison;
    });

    if (_sortDirection == PhotoSortDirection.descending) {
      return sorted.reversed.toList(growable: false);
    }
    return sorted;
  }

  DateTime _sortDate(PhotoPost post) {
    return _sortField == PhotoSortField.uploadedAt
        ? post.uploadedAt
        : post.takenOn ?? post.uploadedAt;
  }

  String get _dateLabel {
    return _sortField == PhotoSortField.uploadedAt ? 'Uploaded' : 'Taken';
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

          final sortedPosts = _sortPosts(posts);
          return RefreshIndicator(
            onRefresh: () async {},
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _SortControls(
                    sortField: _sortField,
                    sortDirection: _sortDirection,
                    onSortFieldChanged: (field) {
                      setState(() => _sortField = field);
                    },
                    onSortDirectionChanged: (direction) {
                      setState(() => _sortDirection = direction);
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: sortedPosts.length,
                    itemBuilder: (context, index) => PhotoTile(
                      post: sortedPosts[index],
                      dateLabel: _dateLabel,
                      displayDate: _sortDate(sortedPosts[index]),
                    ),
                  ),
                ),
              ],
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

class _SortControls extends StatelessWidget {
  const _SortControls({
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
  });

  final PhotoSortField sortField;
  final PhotoSortDirection sortDirection;
  final ValueChanged<PhotoSortField> onSortFieldChanged;
  final ValueChanged<PhotoSortDirection> onSortDirectionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SegmentedButton<PhotoSortField>(
            segments: const [
              ButtonSegment(
                value: PhotoSortField.uploadedAt,
                label: Text('Upload date'),
                icon: Icon(Icons.cloud_upload_outlined),
              ),
              ButtonSegment(
                value: PhotoSortField.takenOn,
                label: Text('Taken on'),
                icon: Icon(Icons.photo_camera_back_outlined),
              ),
            ],
            selected: {sortField},
            onSelectionChanged: (selection) {
              onSortFieldChanged(selection.first);
            },
          ),
          SegmentedButton<PhotoSortDirection>(
            segments: const [
              ButtonSegment(
                value: PhotoSortDirection.descending,
                label: Text('Desc'),
                icon: Icon(Icons.south),
              ),
              ButtonSegment(
                value: PhotoSortDirection.ascending,
                label: Text('Asc'),
                icon: Icon(Icons.north),
              ),
            ],
            selected: {sortDirection},
            onSelectionChanged: (selection) {
              onSortDirectionChanged(selection.first);
            },
          ),
        ],
      ),
    );
  }
}
