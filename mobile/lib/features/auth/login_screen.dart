import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _obscure = true;
  String? _validation;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
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
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'البريد الإلكتروني أو اسم المستخدم',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onSubmitted: session.busy ? null : (_) => _submit(controller),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'كلمة المرور',
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
                  : const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Future<void> _submit(SessionController controller) async {
    final id = _identifier.text.trim();
    final pass = _password.text;
    if (id.isEmpty || pass.isEmpty) {
      setState(() => _validation = 'الرجاء إدخال البريد أو اسم المستخدم وكلمة المرور');
      return;
    }
    setState(() => _validation = null);
    await controller.login(id, pass);
    if (ref.read(sessionProvider).isAuthed && mounted) {
      context.go('/home');
    }
  }
}
