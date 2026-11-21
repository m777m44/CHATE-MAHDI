/// Latest release info as reported by the GitHub API.
class ReleaseInfo {
  ReleaseInfo({
    required this.tagName,
    required this.apkUrl,
    required this.publishedAt,
    this.apkSize = 0,
  });

  final String tagName;
  final String apkUrl;
  final DateTime? publishedAt;
  final int apkSize; // bytes, 0 when the asset wasn't found

  /// "v1.2.3" -> "1.2.3"
  String get version => tagName.replaceFirst(RegExp('^v', caseSensitive: false), '');
}

enum UpdatePhase {
  idle,            // nothing checked yet / up to date
  checking,
  available,       // newer version found, not downloaded yet
  downloading,
  readyToInstall,  // APK downloaded and validated
  installing,      // handed to the system installer
  upToDate,
  error,
}

class UpdateState {
  UpdateState({
    this.phase = UpdatePhase.idle,
    this.latest,
    this.currentVersion = '',
    this.currentBuild = 0,
    this.progress = 0,
    this.error,
  });

  final UpdatePhase phase;
  final ReleaseInfo? latest;
  final String currentVersion;
  final int currentBuild;
  final double progress; // 0..1
  final String? error;

  bool get isUpdateAvailable => phase == UpdatePhase.available && latest != null;

  UpdateState copyWith({
    UpdatePhase? phase,
    ReleaseInfo? latest,
    String? currentVersion,
    int? currentBuild,
    double? progress,
    String? error,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      latest: latest ?? this.latest,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuild: currentBuild ?? this.currentBuild,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}
