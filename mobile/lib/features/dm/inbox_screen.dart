import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

/// DM inbox: conversation list + create direct/group conversations.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  List<Conversation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    socketManager.messages.stream.listen((data) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/dm/conversations');
      if (!mounted) return;
      setState(() {
        _items = (res.data['conversations'] as List)
            .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newConversation() async {
    final usernameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _NewConversationSheet(
        usernameCtrl: usernameCtrl,
        titleCtrl: titleCtrl,
      ),
    );

    if (ok == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل'),
        actions: [
          IconButton(icon: const Icon(Icons.add_comment_outlined), onPressed: _newConversation),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد محادثات بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final c = _items[i];
                      final other = c.participants.isNotEmpty ? c.participants.first : null;
                      final avatar = mediaUrl(other?.avatarUrl ?? '', base);
                      final last = c.lastMessage;
                      final preview = last == null
                          ? 'ابدأ المحادثة'
                          : last.type == 'TEXT'
                              ? last.content
                              : last.type == 'POST_SHARE'
                                  ? 'منشور مشترك'
                                  : (last.type == 'IMAGE' ? 'صورة' : 'فيديو');
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(c.title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: last?.createdAt != null
                            ? Text(
                                timeAgo(last!.createdAt!.toIso8601String()),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              )
                            : null,
                        onTap: () => context.push(
                          '/dm/${c.id}',
                          queryParameters: {'title': c.title},
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet({required this.usernameCtrl, required this.titleCtrl});

  final TextEditingController usernameCtrl;
  final TextEditingController titleCtrl;

  @override
  ConsumerState<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<_NewConversationSheet> {
  bool group = false;
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('محادثة جماعية'),
            value: group,
            onChanged: (v) => setState(() => group = v),
          ),
          TextField(
            controller: widget.usernameCtrl,
            decoration: InputDecoration(
              labelText: group ? 'أسماء المستخدمين (مفصولة بفاصلة)' : 'اسم المستخدم',
              border: const OutlineInputBorder(),
            ),
          ),
          if (group)
            TextField(
              controller: widget.titleCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المجموعة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final api = ref.read(apiClientProvider);
                      final names = widget.usernameCtrl.text
                          .split(',')
                          .map((s) => s.trim().toLowerCase())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      if (names.isEmpty) return;
                      setState(() => busy = true);
                      try {
                        final res = await api.post('/dm/conversations', data: {
                          'participantUsernames': names,
                          if (group && widget.titleCtrl.text.trim().isNotEmpty)
                            'title': widget.titleCtrl.text.trim(),
                        });
                        final c = (res.data['conversation'] as Map<String, dynamic>);
                        if (!mounted) return;
                        Navigator.of(context).pop(true);
                        if (context.mounted) {
                          context.push(
                            '/dm/${c['id']}',
                            queryParameters: {'title': c['title']?.toString() ?? 'محادثة'},
                          );
                        }
                      } catch (_) {
                        setState(() {
                          busy = false;
                          error = 'تعذر إنشاء المحادثة. تحقق من أسماء المستخدمين.';
                        });
                      }
                    },
              child: Text(busy ? 'جارٍ الإنشاء...' : 'إنشاء'),
            ),
          ),
        ],
      ),
    );
  }
}
