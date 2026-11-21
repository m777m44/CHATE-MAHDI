
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_models.dart';
import 'update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._service) : super(UpdateState());

  final UpdateService _service;
  CancelToken? _cancelToken;

  Future<void> loadCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    state = state.copyWith(
      currentVersion: info.version,
      currentBuild: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  /// Fetch latest GitHub release and decide whether an update exists.
  Future<void> checkForUpdate() async {
    state = state.copyWith(phase: UpdatePhase.checking, error: null);
    try {
      await loadCurrentVersion();
      final latest = await _service.fetchLatestRelease();
      if (latest == null) {
        state = state.copyWith(phase: UpdatePhase.upToDate);
        return;
      }
      final newer = _service.isNewerVersion(latest.version, state.currentVersion);
      state = state.copyWith(
        phase: newer ? UpdatePhase.available : UpdatePhase.upToDate,
        latest: latest,
      );
      await _rememberSeenIfNone();
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, error: 'تعذر جلب آخر إصدار: $e');
    }
  }

  /// Show the update dialog only once per released version.
  Future<bool> shouldShowDialogOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'update_dialog_seen';
    final seen = prefs.getString(key);
    final tag = state.latest?.tagName ?? '';
    if (state.isUpdateAvailable && seen != tag) {
      await prefs.setString(key, tag);
      return true;
    }
    return false;
  }

  Future<void> _rememberSeenIfNone() async {
    // Nothing to persist here; flagging happens only when a dialog is shown.
    return;
  }

  /// Downloading stage. After success the state becomes readyToInstall.
  Future<void> downloadUpdate() async {
    final latest = state.latest;
    if (latest == null) return;
    state = state.copyWith(phase: UpdatePhase.downloading, progress: 0, error: null);
    _cancelToken = CancelToken();
    try {
      final file = await _service.downloadApk(
        latest.apkUrl,
        onProgress: (p) {
          if (mounted) state = state.copyWith(progress: p);
        },
        cancelToken: _cancelToken,
      );
      state = state.copyWith(phase: UpdatePhase.readyToInstall, progress: 1);
      await install(file.path);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(phase: UpdatePhase.available, error: null);
        return;
      }
      state = state.copyWith(phase: UpdatePhase.error, error: 'فشل التحميل: ${e.message}');
    } catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, error: 'فشل التحميل: $e');
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  /// Emits any error as PlatformException (INSTALL_FAILED / APK_INVALID).
  Future<void> install(String path) async {
    state = state.copyWith(phase: UpdatePhase.installing, error: null);
    final can = await _service.canInstallUntrustedSources();
    if (!can) {
      await _service.requestInstallPermission();
      state = state.copyWith(
        phase: UpdatePhase.error,
        error: 'امنح التطبيق صلاحية "تثبيت التطبيقات غير المعروفة" ثم أعد المحاولة',
      );
      return;
    }
    try {
      await _service.installApk(path);
      state = state.copyWith(phase: UpdatePhase.installing, error: null);
    } on PlatformException {
      state = state.copyWith(phase: UpdatePhase.error, error: 'فشل فتح المثبِّت');
    }
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier(ref.read(updateServiceProvider));
});
