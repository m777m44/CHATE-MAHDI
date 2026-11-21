import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import 'server_dialog.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');

  final _email = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _validation;

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'الرجاء إدخال بريد إلكتروني صالح';
    }
    if (username.length < 3) return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
    if (!_usernameRegex.hasMatch(username)) {
      return 'اسم المستخدم يقبل الأحرف والأرقام والنقطة وشرطة _ فقط';
    }
    if (password.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);

    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.isAuthed && !(prev?.isAuthed ?? false) && mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email_outlined),
                hintText: 'البريد الإلكتروني',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.alternate_email),
                hintText: 'اسم المستخدم (3 أحرف على الأقل)',
                counterText: '',
              ),
              maxLength: 40,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined),
                hintText: 'الاسم الكامل (اختياري)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'كلمة المرور (8 أحرف على الأقل)',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_validation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_validation!, style: const TextStyle(color: Colors.red)),
              ),
            if (session.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(session.error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: session.busy ? null : () => _submit(controller),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: session.busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إنشاء الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => ServerDialog.show(context),
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: const Text('الخادم الشخصي (متقدم)', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('لديك حساب بالفعل؟ '),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(SessionController controller) async {
    final error = _validate();
    if (error != null) {
      setState(() => _validation = error);
      return;
    }
    setState(() => _validation = null);
    await controller.register(_email.text.trim(), _username.text.trim(), _name.text.trim(), _password.text);
    if (ref.read(sessionProvider).isAuthed && mounted) {
      context.go('/home');
    }
  }
}
