import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../feed/feed_providers.dart';
import 'story_viewers_sheet.dart';

/// Instagram-style full-screen story viewer:
///  - segmented progress bar at the top
///  - tap right/left to advance/rewind
///  - marks each story as viewed
///  - authors can open the viewers list
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.initialGroup});

  final int initialGroup;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  int _groupIndex = 0;
  int _storyIndex = 0;
  VideoPlayerController? _video;
  bool _videoReady = false;
  Timer? _timer;
  final Set<String> _marked = {};

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroup;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  List<StoryGroup> get _groups {
    final s = ref.read(storiesProvider).value;
    return s?.groups ?? const [];
  }

  Story? get _current {
    final groups = _groups;
    if (groups.isEmpty) return null;
    final gi = _groupIndex.clamp(0, groups.length - 1).toInt();
    final stories = groups[gi].stories;
    if (stories.isEmpty) return null;
    return stories[_storyIndex.clamp(0, stories.length - 1).toInt()];
  }

  void _startTimer() {
    _timer?.cancel();
    if (_video == null || !_videoReady) {
      _timer = Timer(const Duration(seconds: 6), () => _go(forward: true));
    }
    // video stories advance through the video controls (loop + manual taps)
  }

  Future<void> _prepareCurrent() async {
    final story = _current;
    if (story == null) return;
    if (!_marked.contains(story.id)) {
      _marked.add(story.id);
      ref.read(storiesProvider.notifier).markViewed(story.id);
    }
    _timer?.cancel();
    _video?.dispose();
    _video = null;
    _videoReady = false;
    final isVideo = story.mediaUrl.toLowerCase().endsWith('.mp4')
        || story.mediaUrl.toLowerCase().contains('video');
    if (isVideo) {
      final base = ref.read(baseUrlProvider);
      final c = VideoPlayerController.networkUrl(Uri.parse(mediaUrl(story.mediaUrl, base)));
      try {
        await c.initialize();
        c.setLooping(true);
        c.play();
        _video = c;
        _videoReady = true;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {});
      _startTimer();
    }
  }

  void _go({required bool forward}) {
    final groups = _groups;
    if (groups.isEmpty) return;
    if (!forward) {
      if (_storyIndex > 0) {
        setState(() => _storyIndex--);
      } else if (_groupIndex > 0) {
        setState(() {
          _groupIndex--;
          _storyIndex = 0;
        });
      }
    } else {
      final group = groups[_groupIndex.clamp(0, groups.length - 1).toInt()];
      if (_storyIndex + 1 < group.stories.length) {
        setState(() => _storyIndex++);
      } else if (_groupIndex + 1 < groups.length) {
        setState(() {
          _groupIndex++;
          _storyIndex = 0;
        });
      } else {
        Navigator.of(context).maybePop();
        return;
      }
    }
    _prepareCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAll = ref.watch(storiesProvider).value?.groups ?? const [];
    if (groupsAll.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    _groupIndex = _groupIndex.clamp(0, groupsAll.length - 1).toInt();
    final group = groupsAll[_groupIndex];
    final story = group.stories.isEmpty ? null : group.stories[_storyIndex.clamp(0, group.stories.length - 1).toInt()];
    final base = ref.read(baseUrlProvider);
    final isMine = group.author.id == ref.read(sessionProvider).user?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: story == null
          ? const Center(child: Text('لا توجد قصص', style: TextStyle(color: Colors.white)))
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final w = MediaQuery.of(context).size.width;
                if (details.localPosition.dx < w / 2) {
                  _go(forward: false);
                } else {
                  _go(forward: true);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoReady && _video != null && _video!.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _video!.value.aspectRatio,
                        child: VideoPlayer(_video!),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: mediaUrl(story.mediaUrl, base),
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const Center(child: CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white, size: 60),
                      ),
                    ),
                  if (story.overlayText.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.all(48),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          story.overlayText,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < group.stories.length; i++)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    color: i == _storyIndex
                                        ? AppTheme.igBlue
                                        : Colors.white.withOpacity(i < _storyIndex ? 0.9 : 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey.shade700,
                                backgroundImage: group.author.avatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(mediaUrl(group.author.avatarUrl, base))
                                    : null,
                                child: group.author.avatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                group.author.username,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo(story.createdAt),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              const Spacer(),
                              if (isMine)
                                IconButton(
                                  icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                                  onPressed: () => showStoryViewers(context, ref, story.id),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareCurrent();
  }
}
