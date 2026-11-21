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

  Future<void> login(String identifier, String password, String serverUrl) async {
    await _applyServerUrl(serverUrl);
    final api = ref.read(apiClientProvider);
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await api.post('/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });
      await saveTokens(
        AuthTokens(accessToken: res.data['accessToken'], refreshToken: res.data['refreshToken']),
        (res.data['user'] as Map<String, dynamic>),
      );
      state = state.copyWith(busy: false, clearError: true);
    } on DioException catch (e) {
      state = state.copyWith(busy: false, error: humanError(e));
    }
  }

  Future<void> register(String email, String username, String name, String password, String serverUrl) async {
    await _applyServerUrl(serverUrl);
    final api = ref.read(apiClientProvider);
    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await api.post('/auth/register', data: {
        'email': email,
        'username': username,
        'name': name.isEmpty ? username : name,
        'password': password,
      });
      await saveTokens(
        AuthTokens(accessToken: res.data['accessToken'], refreshToken: res.data['refreshToken']),
        (res.data['user'] as Map<String, dynamic>),
      );
      state = state.copyWith(busy: false, clearError: true);
    } on DioException catch (e) {
      state = state.copyWith(busy: false, error: humanError(e));
    }
  }

  Future<void> _applyServerUrl(String serverUrl) async {
    final url = serverUrl.trim();
    if (url.isNotEmpty) {
      ref.read(baseUrlProvider.notifier).state = url;
      ref.read(apiClientProvider).updateBaseUrl(url);
      await SessionStorage.setString('baseUrl', url);
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

String humanError(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) return data['message'].toString();
  if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
    return 'تعذر الاتصال بالخادم. تأكد من عنوان الخادم واتصال الإنترنت';
  }
  return 'حدث خطأ غير متوقع (${e.response?.statusCode ?? e.type.name})';
}

final tokensProvider = Provider<AuthTokens?>((ref) => ref.watch(sessionProvider).tokens);

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref);
});
