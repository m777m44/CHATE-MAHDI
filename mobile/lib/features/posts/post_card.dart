import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../dm/share_sheet.dart';
import '../feed/feed_providers.dart';
import 'comment_sheet.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.onOpenMedia});

  final Post post;
  final VoidCallback? onOpenMedia;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _saved = false;
  int _likeCount = 0;
  VideoPlayerController? _video;
  late final AnimationController _heart;

  @override
  void initState() {
    super.initState();
    _heart = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0,
      upperBound: 1,
    );
    _liked = widget.post.viewerLiked;
    _saved = widget.post.viewerSaved;
    _likeCount = widget.post.likeCount;
    if (widget.post.isVideo) {
      _initVideo();
    }
  }

  void _burstHeart() {
    _heart.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _liked = widget.post.viewerLiked;
    _saved = widget.post.viewerSaved;
    _likeCount = widget.post.likeCount;
    if (widget.post.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final base = ref.read(baseUrlProvider);
    final controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl(widget.post.mediaUrl, base)));
    try {
      await controller.initialize();
      controller.setLooping(true);
      if (mounted) {
        controller.play();
        setState(() {});
      }
    } catch (_) {}
    _video = controller;
  }

  @override
  void dispose() {
    _video?.dispose();
    _heart.dispose();
    super.dispose();
  }

  Future<void> _toggleLike({bool forceLike = false}) async {
    final newLiked = forceLike ? true : !_liked;
    if (!newLiked) {
      setState(() {
        _liked = false;
        _likeCount -= 1;
      });
    } else {
      if (forceLike) _burstHeart();
      if (newLiked != _liked) {
        setState(() {
          _liked = true;
          _likeCount += 1;
        });
      }
    }
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.post.id}/like');
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.post.id}/save');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final base = ref.read(baseUrlProvider);
    final avatar = mediaUrl(post.author?.avatarUrl ?? '', base);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: GestureDetector(
            onTap: () => context.push('/profile/${post.author?.username ?? ''}'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
            ),
          ),
          title: GestureDetector(
            onTap: () => context.push('/profile/${post.author?.username ?? ''}'),
            child: Text(post.author?.username ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          subtitle: post.location.isNotEmpty ? Text(post.location, style: const TextStyle(fontSize: 12)) : null,
          trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showOptions(context)),
        ),
        GestureDetector(
          onDoubleTap: () => _toggleLike(forceLike: true),
          onTap: post.isVideo ? null : widget.onOpenMedia,
          child: AspectRatio(
            aspectRatio: post.aspectRatio > 0 ? post.aspectRatio : 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _mediaWidget(base)),
                // Instagram-style expanding heart burst on double tap.
                AnimatedBuilder(
                  animation: _heart,
                  builder: (context, child) {
                    final t = Curves.easeOutBack.transform(_heart.value);
                    return Opacity(
                      opacity: _heart.value < 0.55 ? 1.0 : 1.0 - ((_heart.value - 0.55) / 0.45),
                      child: Transform.scale(
                        scale: t * 2.4,
                        child: child,
                      ),
                    );
                  },
                  child: const Icon(Icons.favorite, color: Colors.white, size: 64, shadows: [
                    BoxShadow(color: Colors.black26, blurRadius: 16),
                  ]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              AnimatedScale(
                scale: _liked ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: IconButton(
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? Colors.red : null),
                  onPressed: () => _toggleLike(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => showCommentSheet(context, ref, post.id),
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined),
                onPressed: () => showShareSheet(context, ref, post),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: _toggleSave,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_likeCount إعجاب', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${post.author?.username ?? ''} ${post.caption}', style: const TextStyle(height: 1.3)),
              if (post.commentCount > 0)
                TextButton(
                  onPressed: () => showCommentSheet(context, ref, post.id),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    'عرض التعليقات (${formatCount(post.commentCount)})',
                    style: const TextStyle(color: AppTheme.igTextSecondary, fontSize: 12),
                  ),
                ),
              Text(
                post.createdAt != null ? timeAgo(post.createdAt!.toIso8601String()) : '',
                style: const TextStyle(fontSize: 11, color: AppTheme.igTextSecondary),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mediaWidget(String base) {
    if (widget.post.isVideo) {
      final video = _video;
      if (video == null || !video.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: mediaUrl(widget.post.mediaUrl, base),
      fit: BoxFit.cover,
      fadeOutDuration: const Duration(milliseconds: 100),
      fadeInDuration: const Duration(milliseconds: 240),
      placeholder: (_, __) => Container(color: Colors.grey.shade200),
      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
    );
  }

  void _showOptions(BuildContext context) {
    final isMine = widget.post.authorId == ref.read(sessionProvider).user?.id;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('حذف المنشور'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    await ref.read(apiClientProvider).delete('/posts/${widget.post.id}');
                    ref.read(homeFeedProvider.notifier).refresh();
                  } catch (_) {}
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ معرف المنشور'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.post.id));
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
