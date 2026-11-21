import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/session.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _server;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          children: [
            TextField(controller: _email, decoration: const InputDecoration(hintText: 'البريد الإلكتروني')),
            const SizedBox(height: 12),
            TextField(controller: _username, decoration: const InputDecoration(hintText: 'اسم المستخدم (حروف وأرقام)')),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'الاسم الكامل (اختياري)')),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'كلمة المرور (8 أحرف على الأقل)'),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('خادم API', style: TextStyle(fontSize: 13)),
              children: [
                TextField(controller: _server, decoration: const InputDecoration(hintText: AppConfig.defaultApiBaseUrl)),
              ],
            ),
            const SizedBox(height: 12),
            if (session.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(session.error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: session.busy
                  ? null
                  : () async {
                      await controller.register(
                        _email.text, _username.text, _name.text, _password.text, _server.text,
                      );
                      if (ref.read(sessionProvider).isAuthed && context.mounted) {
                        context.go('/home');
                      }
                    },
              child: session.busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إنشاء الحساب'),
            ),
          ],
        ),
      ),
    );
  }
}
