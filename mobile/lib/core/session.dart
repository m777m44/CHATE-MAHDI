import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'socket_service.dart';
import 'api_client.dart';

/// Simple key-value storage for tokens, session data and app settings.
/// (SharedPreferences keeps update-once-per-version flags too.)
class SessionStorage {
  static late SharedPreferences _prefs;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  static void ensure() {
    if (!_ready) throw StateError('SessionStorage.init not called');
  }

  static String? getString(String key) {
    ensure();
    return _prefs.getString(key);
  }

  static Future<void> setString(String key, String value) async {
    ensure();
    await _prefs.setString(key, value);
  }

  static void remove(String key) {
    ensure();
    _prefs.remove(key);
  }
}

class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class SessionState {
  SessionState({
    this.user,
    this.tokens,
    this.initialized = false,
    this.error,
    this.busy = false,
  });
  final User? user;
  final AuthTokens? tokens;
  final bool initialized;
  final String? error;
  final bool busy;

  bool get isAuthed => user != null && tokens != null;

  SessionState copyWith({
    User? user,
    AuthTokens? tokens,
    bool? initialized,
    String? error,
    bool? busy,
    bool clearError = false,
  }) {
    return SessionState(
      user: user ?? this.user,
      tokens: tokens ?? this.tokens,
      initialized: initialized ?? this.initialized,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this.ref) : super(SessionState()) {
    _restore();
  }

  final Ref ref;

  Future<void> _restore() async {
    await SessionStorage.init();
    final access = SessionStorage.getString('accessToken');
    final refresh = SessionStorage.getString('refreshToken');
    final userJson = SessionStorage.getString('user');
    User? user;
    if (userJson != null) {
      try {
        user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }
    state = StateReady(
      user: user,
      tokens: access != null ? AuthTokens(accessToken: access, refreshToken: refresh ?? '') : null,
      initialized: true,
    );
  }

  Future<void> saveTokens(AuthTokens tokens, Map<String, dynamic> userJson) async {
    await SessionStorage.setString('accessToken', tokens.accessToken);
    await SessionStorage.setString('refreshToken', tokens.refreshToken);
    await SessionStorage.setString('user', jsonEncode(userJson));
    state = state.copyWith(tokens: tokens, user: User.fromJson(userJson));
  }

  Future<void> login(String identifier, String password) async {
    final api = ref.read(apiClientProvider);
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await api
          .post('/auth/login', data: {
            'identifier': identifier,
            'password': password,
          })
          .timeout(const Duration(seconds: 30));
      await _applyAuthResponse(res.data);
      state = state.copyWith(busy: false, clearError: true);
    } on TimeoutException {
      state = state.copyWith(
        busy: false,
        error: 'استغرق الاتصال بالخادم وقتاً طويلاً جداً. تحقق من العنوان والاتصال وحاول مجدداً.',
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: humanError(e));
    }
  }

  /// Extracts tokens + user from an auth endpoint payload and persists them.
  /// Anything unexpected is converted to a readable Arabic error instead of an
  /// uncaught exception (which previously left the button spinning forever).
  Future<void> _applyAuthResponse(dynamic data) async {
    if (data is! Map ||
        data['accessToken'] is! String ||
        data['refreshToken'] is! String ||
        data['user'] is! Map<String, dynamic>) {
      state = state.copyWith(busy: false, error: 'رد غير متوقع من الخادم. تأكد من العنوان وإعدادات الخادم ثم حاول مجدداً.');
      throw StateError('unexpected auth response');
    }
    await saveTokens(
      AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      ),
      data['user'] as Map<String, dynamic>,
    );
  }

  Future<void> register(String email, String username, String name, String password) async {
    final api = ref.read(apiClientProvider);
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await api
          .post('/auth/register', data: {
            'email': email,
            'username': username,
            'name': name.isEmpty ? username : name,
            'password': password,
          })
          .timeout(const Duration(seconds: 30));
      await _applyAuthResponse(res.data);
      state = state.copyWith(busy: false, clearError: true);
    } on TimeoutException {
      state = state.copyWith(
        busy: false,
        error: 'استغرق إنشاء الحساب وقتاً طويلاً جداً. تحقق من العنوان والاتصال وحاول مجدداً.',
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: humanError(e));
    }
  }

  /// Normalizes a user-provided server address to a full API base URL.
  /// Returns null when the input cannot possibly be a valid host.
  static String? normalizeServerUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    while (url.endsWith('/') && url.length > 1) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api')) url = '$url/api';
    final base = Uri.tryParse(url);
    if (base == null || base.host.isEmpty) return null;
    return url;
  }

  /// Points the app at a different personal server and logs out first, so
  /// accounts never mix between servers (each user can run their own server).
  Future<void> setServerUrl(String input) async {
    final url = normalizeServerUrl(input);
    if (url == null) {
      state = state.copyWith(error: 'عنوان الخادم غير صالح. مثال: http://192.168.1.20:4000');
      return;
    }
    if (url == ref.read(baseUrlProvider)) return;
    logout();
    ref.read(baseUrlProvider.notifier).state = url;
    ref.read(apiClientProvider).updateBaseUrl(url);
    await SessionStorage.setString('baseUrl', url);
    state = state.copyWith(clearError: true);
  }

  /// GETs {url}/auth/health with a short timeout. Returns an Arabic error
  /// message, or null when the server answers correctly.
  Future<String?> testServerConnection(String input) async {
    final url = normalizeServerUrl(input);
    if (url == null) return 'عنوان الخادم غير صالح';
    try {
      final res = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (code) => code != null && code < 500,
        ),
      )
          .get('$url/auth/health')
          .timeout(const Duration(seconds: 12));
      final ok = res.data is Map && res.data['ok'] == true;
      if (ok) return null;
      return 'الخادم استجاب لكنه ليس خادم CHATE-MAHDI — تحقق من العنوان';
    } on TimeoutException {
      return 'انتهت المهلة بدون استجابة من الخادم';
    } catch (_) {
      return 'تعذر الوصول إلى الخادم — تحقق من العنوان وشبكة الهاتف';
    }
  }

  /// Refreshes the cached profile after edits done elsewhere in the app.
  Future<void> updateUser(Map<String, dynamic> userJson) async {
    await SessionStorage.setString('user', jsonEncode(userJson));
    state = state.copyWith(user: User.fromJson(userJson));
  }

  void logout() {
    SessionStorage.remove('accessToken');
    SessionStorage.remove('refreshToken');
    SessionStorage.remove('user');
    state = StateReady(initialized: true);
    socketManager.disconnect();
  }
}

/// Marker subclass so restore can set initialized sync-safe.
class StateReady extends SessionState {
  StateReady({super.user, super.tokens, super.initialized = false});
}

/// Maps API failures to short Arabic messages, translating the common
/// class-validator texts so users never see raw English internals.
String humanError(Object e) {
  if (e is! DioException) {
    if (e is StateError) return 'تعذر إكمال العملية، حاول مجدداً';
    return 'تعذر الاتصال بالخادم. حاول مجدداً';
  }
  final data = e.response?.data;
  final dynamic msg = data is Map ? data['message'] : null;
  if (msg != null) {
    final text = (msg is List) ? msg.join('. ') : msg.toString();
    return translateError(text);
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return 'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت أو عنوان الخادم';
  }
  if (e.type == DioExceptionType.cancel) return 'تم إلغاء العملية';
  if (e.response?.statusCode == 404) {
    return 'تعذر العثور على نقطة الاتصال في الخادم. تأكد من أن العنوان صحيح وأن الخادم محدث (يشمل المسار /api).';
  }
  return 'حدث خطأ غير متوقع (${e.response?.statusCode ?? e.type.name})';
}

String translateError(String text) {
  const table = <String, String>{
    'username must be longer than or equal to 3 characters':
        'اسم المستخدم يجب أن يكون 3 أحرف على الأقل',
    'password must be longer than or equal to 8 characters':
        'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
    'email must be an email': 'البريد الإلكتروني غير صالح',
    'Email or username already in use': 'البريد أو اسم المستخدم مستخدم بالفعل',
    'Username may only contain letters, numbers, dots and underscores':
        'اسم المستخدم يقبل الأحرف والأرقام والنقطة وشرطة _ فقط',
    'Invalid credentials': 'بيانات الدخول غير صحيحة',
  };
  for (final entry in table.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return text;
}

final tokensProvider = Provider<AuthTokens?>((ref) => ref.watch(sessionProvider).tokens);

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref);
});
