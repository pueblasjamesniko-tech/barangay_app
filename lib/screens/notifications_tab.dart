import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/notif_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import 'requests_tab.dart';

/// Notifications from the API (status changes on the resident's own requests).
class NotificationsTab extends StatefulWidget {
  final void Function(int) onGoto;
  const NotificationsTab({super.key, required this.onGoto});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<AppNotification>? _items;
  String? _error;
  int _filter = 0; // 0 All, 1 Unread

  @override
  void initState() {
    super.initState();
    _load();
    refreshBus.addListener(_load);
  }

  @override
  void dispose() {
    refreshBus.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final notif = context.read<NotifProvider>();
    try {
      final l = await Repo.notifications();
      if (!mounted) return;
      setState(() {
        _items = l;
        _error = null;
      });
      notif.setUnread(l.where((n) => !n.isRead).length);
    } catch (e) {
      if (!mounted) return;
      if (_items == null) {
        setState(() => _error = e is ApiException
            ? e.message
            : 'Could not load your notifications.');
      }
    }
  }

  List<AppNotification> get _visible {
    final l = _items ?? const <AppNotification>[];
    return _filter == 1 ? l.where((n) => !n.isRead).toList() : l;
  }

  Future<void> _markAll() async {
    final items = _items;
    if (items == null || items.every((n) => n.isRead)) return;
    final notif = context.read<NotifProvider>();
    final r = await Repo.markAllRead();
    if (!mounted) return;
    if (!r.ok) {
      showMsg(context, r.message, error: true);
      return;
    }
    setState(() {
      for (final n in items) {
        n.isRead = true;
      }
    });
    notif.setUnread(0);
  }

  Future<void> _open(AppNotification n) async {
    final notif = context.read<NotifProvider>();
    if (!n.isRead) {
      setState(() => n.isRead = true);
      notif.setUnread((_items ?? []).where((x) => !x.isRead).length);
      Repo.markRead(n.id); // best effort
    }
    try {
      final all = await Repo.complaints();
      if (!mounted) return;
      final match = all.where((c) => c.id == n.complaintId);
      if (match.isEmpty) {
        showMsg(context, 'That request is no longer available.', error: true);
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RequestDetailScreen(complaint: match.first)));
    } catch (e) {
      if (!mounted) return;
      widget.onGoto(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabHeader(
          title: 'Notifications',
          subtitle: 'Updates on your requests',
          trailing: IconButton(
            tooltip: 'Mark all as read',
            onPressed: _markAll,
            icon: const Icon(Icons.done_all, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        FilterChips(
          labels: const ['All', 'Unread'],
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(onRefresh: _load, child: _body()),
        ),
      ],
    );
  }

  Widget _body() {
    if (_items == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items == null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final items = _visible;
    if (items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 40),
        EmptyState(
          icon: Icons.notifications_none_rounded,
          title: _filter == 1 ? 'No unread notifications' : 'No notifications yet',
          message: 'You will be notified when the barangay updates your requests.',
        ),
      ]);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: items.length,
      itemBuilder: (_, i) => _tile(items[i]),
    );
  }

  (IconData, Color, Color) _look(String message) {
    final m = message.toLowerCase();
    if (m.contains('resolved') || m.contains('approved') || m.contains('done')) {
      return (Icons.check_circle_outline, AppColors.green, AppColors.softGreen);
    }
    if (m.contains('progress') || m.contains('updated')) {
      return (Icons.campaign_outlined, AppColors.navy, AppColors.softBlue);
    }
    return (Icons.notifications_none_rounded, const Color(0xFFB36B00),
        AppColors.softGold);
  }

  Widget _tile(AppNotification n) {
    final (icon, fg, bg) = _look(n.message);
    return GestureDetector(
      onTap: () => _open(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(14).copyWith(
          border: n.isRead
              ? null
              : Border.all(color: AppColors.gold.withOpacity(0.7), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${requestRef(n.complaintId)} - ${timeAgo(n.createdAt)}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
