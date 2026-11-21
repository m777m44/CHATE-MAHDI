import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import 'feed_providers.dart';

/// Convenience: current session user via providers.
final sessionUserProvider = Provider<User?>((ref) => ref.watch(sessionProvider).user);

/// Horizontal story tray shown at the top of the home feed.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesProvider);
    final me = ref.watch(sessionUserProvider);
    final base = ref.watch(baseUrlProvider);
    final myAvatar = mediaUrl(me?.avatarUrl ?? '', base);

    return Container(
      height: 106,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: stories.maybeWhen(
        data: (data) => ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => context.push('/create-story'),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: myAvatar.isNotEmpty ? CachedNetworkImageProvider(myAvatar) : null,
                          child: myAvatar.isEmpty ? const Icon(Icons.person, size: 30) : null,
                        ),
                        const CircleAvatar(
                          radius: 10,
                          backgroundColor: AppTheme.igBlue,
                          child: Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('قصتي', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < data.groups.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => context.push('/story-viewer?group=$i'),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: data.groups[i].stories.every((s) => s.viewed)
                                ? [Colors.grey.shade400, Colors.grey.shade400]
                                : const [Color(0xFFF58529), Color(0xFFDD2A7B), AppTheme.igBlue],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 29,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: data.groups[i].author.avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(mediaUrl(data.groups[i].author.avatarUrl, base))
                                : null,
                            child: data.groups[i].author.avatarUrl.isEmpty
                                ? const Icon(Icons.person, size: 26)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(data.groups[i].author.username, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        orElse: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
