import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';

/// Personal-server picker. Every user can point the app to their own server
/// instance; switching servers logs out first so accounts never mix.
class ServerDialog extends ConsumerStatefulWidget {
  const ServerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ServerDialog(),
    );
  }

  @override
  ConsumerState<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends ConsumerState<ServerDialog> {
  late final TextEditingController _url;
  bool _testing = false;
  bool _saving = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إعدادات الخادم الشخصي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            const Text(
              'لكل مستخدم سيرفره الخاص وحساباته منفصلة تماماً عن أي خادم آخر. مثال: http://192.168.1.20:4000 أو https://api.example.com',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.dns_outlined),
                hintText: 'http://192.168.1.20:4000',
              ),
            ),
            const SizedBox(height: 12),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: _result == 'تم الاتصال بالخادم بنجاح ✓' ? Colors.green : Colors.red,
                    fontSize: 13,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('اختبار الاتصال'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final error = await ref.read(sessionProvider.notifier).testServerConnection(_url.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = error ?? 'تم الاتصال بالخادم بنجاح ✓';
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _result = null;
    });
    final controller = ref.read(sessionProvider.notifier);
    await controller.setServerUrl(_url.text);
    final error = ref.read(sessionProvider).error;
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      setState(() => _result = error);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث الخادم بنجاح — قم بتسجيل الدخول من جديد')),
    );
  }
}
