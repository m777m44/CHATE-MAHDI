import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

/// Full-screen image viewer with pinch-zoom (InteractiveViewer).
class ImageViewerScreen extends ConsumerWidget {
  const ImageViewerScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.read(baseUrlProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(post.author?.username ?? ''),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.5,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: mediaUrl(post.mediaUrl, base),
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 60),
          ),
        ),
      ),
    );
  }
}
