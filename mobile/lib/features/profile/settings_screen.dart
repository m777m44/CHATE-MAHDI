import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show themeModeProvider;
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../auth/server_dialog.dart';
import '../update/update_controller.dart';
import '../update/update_models.dart';
import '../update/update_ui.dart';

/// Settings: appearance, privacy, in-app update, logout.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final updateState = ref.watch(updateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          const UpdateBanner(),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('المظهر'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('نهاري')),
                ButtonSegment(value: ThemeMode.dark, label: Text('ليلي')),
                ButtonSegment(value: ThemeMode.system, label: Text('تلقائي')),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref.read(themeModeProvider.notifier).set(selection.first);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('حساب خاص'),
            subtitle: const Text('لا يمكن رؤية منشوراتك إلا من تتابعه'),
            value: user?.isPrivate ?? false,
            onChanged: (v) async {
              try {
                final res = await ref.read(apiClientProvider).patch('/users/me', data: {
                  'isPrivate': v,
                });
                await ref
                    .read(sessionProvider.notifier)
                    .updateUser(res.data as Map<String, dynamic>);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تعذر تحديث الخصوصية')));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('الخادم الشخصي'),
            subtitle: Text(ref.watch(baseUrlProvider).replaceFirst(RegExp('^https?://'), '')),
            onTap: () => ServerDialog.show(context),
          ),
          const ListTile(
            leading: Icon(Icons.system_update),
            title: Text('التحديثات'),
            subtitle: Text('افتح مركز التحديث لفحص وتنزيل التحديث'),
          ),
          if (updateState.phase == UpdatePhase.checking)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('حول التطبيق'),
            subtitle: const Text('الإصدار ومعلومات التحديث'),
            onTap: () => context.push('/about'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل تريد تسجيل الخروج من الحساب؟'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('إلغاء')),
                    FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('خروج')),
                  ],
                ),
              );
              if (ok == true && mounted) {
                ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
