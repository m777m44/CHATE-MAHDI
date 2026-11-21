import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/utils.dart';

/// Edit name / bio / website / avatar (avatar uploaded via /media/upload).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _website;
  String _avatarUrl = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _website = TextEditingController(text: user?.websiteUrl ?? '');
    _avatarUrl = user?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 720,
    );
    if (picked == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final res = await api.dio.post('${api.dio.options.baseUrl}/media/upload', data: form);
      if (res.data is Map && res.data['url'] != null) {
        setState(() => _avatarUrl = res.data['url'] as String);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر رفع الصورة')));
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).patch('/users/me', data: {
        if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'websiteUrl': _website.text.trim(),
        'avatarUrl': _avatarUrl,
      });
      await ref
          .read(sessionProvider.notifier)
          .updateUser(res.data as Map<String, dynamic>);
      if (mounted) context.pop();
    } catch (_) {
      setState(() => _error = 'تعذر حفظ التعديلات');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.read(baseUrlProvider);
    final avatar = mediaUrl(_avatarUrl, base);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('حفظ'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundImage:
                    avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty
                    ? const Icon(Icons.person, size: 44)
                    : const Icon(Icons.camera_alt, size: 22, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            const Text('تغيير صورة الملف الشخصي', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'نبذة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _website,
              decoration: const InputDecoration(
                  labelText: 'الرابط (Website)', border: OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
