import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/notif_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import 'requests_tab.dart';

/// Alerts from the API (status changes on the resident's own reports).
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
        setState(() => _error =
            e is ApiException ? e.message : 'Could not load your alerts.');
      }
    }
  }

  int get _unread =>
      (_items ?? const <AppNotification>[]).where((n) => !n.isRead).length;

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
      notif.setUnread(_unread);
      Repo.markRead(n.id); // best effort
    }
    try {
      final all = await Repo.complaints();
      if (!mounted) return;
      final match = all.where((c) => c.id == n.complaintId);
      if (match.isEmpty) {
        showMsg(context, 'That report is no longer available.', error: true);
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RequestDetailScreen(complaint: match.first)));
    } catch (_) {
      if (!mounted) return;
      widget.onGoto(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabHeader(
          title: 'Alerts',
          subtitle: _unread > 0 ? '$_unread unread' : 'You are all caught up',
          trailing: TextButton.icon(
            onPressed: _unread > 0 ? _markAll : null,
            icon: const Icon(Icons.done_all_rounded, size: 20),
            label: const Text('Mark all read'),
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

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Widget _body() {
    if (_items == null && _error == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: const [SkeletonCards(count: 4)],
      );
    }
    if (_items == null) {
      return ListView(children: [
        const SizedBox(height: 40),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final all = _items!;
    final shown = _filter == 1 ? all.where((n) => !n.isRead).toList() : all;
    if (shown.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 24),
        EmptyState(
          icon: Icons.notifications_none_rounded,
          title: _filter == 1 ? 'No unread alerts' : 'No alerts yet',
          message:
              'We will tell you here when the barangay updates your reports.',
        ),
      ]);
    }
    final today = shown.where((n) => _isToday(n.createdAt)).toList();
    final earlier = shown.where((n) => !_isToday(n.createdAt)).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (today.isNotEmpty) ...[
          _heading('Today'),
          for (final n in today) _tile(n),
        ],
        if (earlier.isNotEmpty) ...[
          _heading('Earlier'),
          for (final n in earlier) _tile(n),
        ],
      ],
    );
  }

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(t, style: AppText.label.copyWith(color: AppColors.muted)),
      );

  (IconData, Color, Color) _look(String message) {
    final m = message.toLowerCase();
    if (m.contains('resolved') ||
        m.contains('approved') ||
        m.contains('done')) {
      return (
        Icons.check_circle_outline_rounded,
        AppColors.green,
        AppColors.softGreen
      );
    }
    if (m.contains('progress') || m.contains('updated')) {
      return (Icons.autorenew_rounded, AppColors.navy, AppColors.softBlue);
    }
    return (
      Icons.notifications_none_rounded,
      AppColors.goldDark,
      AppColors.softGold
    );
  }

  Widget _tile(AppNotification n) {
    final (icon, fg, bg) = _look(n.message);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: n.isRead ? Colors.white : AppColors.navySoft,
      onTap: () => _open(n),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 24),
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
                  style: AppText.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Report ${requestRef(n.complaintId)} - ${timeAgo(n.createdAt)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                  color: AppColors.red, shape: BoxShape.circle),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}
