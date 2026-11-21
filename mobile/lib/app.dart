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
      socketManager.notifications.stream.listen((_) {
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

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), AppTheme.igBlue]),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text('CM', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
