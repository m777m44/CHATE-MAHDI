import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'update_controller.dart';
import 'update_models.dart';

/// Compact banner for the Settings screen ("update available" pill).
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    if (!state.isUpdateAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.igBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.igBlue.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.system_update, color: AppTheme.igBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تحديث متوفر: ${state.latest?.version ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/about'),
              child: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once per version when a newer release exists.
class UpdateDialogOnce extends ConsumerStatefulWidget {
  const UpdateDialogOnce({super.key});

  @override
  ConsumerState<UpdateDialogOnce> createState() => _UpdateDialogOnceState();
}

class _UpdateDialogOnceState extends ConsumerState<UpdateDialogOnce> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(updateProvider.notifier);
      final show = await controller.shouldShowDialogOnce();
      if (show && mounted) {
        await _show(context, ref);
      }
    });
  }

  static Future<void> _show(BuildContext context, WidgetRef ref) {
    final state = ref.read(updateProvider);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث جديد'),
        content: Text(
          'الإصدار ${state.latest?.version ?? ''} متوفر الآن. الإصدار الحالي ${state.currentVersion}.'
          '\nسيتم تنزيل الملف وتثبيته فوق النسخة الموجودة مع الاحتفاظ ببياناتك.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('لاحقاً')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/about');
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "About" screen: version info, check-for-updates, download with progress.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), AppTheme.igBlue]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Text('CM', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                const Text('CHATE-MAHDI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Row('الإصدار الحالي', state.currentVersion.isEmpty ? '—' : state.currentVersion),
          _Row('رقم البناء (versionCode)', state.currentBuild.toString()),
          _Row('آخر إصدار متاح', state.latest?.version ?? '—'),
          _Row('نُشر في', state.latest?.publishedAt?.toIso8601String().split('T').first ?? '—'),
          const SizedBox(height: 16),
          if (state.error != null) ...[
            Text(state.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          const _ProgressArea(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: state.phase == UpdatePhase.checking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('فحص التحديثات'),
            onPressed: state.phase == UpdatePhase.checking || state.phase == UpdatePhase.downloading
                ? null
                : () => notifier.checkForUpdate(),
          ),
          if (state.isUpdateAvailable) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('تحديث الآن'),
              onPressed: state.phase == UpdatePhase.downloading ? null : () => notifier.downloadUpdate(),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const Text(
            'يتم البحث عن التحديثات في مستودع GitHub العام (بدون أي توكن). عند الضغط على "تحديث الآن" يتم تنزيل app-release.apk ثم فتح مثبِّت النظام؛ الاسم المثبَّت (Application ID) ثابت والتحديث سيحافظ على كل بياناتك.',
            style: TextStyle(fontSize: 12, color: AppTheme.igTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProgressArea extends ConsumerWidget {
  const _ProgressArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    if (state.phase == UpdatePhase.downloading) {
      return Column(
        children: [
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 6),
          Text('جارِ التحميل ${(state.progress * 100).toStringAsFixed(0)}%'),
        ],
      );
    }
    if (state.phase == UpdatePhase.installing || state.phase == UpdatePhase.readyToInstall) {
      return const Column(
        children: [
          SizedBox(height: 8),
          Text('جاهز لفتح المثبِّت...', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
