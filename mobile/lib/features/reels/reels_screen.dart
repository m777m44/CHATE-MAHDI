import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../feed/feed_providers.dart';
import '../posts/comment_sheet.dart';

class _ReelItem extends ConsumerStatefulWidget {
  const _ReelItem({required this.post});

  final Post post;

  @override
  ConsumerState<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends ConsumerState<_ReelItem> {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.viewerLiked;
    _likeCount = widget.post.likeCount;
    _init();
  }

  Future<void> _init() async {
    final base = ref.read(baseUrlProvider);
    final c = VideoPlayerController.networkUrl(Uri.parse(mediaUrl(widget.post.mediaUrl, base)));
    try {
      await c.initialize();
      c.setLooping(true);
      if (mounted) {
        c.play();
        setState(() => _ready = true);
      }
    } catch (_) {}
    _video = c;
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.post.id}/like');
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.post.id}/save');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    final post = widget.post;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready && _video != null && _video!.value.isInitialized)
          GestureDetector(
            onTap: () {
              setState(() => _video!.value.isPlaying ? _video!.pause() : _video!.play());
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: _video!.value.aspectRatio,
                child: VideoPlayer(_video!),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        PositionedDirectional(
          end: 8,
          bottom: 120,
          child: Column(
            children: [
              IconButton(
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? Colors.red : Colors.white,
                  size: 30,
                ),
                onPressed: _like,
              ),
              Text(formatCount(_likeCount), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                onPressed: () => showCommentSheet(context, ref, post.id),
              ),
              Text(formatCount(post.commentCount), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(Icons.bookmark_border, color: Colors.white, size: 28),
                onPressed: _save,
              ),
            ],
          ),
        ),

        PositionedDirectional(
          start: 12,
          end: 72,
          bottom: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${post.author?.username ?? ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(post.caption, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vertical reels feed with autoplay on visibility.
class ReelsScreen extends ConsumerWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(reelsFeedProvider);
    final base = ref.watch(baseUrlProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('الريلز')),
      body: feed.maybeWhen(
        data: (data) => PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: data.posts.length + (data.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= data.posts.length) {
              ref.read(reelsFeedProvider.notifier).loadMore();
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (data.posts[i].isVideo) {
              return _ReelItem(post: data.posts[i]);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: mediaUrl(data.posts[i].mediaUrl, base),
                  fit: BoxFit.contain,
                ),
                Center(
                  child: Text(
                    data.posts[i].caption,
                    style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            );
          },
        ),
        orElse: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
