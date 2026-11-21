import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

/// Public/private profile: grid, counters, follow/unfollow, DM shortcut.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _missing = User(id: 'missing', username: '...');

  Map<String, dynamic>? _data;
  User _user = _missing;
  List<Post> _posts = [];
  bool _isSelf = false;
  bool _isFollowing = false;
  bool _followRequested = false;
  bool _canView = false;
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/users/${widget.username}');
      if (!mounted) return;
      final d = res.data as Map<String, dynamic>;
      setState(() {
        _data = d;
        _user = User.fromJson(d['user'] as Map<String, dynamic>);
        _posts = (d['posts'] as List)
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();
        _isSelf = d['isSelf'] == true;
        _isFollowing = d['isFollowing'] == true;
        _followRequested = d['followRequested'] == true;
        _canView = d['canView'] == true;
        _loading = false;
      });
      if (_isSelf) {
        final current = ref.read(sessionProvider).user;
        if (current != null && current.id == _user.id) {
          await ref.read(sessionProvider.notifier).updateUser(d['user'] as Map<String, dynamic>);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      if (_isFollowing || _followRequested) {
        await api.delete('/users/${widget.username}/follow');
        setState(() {
          _isFollowing = false;
          _followRequested = false;
          if (_user.followers > 0) {
            _user = _copyUser(followers: _user.followers - 1);
          }
        });
      } else {
        final res = await api.post('/users/${widget.username}/follow');
        final status = res.data['status']?.toString();
        setState(() {
          if (status == 'PENDING') {
            _followRequested = true;
          } else {
            _isFollowing = true;
          }
          _user = _copyUser(followers: _user.followers + 1);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  User _copyUser({int? followers, int? following}) {
    return User(
      id: _user.id,
      username: _user.username,
      name: _user.name,
      bio: _user.bio,
      avatarUrl: _user.avatarUrl,
      websiteUrl: _user.websiteUrl,
      isPrivate: _user.isPrivate,
      followers: followers ?? _user.followers,
      following: following ?? _user.following,
      postsCount: _user.postsCount,
      createdAt: _user.createdAt,
    );
  }

  Future<void> _openChat() async {
    try {
      final res = await ref.read(apiClientProvider).post('/dm/conversations', data: {
        'participantUsernames': [widget.username],
      });
      final c = res.data['conversation'] as Map<String, dynamic>;
      if (!mounted) return;
      context.push('/dm/${c['id']}', queryParameters: {'title': widget.username});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    final avatar = mediaUrl(_user.avatarUrl, base);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (_isSelf)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () async {
                await context.push('/settings');
                _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundImage:
                                  avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                              child: avatar.isEmpty ? const Icon(Icons.person, size: 40) : null,
                            ),
                            const Spacer(),
                            _stat(formatCount(_user.postsCount), 'منشورات'),
                            const SizedBox(width: 16),
                            _stat(formatCount(_user.followers), 'متابع'),
                            const SizedBox(width: 16),
                            _stat(formatCount(_user.following), 'يتابع'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_user.name.isNotEmpty)
                                Text(_user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (_user.bio.isNotEmpty) Text(_user.bio),
                              if (_user.websiteUrl.isNotEmpty)
                                Text(_user.websiteUrl,
                                    style: const TextStyle(color: AppWebLink.color)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSelf)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push('/edit-profile'),
                                  child: const Text('تعديل الملف الشخصي'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => context.push('/saved'),
                                child: const Icon(Icons.bookmark_border, size: 20),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busy ? null : _toggleFollow,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        (_isFollowing || _followRequested)
                                            ? Theme.of(context).colorScheme.surfaceVariant
                                            : null,
                                    foregroundColor:
                                        (_isFollowing || _followRequested)
                                            ? Theme.of(context).colorScheme.onSurface
                                            : null,
                                  ),
                                  child: Text(
                                    _isFollowing
                                        ? 'إلغاء المتابعة'
                                        : _followRequested
                                            ? 'طلب معلق'
                                            : 'متابعة',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _openChat,
                                  child: const Text('مراسلة'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (!_canView)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('هذا الحساب خاص'),
                          const Text('تابع هذا الحساب لعرض منشوراته',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  else if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('لا توجد منشورات'),
                        ],
                      ),
                    )
                  else
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
                          onTap: () => context.push('/media', extra: p),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: mediaUrl(p.mediaUrl, base),
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey.shade200),
                                errorWidget: (_, __, ___) =>
                                    const Center(child: Icon(Icons.broken_image)),
                              ),
                              if (p.isVideo)
                                const PositionedDirectional(
                                  top: 4,
                                  end: 4,
                                  child: Icon(Icons.play_arrow,
                                      color: Colors.white, size: 18),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class AppWebLink {
  static const color = Color(0xFF0057B8);
}
