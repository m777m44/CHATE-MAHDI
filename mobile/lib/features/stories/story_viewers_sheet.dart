import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';

Future<void> showStoryViewers(BuildContext context, WidgetRef ref, String storyId) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => _StoryViewers(storyId: storyId),
  );
}

class _StoryViewers extends ConsumerStatefulWidget {
  const _StoryViewers({required this.storyId});

  final String storyId;

  @override
  ConsumerState<_StoryViewers> createState() => _StoryViewersState();
}

class _StoryViewersState extends ConsumerState<_StoryViewers> {
  bool _loading = true;
  List<User> _viewers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/stories/${widget.storyId}/viewers');
      setState(() {
        _viewers = (res.data['viewers'] as List)
            .map((v) => User.fromJson(v as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('المشاهدات', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _viewers.isEmpty
                    ? const Center(child: Text('لا يوجد مشاهدون بعد'))
                    : ListView.builder(
                        itemCount: _viewers.length,
                        itemBuilder: (context, i) => ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(_viewers[i].username),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
