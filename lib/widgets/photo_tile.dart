import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/photo_post.dart';
import '../screens/photo_preview_screen.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.post,
    required this.dateLabel,
    required this.displayDate,
    super.key,
  });

  final PhotoPost post;
  final String dateLabel;
  final DateTime displayDate;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('MMM d, yyyy h:mm a').format(displayDate);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          onTap: () => _openPreview(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Hero(
                  tag: post.id,
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ColoredBox(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: Color(0xFFE6E6E0),
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.uploaderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel: $timestamp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoPreviewScreen(post: post),
      ),
    );
  }
}
