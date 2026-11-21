import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

/// Full-screen search overlay: users + posts (captions, hashtags, locations).
Future<void> showSearchOverlay(BuildContext context, WidgetRef ref) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const _SearchOverlay(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _SearchOverlay extends ConsumerStatefulWidget {
  const _SearchOverlay();

  @override
  ConsumerState<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<_SearchOverlay> {
  Timer? _debounce;
  final _controller = TextEditingController();
  List<User> _users = [];
  List<Post> _posts = [];
  bool _busy = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _users = [];
        _posts = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _run);
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/search', query: {'q': q, 'limit': 20});
      setState(() {
        _users = (res.data['users'] as List)
            .map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList();
        _posts = (res.data['posts'] as List)
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();
        _searched = true;
      });
    } catch (_) {
      if (mounted) setState(() => _searched = true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: (_) => _run(),
          decoration: InputDecoration(
            hintText: 'ابحث عن مستخدمين أو هاشتاغات أو أماكن',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade300.withOpacity(0.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_users.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('حسابات', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._users.map((u) => ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage: u.avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(mediaUrl(u.avatarUrl, base))
                              : null,
                          child: u.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(u.username,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: u.name.isNotEmpty ? Text(u.name) : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/profile/${u.username}');
                        },
                      )),
                ],
                if (_posts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('منشورات',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _posts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, i) {
                      final p = _posts[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/media', extra: p);
                        },
                        child: CachedNetworkImage(
                          imageUrl: mediaUrl(p.mediaUrl, base),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      );
                    },
                  ),
                ],
                if (_searched && _users.isEmpty && _posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('لا توجد نتائج')),
                  ),
                if (!_searched)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('ابحث للعثور على أشخاص ومنشورات',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            ),
    );
  }
}
