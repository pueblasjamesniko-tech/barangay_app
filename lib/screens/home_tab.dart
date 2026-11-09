import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/notif_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/feed_card.dart';
import 'announcements_screen.dart';
import 'chatbot_screen.dart';
import 'create_post_screen.dart';
import 'requests_tab.dart';

class HomeTab extends StatefulWidget {
  /// Switches the bottom tab: 0 Home, 1 Community, 2 My Reports, 3 Alerts, 4 Profile.
  final void Function(int) onGoto;
  const HomeTab({super.key, required this.onGoto});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Profile? _profile;
  List<Announcement>? _ann;
  List<Complaint> _mine = const [];
  String? _error;

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
    final myId = context.read<AuthProvider>().user?.userId;
    try {
      final ann = await Repo.announcements();
      final p = await Repo.profile();
      var mine = _mine;
      try {
        final all = await Repo.complaints();
        mine = all.where((c) => c.userId == myId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        // the "latest report" card just keeps what it had
      }
      if (!mounted) return;
      setState(() {
        _ann = ann;
        _profile = p;
        _mine = mine;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_ann == null) {
        setState(() => _error =
            e is ApiException ? e.message : 'Could not load the home screen.');
      }
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _report() => openReportFlow(context, widget.onGoto);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = _profile?.fullName ?? auth.user?.fullName ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _hero(name),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _error != null && _ann == null
                  ? [
                      const SizedBox(height: 24),
                      ErrorState(message: _error!, onRetry: _load),
                    ]
                  : _sections(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- top part ----------------

  Widget _hero(String name) {
    final top = MediaQuery.of(context).padding.top;
    final trimmed = name.trim();
    final first = trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => widget.onGoto(4),
                child: Avatar(
                    path: _profile?.profilePicturePath, name: name, radius: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_greeting,',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.white70)),
                    Text(
                      first.isEmpty ? 'Welcome' : first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2),
                    ),
                  ],
                ),
              ),
              Consumer<NotifProvider>(
                builder: (_, n, __) => IconButton(
                  tooltip: 'Alerts',
                  onPressed: () => widget.onGoto(3),
                  icon: Badge(
                    isLabelVisible: n.unread > 0,
                    backgroundColor: AppColors.red,
                    textColor: Colors.white,
                    label: Text(n.unread > 9 ? '9+' : '${n.unread}'),
                    child: const Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                          color: AppColors.softGold, shape: BoxShape.circle),
                      child: const Icon(Icons.campaign_rounded,
                          color: AppColors.goldDark, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Have a concern?', style: AppText.heading),
                          Text(
                              'Tell the barangay what is happening in your area.',
                              style: AppText.small),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Report a concern',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _report,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- sections below ----------------

  List<Widget> _sections() {
    return [
      if (_mine.isNotEmpty) ...[
        SectionTitle('Your latest report',
            actionLabel: 'See all', onAction: () => widget.onGoto(2)),
        RequestTile(complaint: _mine.first),
      ],
      const SectionTitle('What do you need?'),
      Row(
        children: [
          Expanded(
            child: _QuickTile(
              icon: Icons.assignment_outlined,
              title: 'My Reports',
              subtitle: 'Follow your reports',
              onTap: () => widget.onGoto(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickTile(
              icon: Icons.forum_outlined,
              title: 'Community',
              subtitle: 'See what is happening',
              onTap: () => widget.onGoto(1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _QuickTile(
              icon: Icons.campaign_outlined,
              title: 'Announcements',
              subtitle: 'From the barangay',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AnnouncementsScreen())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & FAQ',
              subtitle: 'Quick answers',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatbotScreen())),
            ),
          ),
        ],
      ),
      SectionTitle('Latest announcement',
          actionLabel: 'See all',
          onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen()))),
      _latestAnnouncement(),
      const SectionTitle('Barangay office'),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _info(Icons.phone_outlined, 'Phone', AppConfig.contactNumber,
                copy: true),
            const Divider(height: 22),
            _info(Icons.mail_outline, 'Email', AppConfig.contactEmail,
                copy: true),
            const Divider(height: 22),
            _info(Icons.access_time, 'Office hours', AppConfig.officeHours),
          ],
        ),
      ),
    ];
  }

  Widget _latestAnnouncement() {
    if (_ann == null) return const SkeletonCards(count: 1);
    if (_ann!.isEmpty) {
      return AppCard(
        child: Text('No announcements yet.', style: AppText.small),
      );
    }
    return FeedCard(item: FeedItem.fromAnnouncement(_ann!.first));
  }

  Widget _info(IconData icon, String label, String value, {bool copy = false}) {
    final row = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
              color: AppColors.navySoft, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.navy, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (copy)
          const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
      ],
    );
    if (!copy) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) showMsg(context, '$label copied');
      },
      child: row,
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.navySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.navy, size: 23),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
