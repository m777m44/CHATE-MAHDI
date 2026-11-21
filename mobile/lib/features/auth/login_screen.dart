import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _server;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          children: [
            const SizedBox(height: 96),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), AppTheme.igBlue]),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Text('CM', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 36),
            TextField(
              controller: _identifier,
              decoration: const InputDecoration(hintText: 'البريد الإلكتروني أو اسم المستخدم'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'كلمة المرور'),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('خادم API', style: TextStyle(fontSize: 13)),
              children: [
                TextField(
                  controller: _server,
                  decoration: const InputDecoration(hintText: AppConfig.defaultApiBaseUrl),
                ),
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
                      await controller.login(_identifier.text, _password.text, _server.text);
                      if (ref.read(sessionProvider).isAuthed && context.mounted) {
                        context.go('/home');
                      }
                    },
              child: session.busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تسجيل الدخول'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ليس لديك حساب؟ '),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: const Text('إنشاء حساب'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
