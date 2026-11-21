import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils.dart';
import 'stories_row.dart';
import 'feed_providers.dart';
import '../posts/post_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
      child: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('تعذر تحميل المنشورات'),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => ref.read(homeFeedProvider.notifier).refresh(), child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
        data: (data) {
          final posts = data.posts;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const StoriesRow(),
              for (final post in posts)
                PostCard(post: post, onOpenMedia: () => context.push('/media', extra: post)),
              if (data.hasMore)
                TextButton(
                  onPressed: () => ref.read(homeFeedProvider.notifier).loadMore(),
                  child: const Text('تحميل المزيد'),
                ),
              if (!data.hasMore && posts.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('لقد استعرضت كل المنشورات', textAlign: TextAlign.center)),
                ),
            ],
          );
        },
      ),
    );
  }
}
