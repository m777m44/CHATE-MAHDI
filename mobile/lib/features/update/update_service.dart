import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config.dart';
import 'update_models.dart';

/// Implements the In-App Update flow:
///   1. latest release metadata  -> GitHub API (public, no token)
///   2. comparison               -> semantic version (v prefix accepted)
///   3. download                 -> Dio into {cacheDir}/update/CHATE-MAHDI.apk
///   4. validation               -> exists, extension .apk, size > 0
///   5. installation             -> native MethodChannel:
///        canInstall() / requestInstallPermission() / installApk(path)
///      which uses FileProvider + ACTION_VIEW (system installer). Installing
///      over the current app preserves all user data.
class UpdateService {
  static const _channel = MethodChannel('com.mahdim44.chatemahdi/install');

  final Dio dio = Dio();

  /// GET https://api.github.com/repos/{repo}/releases/latest
  Future<ReleaseInfo?> fetchLatestRelease() async {
    final res = await dio.get<Map<String, dynamic>>(
      AppConfig.latestReleaseApiUrl,
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    final data = res.data;
    if (data == null) return null;
    final tagName = data['tag_name']?.toString() ?? '';
    if (tagName.isEmpty) return null;

    String? apkUrl;
    int apkSize = 0;
    final assets = (data['assets'] as List<dynamic>? ?? []);
    for (final asset in assets) {
      if (asset is Map && asset['name'] == AppConfig.apkAssetName) {
        apkUrl = asset['browser_download_url']?.toString();
        apkSize = (asset['size'] is num) ? (asset['size'] as num).toInt() : 0;
      }
    }
    return ReleaseInfo(
      tagName: tagName,
      apkUrl: apkUrl ?? AppConfig.latestApkUrl,
      publishedAt: DateTime.tryParse(data['published_at']?.toString() ?? ''),
      apkSize: apkSize,
    );
  }

  /// Semantic comparison, tolerant to "1.2", "1.2.3", "v1.2.3+7".
  bool isNewerVersion(String remote, String current) {
    final r = _parts(remote);
    final c = _parts(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] != c[i]) return r[i] > c[i];
    }
    return false;
  }

  List<int> _parts(String v) {
    final clean = v.replaceFirst(RegExp('^v', caseSensitive: false), '').split('-')[0];
    final segs = clean.split('+')[0].split('.');
    return [0, 1, 2].map((i) => i < segs.length ? (int.tryParse(segs[i]) ?? 0) : 0).toList();
  }

  /// Downloads the APK with progress callbacks [0..1] and validates it.
  Future<File> downloadApk(
    String url, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final updateDir = Directory('${dir.path}${Platform.pathSeparator}update');
    await updateDir.create(recursive: true);
    final path = '${updateDir.path}${Platform.pathSeparator}${AppConfig.apkAssetName}';
    final file = File(path);
    if (await file.exists()) await file.delete();

    await dio.download(
      url,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );

    // Validate: exists, correct extension, non-empty file.
    if (!await file.exists()) {
      throw Exception('APK download failed: file not found');
    }
    if (!path.toLowerCase().endsWith('.apk')) {
      throw Exception('APK download failed: wrong extension');
    }
    if ((await file.length()) == 0) {
      throw Exception('APK download failed: empty file');
    }
    return file;
  }

  Future<bool> canInstallUntrustedSources() async {
    try {
      final res = await _channel.invokeMethod<bool>('canInstall');
      return res ?? true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod('requestInstallPermission');
    } on PlatformException {
      // user denied or platform too old - ignore, install attempt will fail
    }
  }

  /// Emits any error as PlatformException (message: INSTALL_FAILED / APK_INVALID).
  Future<void> installApk(String path) async {
    await _channel.invokeMethod('installApk', {'path': path});
  }
}
