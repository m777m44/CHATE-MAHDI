/// Global app configuration constants.
class AppConfig {
  AppConfig._();

  static const appName = 'CHATE-MAHDI';

  /// Default API base URL for the backend.
  /// - Android emulator reaches host machine through 10.0.2.2
  /// - Override at build time with: `--dart-define=API_BASE_URL=https://your-server/api`
  /// - Users can also change it on the login screen (stored locally).
  static const defaultApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000/api');

  // In-app update (public GitHub info - NO tokens inside the app).
  static const updateRepoOwner = 'm777m44';
  static const updateRepoName = 'CHATE-MAHDI';
  static const updateRepoSlug = 'm777m44/CHATE-MAHDI';
  static const latestReleaseApiUrl =
      'https://api.github.com/repos/m777m44/CHATE-MAHDI/releases/latest';
  static const latestApkUrl =
      'https://github.com/m777m44/CHATE-MAHDI/releases/latest/download/app-release.apk';
  static const repoUrl = 'https://github.com/m777m44/CHATE-MAHDI';
  static const apkAssetName = 'app-release.apk';
}
