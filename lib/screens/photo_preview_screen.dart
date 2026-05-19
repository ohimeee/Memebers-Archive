import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/photo_post.dart';
import '../services/photo_service.dart';

class PhotoPreviewScreen extends StatefulWidget {
  const PhotoPreviewScreen({required this.post, super.key});

  final PhotoPost post;

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  final _photoService = PhotoService();
  bool _downloading = false;
  bool _deleting = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await _photoService.downloadToGallery(widget.post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to gallery.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This removes the photo from the shared feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _deleting = true);
    try {
      final result = await _photoService.deletePhoto(widget.post);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.cloudinaryDeleted
                ? 'Photo deleted.'
                : 'Photo removed from the feed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showDetails() {
    final post = widget.post;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                'Photo details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Uploaded by', value: post.uploaderName),
              _DetailRow(
                  label: 'Uploaded', value: _formatDate(post.uploadedAt)),
              _DetailRow(
                label: 'Taken on',
                value: post.takenOn == null
                    ? 'Not available'
                    : _formatDate(post.takenOn!),
              ),
              _DetailRow(
                label: 'Filename',
                value: post.originalFileName ?? 'Not available',
              ),
              _DetailRow(
                  label: 'Size', value: _formatBytes(post.fileSizeBytes)),
              _DetailRow(
                label: 'Resolution',
                value: post.width == null || post.height == null
                    ? 'Not available'
                    : '${post.width} x ${post.height} px',
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'Not available';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(2)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          if (_photoService.canCurrentUserDelete(widget.post))
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Photo details',
            onPressed: _showDetails,
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Download',
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: widget.post.id,
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: widget.post.imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
