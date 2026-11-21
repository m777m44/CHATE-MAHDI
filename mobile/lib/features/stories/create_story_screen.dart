import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  XFile? _file;
  final _overlay = TextEditingController();
  bool _uploading = false;
  double _progress = 0;

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickMedia(
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (picked != null) {
      setState(() => _file = picked);
    }
  }

  Future<String?> _upload() async {
    if (_file == null) return null;
    final api = ref.read(apiClientProvider);
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(_file!.path, filename: _file!.name),
    });
    final res = await api.dio.post(
      api.dio.options.baseUrl + '/media/upload',
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0) {
          setState(() => _progress = sent / total);
        }
      },
    );
    if (res.data is Map && res.data['url'] != null) {
      return res.data['url'] as String;
    }
    return null;
  }

  Future<void> _publish() async {
    if (_file == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final url = await _upload();
      if (url == null) throw Exception('upload failed');
      await ref.read(apiClientProvider).post('/stories', data: {
        'mediaUrl': url,
        'overlayText': _overlay.text.trim(),
      });
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل نشر القصة: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قصة جديدة'),
        actions: [
          TextButton(
            onPressed: (_file != null && !_uploading) ? _publish : null,
            child: _uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('نشر'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _file == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('من المعرض'),
                          onPressed: () => _pick(ImageSource.gallery),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('الكاميرا'),
                          onPressed: () => _pick(ImageSource.camera),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(_file!.path), fit: BoxFit.contain),
                      if (_uploading)
                        LinearProgressIndicator(value: _progress),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _overlay,
              decoration: const InputDecoration(hintText: 'نص أو ملصق على القصة (اختياري)'),
            ),
          ),
        ],
      ),
    );
  }
}
