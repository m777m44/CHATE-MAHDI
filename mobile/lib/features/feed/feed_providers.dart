import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../models/models.dart';

class FeedData {
  FeedData({required this.posts, required this.hasMore, this.error});
  final List<Post> posts;
  final bool hasMore;
  final String? error;
}

class FeedNotifier extends StateNotifier<AsyncValue<FeedData>> {
  FeedNotifier(this.ref, {required this.reelsOnly}) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref ref;
  final bool reelsOnly;
  int _page = 0;
  bool _busy = false;

  Future<void> refresh() async {
    _page = 0;
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        reelsOnly ? '/feed/reels' : '/feed/home',
        query: {'page': 0, 'limit': 10},
      );
      final posts = (res.data['posts'] as List)
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(FeedData(
        posts: posts,
        hasMore: res.data['hasMore'] == true,
      ));
    } on DioException catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _busy) return;
    _busy = true;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        reelsOnly ? '/feed/reels' : '/feed/home',
        query: {'page': _page + 1, 'limit': 10},
      );
      final posts = (res.data['posts'] as List)
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList();
      _page++;
      state = AsyncValue.data(FeedData(
        posts: [...current.posts, ...posts],
        hasMore: res.data['hasMore'] == true,
      ));
    } catch (_) {
    } finally {
      _busy = false;
    }
  }
}

final homeFeedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<FeedData>>(
  (ref) => FeedNotifier(ref, reelsOnly: false),
);

final reelsFeedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<FeedData>>(
  (ref) => FeedNotifier(ref, reelsOnly: true),
);

// ---------- stories ----------
class StoriesData {
  StoriesData({required this.groups, this.error});
  final List<StoryGroup> groups;
  final String? error;
}

class StoriesNotifier extends StateNotifier<AsyncValue<StoriesData>> {
  StoriesNotifier(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/stories/feed');
      final groups = (res.data['groups'] as List)
          .map((g) => StoryGroup.fromJson(g as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(StoriesData(groups: groups));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markViewed(String storyId) async {
    try {
      await ref.read(apiClientProvider).post('/stories/$storyId/view');
    } catch (_) {}
  }
}

final storiesProvider =
    StateNotifierProvider<StoriesNotifier, AsyncValue<StoriesData>>((ref) {
  return StoriesNotifier(ref);
});

// ---------- realtime notifications badge ----------
class NotificationsUnreadNotifier extends StateNotifier<int> {
  NotificationsUnreadNotifier(this.ref) : super(0) {
    socketManager.notifications.stream.listen((_) {
      bump();
    });
    if (socketManager.connected) {
      socketManager.messages.stream.listen((_) {
        bump();
      });
    }
  }

  final Ref ref;

  void bump() {
    state = state + 1;
  }

  void reset() {
    state = 0;
  }
}

final notificationsUnreadProvider =
    StateNotifierProvider<NotificationsUnreadNotifier, int>((ref) {
  return NotificationsUnreadNotifier(ref);
});
