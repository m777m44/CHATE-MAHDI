import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'models/models.dart';
import 'core/socket_service.dart';
import 'core/theme.dart';
import 'core/utils.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/dm/chat_screen.dart';
import 'features/dm/inbox_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/feed/feed_providers.dart';
import 'features/feed/home_screen.dart';
import 'features/home_shell.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/posts/create_post_screen.dart';
import 'features/posts/image_viewer_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/saved_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/reels/reels_screen.dart';
import 'features/stories/create_story_screen.dart';
import 'features/stories/story_viewer_screen.dart';
import 'features/update/update_center.dart';
import 'features/update/update_ui.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final v = SessionStorage.getString('themeMode');
    if (v == 'light') state = ThemeMode.light;
    if (v == 'dark') state = ThemeMode.dark;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await SessionStorage.setString('themeMode', mode.name);
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      if (!session.initialized) return '/';
      final authed = session.isAuthed;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (!session.initialized) return '/';
      if (!authed) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      if (state.matchedLocation == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
        routes: [],
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const ExploreScreen(),
      ),
      GoRoute(
        path: '/reels',
        builder: (context, state) => const ReelsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/:username',
        builder: (context, state) => ProfileScreen(username: state.pathParameters['username'] ?? ''),
      ),
      GoRoute(
        path: '/dm',
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: '/dm/:id',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['id'] ?? '',
          title: state.uri.queryParameters['title'] ?? 'محادثة',
        ),
      ),
      GoRoute(
        path: '/media',
        builder: (context, state) {
          final post = state.extra;
          return ImageViewerScreen(post: post is Post ? post : Post(id: '', authorId: '', mediaUrl: '', mediaType: 'IMAGE', createdAt: DateTime.now()));
        },
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/create-story',
        builder: (context, state) => const CreateStoryScreen(),
      ),
      GoRoute(
        path: '/story-viewer',
        builder: (context, state) => StoryViewerScreen(
          initialGroup: int.tryParse(state.uri.queryParameters['group'] ?? '0') ?? 0,
        ),
      ),
      GoRoute(
        path: '/update',
        builder: (context, state) => const UpdateCenterScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedScreen(),
      ),
    ],
  );
});

class ChatemahdiApp extends ConsumerStatefulWidget {
  const ChatemahdiApp({super.key});

  @override
  ConsumerState<ChatemahdiApp> createState() => _ChatemahdiAppState();
}

class _ChatemahdiAppState extends ConsumerState<ChatemahdiApp> {
  @override
  void initState() {
    super.initState();
    initTimeago();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmup();
    });
  }

  Future<void> _warmup() async {
    final session = ref.read(sessionProvider);
    if (session.isAuthed && session.tokens != null) {
      socketManager.connect(ref.read(baseUrlProvider), session.tokens!.accessToken);
      socketManager.notifications.listen((_) {
        ref.read(notificationsUnreadProvider.notifier).bump();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CHATE-MAHDI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.repeat(reverse: true, min: 0.75);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oauthDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: oauthDark
                ? [const Color(0xFF121212), const Color(0xFF000000)]
                : [const Color(0xFFFFFFFF), const Color(0xFFFAFAFA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDD2A7B).withOpacity(0.35),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('CM',
                        style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 18),
                  const Text('CHATE-MAHDI',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 36),
                  const CircularProgressIndicator(strokeWidth: 2.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
