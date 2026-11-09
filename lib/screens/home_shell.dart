import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../services/notif_provider.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'home_tab.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';
import 'requests_tab.dart';

/// Bottom navigation with 5 clear places:
/// Home (0), Community (1), My Reports (2), Alerts (3), Profile (4).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final NotifProvider _notif;

  @override
  void initState() {
    super.initState();
    _notif = NotifProvider();
    _notif.refresh();
    refreshBus.addListener(_onBus);
  }

  void _onBus() => _notif.refresh();

  @override
  void dispose() {
    refreshBus.removeListener(_onBus);
    _notif.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    refreshBus.value++; // every tab reloads quietly
  }

  @override
  Widget build(BuildContext context) {
    // The "Report a concern" button is only shown where it makes sense.
    final showFab = _index == 1 || _index == 2;

    return ChangeNotifierProvider<NotifProvider>.value(
      value: _notif,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomeTab(onGoto: _go),
            FeedScreen(embedded: true, onGoto: _go),
            RequestsTab(onGoto: _go),
            NotificationsTab(onGoto: _go),
            ProfileTab(onGoto: _go),
          ],
        ),
        floatingActionButton: showFab
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                elevation: 3,
                onPressed: () => openReportFlow(context, _go),
                icon: const Icon(Icons.add_rounded, size: 26),
                label: const Text(
                  'Report a concern',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Community',
            ),
            const NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'My Reports',
            ),
            NavigationDestination(
              icon: _bell(false),
              selectedIcon: _bell(true),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _bell(bool selected) {
    return Consumer<NotifProvider>(
      builder: (_, n, __) => Badge(
        isLabelVisible: n.unread > 0,
        backgroundColor: AppColors.red,
        textColor: Colors.white,
        label: Text(n.unread > 9 ? '9+' : '${n.unread}'),
        child: Icon(selected
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded),
      ),
    );
  }
}
