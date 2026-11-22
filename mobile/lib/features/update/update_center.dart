import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'update_controller.dart';
import 'update_models.dart';

/// Full-screen, animated "Update Center": check, download with live progress,
/// then hand the validated APK to the system installer — entirely in-app.
class UpdateCenterScreen extends ConsumerStatefulWidget {
  const UpdateCenterScreen({super.key});

  @override
  ConsumerState<UpdateCenterScreen> createState() => _UpdateCenterScreenState();
}

class _UpdateCenterScreenState extends ConsumerState<UpdateCenterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..repeat(reverse: true);
    final state = ref.read(updateProvider);
    if (state.phase == UpdatePhase.idle || state.currentVersion.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(updateProvider.notifier).checkForUpdate();
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(state)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 36),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  child: _phaseBody(state, notifier),
                ),
                const SizedBox(height: 36),
                if (state.phase != UpdatePhase.checking && state.phase != UpdatePhase.downloading)
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة فحص الإصدارات'),
                      onPressed: () => notifier.checkForUpdate(),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(UpdateState state) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              const Icon(Icons.system_update_alt, color: Colors.white),
            ],
          ),
          const SizedBox(height: 10),
          ScaleTransition(
            scale: _pulse,
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                alignment: Alignment.center,
                child: const Text('CM',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('مركز التحديث',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'تحديث من داخل التطبيق مع الاحتفاظ بكل بياناتك',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _versionChip('الحالي', state.currentVersion.isEmpty ? '—' : state.currentVersion),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              _versionChip('الأحدث', state.latest?.version ?? '—', filled: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _versionChip(String label, String version, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: filled ? Colors.black54 : Colors.white70, fontSize: 11)),
          Text('v$version',
              style: TextStyle(
                color: filled ? const Color(0xFFDD2A7B) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget _phaseBody(UpdateState state, UpdateNotifier notifier) {
    final key = ValueKey(state.phase);
    switch (state.phase) {
      case UpdatePhase.checking:
        return const Column(
          key: ValueKey(UpdatePhase.checking),
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('يجارٍ فحص أحدث إصدار من GitHub...'),
          ],
        );
      case UpdatePhase.upToDate:
        return const Column(
          key: ValueKey(UpdatePhase.upToDate),
          children: [
            Icon(Icons.verified_rounded, color: Colors.green, size: 72),
            SizedBox(height: 16),
            Text('أنت على أحدث إصدار 🎉', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        );
      case UpdatePhase.available:
        final size = state.latest?.apkSize ?? 0;
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.igBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.download_rounded, color: AppTheme.igBlue, size: 56),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('تحديث جديد متوفر!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (size > 0)
              Center(
                child: Text(
                  'حجم الملف: ${(size / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(color: AppTheme.igTextSecondary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'تحديث الآن',
              icon: Icons.rocket_launch_rounded,
              onTap: () => notifier.downloadUpdate(),
            ),
          ],
        );
      case UpdatePhase.downloading:
        final p = state.progress;
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: p,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: AppTheme.igBlue,
                        backgroundColor: Colors.grey.withOpacity(0.25),
                      ),
                    ),
                    Text('${(p * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: Text('جارٍ تنزيل التحديث...')),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: notifier.cancelDownload,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('إلغاء التنزيل'),
            ),
          ],
        );
      case UpdatePhase.readyToInstall:
      case UpdatePhase.installing:
        return const Column(
          key: ValueKey(UpdatePhase.installing),
          children: [
            Icon(Icons.install_mobile_rounded, color: AppTheme.igBlue, size: 72),
            SizedBox(height: 16),
            Text('جاهز للتثبيت — يجارٍ فتح المثبِّت...',
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'سيحافظ التثبيت على حسابك وكل بياناتك (نفس التوقيع والحزمة).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.igTextSecondary),
            ),
          ],
        );
      case UpdatePhase.error:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              state.error ?? 'حدث خطأ',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            _GradientButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh,
              onTap: () =>
                  state.latest == null ? notifier.checkForUpdate() : notifier.downloadUpdate(),
            ),
          ],
        );
      case UpdatePhase.idle:
        return const SizedBox(height: 8, key: ValueKey('idle'));
    }
  }
}

/// Brand-gradient action button used across the update center.
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
              gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(18)),
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
