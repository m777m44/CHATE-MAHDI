import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/socket_service.dart';
import 'feed/feed_providers.dart';
import 'feed/home_screen.dart';
import 'update/update_ui.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionProvider);
      if (session.isAuthed && session.tokens != null) {
        socketManager.connect(ref.read(baseUrlProvider), session.tokens!.accessToken);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(notificationsUnreadProvider);
    final myUsername = ref.watch(sessionProvider).user?.username ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHATE-MAHDI'),
        actions: [
          IconButton(
            tooltip: 'الرسائل',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/dm'),
          ),
        ],
      ),
      body: Stack(
        children: const [
          HomeScreen(),
          UpdateDialogOnce(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              setState(() => _index = 0);
              break;
            case 1:
              context.push('/explore');
              setState(() => _index = 0);
              break;
            case 2:
              context.push('/reels');
              setState(() => _index = 0);
              break;
            case 3:
              context.push('/notifications');
              setState(() => _index = 0);
              break;
            case 4:
              context.push('/profile/$myUsername');
              break;
          }
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'استكشاف'),
          const NavigationDestination(icon: Icon(Icons.smart_display_outlined), selectedIcon: Icon(Icons.smart_display), label: 'ريلز'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.favorite_outline),
            ),
            selectedIcon: const Icon(Icons.favorite),
            label: 'إشعارات',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
