import 'dart:io';

import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../feed/feed_providers.dart';

/// Create post (or Reel): pick media (compressed), caption + location,
/// upload to /media/upload then POST /posts.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  XFile? _file;
  final _caption = TextEditingController();
  final _location = TextEditingController();
  bool _isReel = false;
  bool _busy = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  bool get _fileIsVideo {
    final path = _file?.path.toLowerCase() ?? '';
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        (_file?.mimeType?.startsWith('video') ?? false);
  }

  Future<void> _pick({required bool video}) async {
    final XFile? picked;
    if (video) {
      picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } else {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1440,
      );
    }
    if (picked != null) {
      setState(() {
        _file = picked;
        _isReel = video;
      });
    }
  }

  Future<void> _publish() async {
    if (_file == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(_file!.path, filename: _file!.name),
      });
      final res = await api.dio.post(
        '${api.dio.options.baseUrl}/media/upload',
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = sent / total);
          }
        },
      );
      final url = res.data is Map ? res.data['url'] as String? : null;
      if (url == null) throw Exception('upload failed');
      await api.post('/posts', data: {
        'mediaUrl': url,
        'mediaType': _fileIsVideo ? 'VIDEO' : 'IMAGE',
        'caption': _caption.text.trim(),
        'location': _location.text.trim(),
        'isReel': _isReel,
        'aspectRatio': _fileIsVideo ? 9.0 / 16.0 : 1.0,
      });
      ref.read(homeFeedProvider.notifier).refresh();
      if (mounted) {
        context.go('/home');
      }
    } catch (_) {
      setState(() => _error = 'فشل نشر المنشور، حاول مرة أخرى');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReel ? 'ريلز جديد' : 'منشور جديد'),
        actions: [
          TextButton(
            onPressed: (_file == null || _busy) ? null : _publish,
            child: const Text('نشر'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('صورة'),
                    onPressed: _busy ? null : () => _pick(video: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.videocam),
                    label: const Text('فيديو (ريلز)'),
                    onPressed: _busy ? null : () => _pick(video: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_file == null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('اختر صورة أو فيديو للنشر'),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 260,
                  child: _fileIsVideo
                      ? _VideoPreview(path: _file!.path)
                      : Image.file(File(_file!.path), fit: BoxFit.cover),
                ),
              ),
            if (_busy && _progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _progress),
                    Text('جارٍ الرفع ${(_progress * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              maxLines: 3,
              maxLength: 2200,
              decoration: const InputDecoration(
                labelText: 'اكتب وصفاً (Caption)',
                hintText: 'استخدم #هاشتاغ لتصنيف منشورك',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'الموقع (اختياري)',
                icon: Icon(Icons.location_on_outlined),
              ),
            ),
            SwitchListTile(
              title: const Text('نشر كريلز'),
              value: _isReel,
              onChanged: _busy ? null : (v) => setState(() => _isReel = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.path});

  final String path;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.file(File(widget.path));
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
        AspectRatio(
          aspectRatio: ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : 0.6,
          child: VideoPlayer(ctrl),
        ),
        IconButton(
          icon: Icon(ctrl.value.isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
              size: 48, color: Colors.white),
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
