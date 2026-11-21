import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import 'explore_search.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/explore');
      setState(() {
        _posts = (res.data['posts'] as List)
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => showSearchOverlay(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 20),
                SizedBox(width: 6),
                Text('بحث', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              itemCount: _posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemBuilder: (context, i) {
                final p = _posts[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: mediaUrl(p.mediaUrl, base),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                    ),
                    if (p.isVideo)
                      const PositionedDirectional(
                        top: 4,
                        end: 4,
                        child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
