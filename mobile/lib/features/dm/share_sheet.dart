import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

/// Share a post as a POST_SHARE message into any conversation,
/// or create a new conversation by username.
Future<void> showShareSheet(BuildContext context, WidgetRef ref, Post post) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ShareSheet(post: post),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.post});

  final Post post;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  bool _sending = false;
  String? _sentTo;
  final _newUser = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newUser.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/dm/conversations');
      setState(() {
        _conversations = (res.data['conversations'] as List)
            .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _send(String conversationId, String title) async {
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).post('/dm/conversations/$conversationId/messages', data: {
        'type': 'POST_SHARE',
        'sharedPostId': widget.post.id,
      });
      setState(() => _sentTo = title);
    } catch (e) {
      setState(() => _error = 'تعذر إرسال المنشور');
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _createAndSend() async {
    final username = _newUser.text.trim().toLowerCase();
    if (username.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/dm/conversations', data: {
        'participantUsernames': [username],
      });
      final id = (res.data['conversation'] as Map<String, dynamic>)['id'] as String;
      await _send(id, username);
    } catch (_) {
      setState(() => _error = 'تعذر إنشاء المحادثة أو إرسالها');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sentTo != null ? 'تم إرسال المنشور إلى $_sentTo ✓' : 'مشاركة المنشور مع',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newUser,
                      decoration: const InputDecoration(
                        hintText: 'اسم مستخدم لإرسال محادثة جديدة',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _createAndSend,
                    child: const Text('إرسال'),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, i) {
                      final c = _conversations[i];
                      final other = c.participants.isNotEmpty ? c.participants.first : null;
                      final avatar = mediaUrl(other?.avatarUrl ?? '', base);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(c.title),
                        onTap: _sending || _sentTo != null
                            ? null
                            : () => _send(c.id, c.title),
                      );
                    },
                  ),
                ),
              if (_sentTo != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
