import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

Future<void> showCommentSheet(BuildContext context, WidgetRef ref, String postId) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _CommentsBody(postId: postId),
    ),
  );

  // Keep nested providers in sync (comments provider lives inside the sheet).
  ref.read(commentCountRefreshProvider.notifier).state++;
}

final commentCountRefreshProvider = StateProvider<int>((ref) => 0);

class _CommentsBody extends ConsumerStatefulWidget {
  const _CommentsBody({required this.postId});

  final String postId;

  @override
  ConsumerState<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends ConsumerState<_CommentsBody> {
  List<Comment> _comments = [];
  bool _loading = true;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/posts/${widget.postId}/comments');
      setState(() {
        _comments = (res.data['comments'] as List)
            .map((c) => Comment.fromJson(c as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.postId}/comments', data: {'text': text});
      await _load();
      ref.read(commentCountRefreshProvider.notifier).state++;
    } catch (_) {}
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final capped = _comments.length > 8 ? 8 : _comments.length;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.25 + capped * 56.0,
      width: width,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('التعليقات', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('لا توجد تعليقات بعد'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, i) {
                          final c = _comments[i];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text('${c.author.username} • ${timeAgo(c.createdAt)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text(c.text),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(hintText: 'أضف تعليقاً...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
