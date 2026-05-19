import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/photo_post.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.post,
    required this.dateLabel,
    required this.displayDate,
    required this.selectionMode,
    required this.selected,
    required this.canSelect,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final PhotoPost post;
  final String dateLabel;
  final DateTime displayDate;
  final bool selectionMode;
  final bool selected;
  final bool canSelect;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('MMM d, yyyy h:mm a').format(displayDate);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: post.id,
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const ColoredBox(
                          color: Color(0xFFE6E6E0),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    if (selectionMode)
                      Positioned.fill(
                        child: ColoredBox(
                          color: selected
                              ? Colors.black.withValues(alpha: 0.28)
                              : Colors.black.withValues(
                                  alpha: canSelect ? 0.05 : 0.42,
                                ),
                        ),
                      ),
                    if (selectionMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          selected
                              ? Icons.check_circle
                              : canSelect
                                  ? Icons.radio_button_unchecked
                                  : Icons.lock_outline,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                  ],
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
}
