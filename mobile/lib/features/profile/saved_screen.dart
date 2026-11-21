import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../posts/post_card.dart';

/// Bookmarked/saved posts of the signed-in user.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/users/me/bookmarks');
      if (!mounted) return;
      setState(() {
        _posts = (res.data['posts'] as List)
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحفوظات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('لم تحفظ أي منشورات بعد'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, i) {
                      final p = _posts[i];
                      return PostCard(
                        post: p,
                        onOpenMedia: () => context.push('/media', extra: p),
                      );
                    },
                  ),
                ),
    );
  }
}
