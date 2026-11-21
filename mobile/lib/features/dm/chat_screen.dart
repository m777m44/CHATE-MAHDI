import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/socket_service.dart';
import '../../core/utils.dart';
import '../../models/models.dart';

/// One conversation. Real-time via /rt socket events plus initial REST load.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.title});

  final String conversationId;
  final String title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Message> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _subNew;
  StreamSubscription<Map<String, dynamic>>? _subTyping;
  String? _myId;
  bool _typingPeer = false;
  Timer? _typingClear;
  Timer? _typingEmit;
  bool _loading = true;
  bool _sendingMedia = false;

  @override
  void initState() {
    super.initState();
    _myId = ref.read(sessionProvider).user?.id;
    _subNew = socketManager.messages.listen((data) {
      if (data['conversationId'] != widget.conversationId) return;
      final raw = data['message'];
      if (raw is Map<String, dynamic>) _append(Message.fromJson(raw));
    });
    _subTyping = socketManager.typing.listen((data) {
      if (data['conversationId'] != widget.conversationId) return;
      if (!mounted) return;
      _typingClear?.cancel();
      setState(() => _typingPeer = data['typing'] == true);
      if (data['typing'] == true) {
        _typingClear = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _typingPeer = false);
        });
      }
    });
    _load();
    _markRead();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _subNew?.cancel();
    _subTyping?.cancel();
    _typingClear?.cancel();
    _typingEmit?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/dm/conversations/${widget.conversationId}/messages');
      if (!mounted) return;
      setState(() {
        _messages = (res.data['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _append(Message m) {
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() => _messages = [..._messages, m]);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(apiClientProvider)
          .post('/dm/conversations/${widget.conversationId}/read');
    } catch (_) {}
  }

  void _onInputChanged(String text) {
    if (_typingEmit == null || !_typingEmit!.isActive) {
      socketManager.emitTyping(widget.conversationId, true);
      _typingEmit = Timer(const Duration(seconds: 2), () {
        socketManager.emitTyping(widget.conversationId, false);
      });
    }
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/dm/conversations/${widget.conversationId}/messages', data: {
        'type': 'TEXT',
        'content': text,
      });
      final raw = res.data['message'];
      if (raw is Map<String, dynamic>) _append(Message.fromJson(raw));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر إرسال الرسالة')));
      }
    }
  }

  Future<void> _sendMedia() async {
    if (_sendingMedia) return;
    final picked = await ImagePicker().pickMedia(imageQuality: 85, maxWidth: 1440);
    if (picked == null) return;
    setState(() => _sendingMedia = true);
    try {
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final res = await api.dio.post(
        '${api.dio.options.baseUrl}/media/upload',
        data: form,
      );
      final url = res.data is Map ? res.data['url'] as String? : null;
      if (url == null) throw Exception('upload failed');
      final isVideo = picked.path.toLowerCase().endsWith('.mp4') ||
          picked.path.toLowerCase().endsWith('.mov') ||
          (picked.mimeType?.startsWith('video') ?? false);
      final sent = await ref
          .read(apiClientProvider)
          .post('/dm/conversations/${widget.conversationId}/messages', data: {
        'type': isVideo ? 'VIDEO' : 'IMAGE',
        'content': url,
      });
      final raw = sent.data['message'];
      if (raw is Map<String, dynamic>) _append(Message.fromJson(raw));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر إرسال الوسائط')));
      }
    }
    if (mounted) setState(() => _sendingMedia = false);
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, overflow: TextOverflow.ellipsis),
                  if (_typingPeer)
                    Text('يكتب الآن...',
                        style: TextStyle(
                            fontSize: 11,
                            color: dark ? Colors.greenAccent : Colors.green)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.sender.id == _myId;
                      return _bubble(m, mine, base, dark);
                    },
                  ),
          ),
          if (_sendingMedia)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                    icon: _sendingMedia
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined),
                    onPressed: _sendMedia),
                Expanded(
                  child: TextField(
                    controller: _input,
                    onChanged: _onInputChanged,
                    onSubmitted: (_) => _sendText(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Message m, bool mine, String base, bool dark) {
    final bg = mine
        ? AppBubbleColors.mine
        : (dark ? const Color(0xFF262626) : const Color(0xFFEFEFEF));
    Widget content;
    switch (m.type) {
      case 'IMAGE':
      case 'VIDEO':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 220,
            height: 220,
            child: m.type == 'VIDEO'
                ? _VideoBubble(url: mediaUrl(m.content, base))
                : CachedNetworkImage(
                    imageUrl: mediaUrl(m.content, base),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
          ),
        );
        break;
      case 'POST_SHARE':
        final sp = m.sharedPost;
        content = InkWell(
          onTap: sp != null ? () => context.push('/media', extra: _normalizePost(sp)) : null,
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('منشور مشترك',
                    style: TextStyle(
                        fontSize: 11,
                        color: mine ? Colors.white70 : Colors.grey,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (sp!.mediaUrl.isNotEmpty)
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl(sp.mediaUrl, base),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${sp.author?.username ?? ''} ${sp.caption}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: mine ? Colors.white : null),
                ),
              ],
            ),
          ),
        );
        break;
      default:
        content = Text(m.content, style: TextStyle(color: mine ? Colors.white : null));
    }
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: m.type == 'TEXT' ? 10 : 6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: content,
      ),
    );
  }

  Post _normalizePost(Post partial) => Post(
        id: partial.id,
        authorId: partial.authorId,
        mediaUrl: partial.mediaUrl,
        mediaType: partial.mediaType,
        createdAt: partial.createdAt ?? DateTime.now(),
      );
}

class AppBubbleColors {
  static Color get mine => const Color(0xFF3797F0);
}

class _VideoBubble extends StatefulWidget {
  const _VideoBubble({required this.url});

  final String url;

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _ctrl = c);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.size.width,
            height: ctrl.value.size.height,
            child: VideoPlayer(ctrl),
          ),
        ),
        IconButton(
          icon: Icon(ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white),
          onPressed: () {
            setState(() {
              if (ctrl.value.isPlaying) {
                ctrl.pause();
              } else {
                ctrl.play();
              }
            });
          },
        ),
      ],
    );
  }
}
