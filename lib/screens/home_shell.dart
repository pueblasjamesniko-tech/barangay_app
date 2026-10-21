import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../services/notif_provider.dart';
import 'create_post_screen.dart';
import 'home_tab.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';
import 'requests_tab.dart';

/// Bottom navigation: Home, Requests, [+], Notifications, Profile
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
    return ChangeNotifierProvider<NotifProvider>.value(
      value: _notif,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomeTab(onGoto: _go),
            const RequestsTab(),
            NotificationsTab(onGoto: _go),
            ProfileTab(onGoto: _go),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          shape: const CircleBorder(),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          ),
          child: const Icon(Icons.add, size: 30),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 64,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              _item(0, Icons.home_rounded, 'Home'),
              _item(1, Icons.description_outlined, 'Requests'),
              const SizedBox(width: 64),
              _item(2, Icons.notifications_none_rounded, 'Notifications',
                  withDot: true),
              _item(3, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label, {bool withDot = false}) {
    final selected = _index == i;
    final color = selected ? AppColors.navy : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: () => _go(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (withDot)
                  Consumer<NotifProvider>(
                    builder: (_, n, __) => n.unread > 0
                        ? Positioned(
                            right: -2,
                            top: -1,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                  color: AppColors.red, shape: BoxShape.circle),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
