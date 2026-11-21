import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../feed/feed_providers.dart';

/// Activity page: persisted notification history, live via socket badge.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/notifications');
      final items = (res.data['notifications'] as List)
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      await api.post('/notifications/read');
      if (mounted) ref.read(notificationsUnreadProvider.notifier).reset();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(String type) {
    switch (type) {
      case 'LIKE':
        return 'أعجب بمنشورك';
      case 'COMMENT':
        return 'علّق على منشورك';
      case 'FOLLOW':
        return 'بدأ متابعتك';
      case 'MENTION':
        return 'أشار إليك في تعليق';
      case 'MESSAGE':
        return 'أرسل لك رسالة';
      default:
        return 'تفاعل معك';
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'LIKE':
        return Icons.favorite;
      case 'COMMENT':
        return Icons.chat_bubble;
      case 'FOLLOW':
        return Icons.person_add;
      case 'MENTION':
        return Icons.alternate_email;
      case 'MESSAGE':
        return Icons.send;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد إشعارات'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final n = _items[i];
                      final avatar = mediaUrl(n.actor.avatarUrl, base);
                      final actorName = n.actor.username;
                      void Function()? onTap;
                      if (n.type == 'MESSAGE') {
                        onTap = () => context.push('/dm/${n.entityId}');
                      } else {
                        onTap = () => context.push('/profile/$actorName');
                      }
                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  avatar.isNotEmpty ? NetworkImage(avatar) : null,
                              child: avatar.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            PositionedDirectional(
                              bottom: -2,
                              end: -2,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: Icon(_icon(n.type),
                                    size: 12,
                                    color: n.type == 'LIKE' ? Colors.red : AppIconColors.blue),
                              ),
                            ),
                          ],
                        ),
                        title: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: actorName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: ' ${_text(n.type)}'),
                            ],
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: n.createdAt != null
                            ? Text(timeAgo(n.createdAt!.toIso8601String()),
                                style: const TextStyle(fontSize: 11, color: Colors.grey))
                            : null,
                        tileColor: n.read ? null : Theme.of(context).colorScheme.primary.withOpacity(0.04),
                        onTap: onTap,
                      );
                    },
                  ),
                ),
    );
  }
}

class AppIconColors {
  static const blue = Color(0xFF0095F6);
}
