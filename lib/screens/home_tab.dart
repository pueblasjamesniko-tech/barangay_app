import 'package:flutter/material.dart';
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
import 'create_post_screen.dart';
import 'feed_screen.dart';

class HomeTab extends StatefulWidget {
  final void Function(int) onGoto;
  const HomeTab({super.key, required this.onGoto});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Profile? _profile;
  List<Announcement>? _ann;
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
    try {
      final ann = await Repo.announcements();
      final p = await Repo.profile();
      if (!mounted) return;
      setState(() {
        _ann = ann;
        _profile = p;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_ann == null) {
        setState(() =>
            _error = e is ApiException ? e.message : 'Could not load the home screen.');
      }
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = _profile?.fullName ?? auth.user?.fullName ?? '';

    return Column(
      children: [
        TabHeader(
          title: AppConfig.barangayName,
          subtitle: 'Barangay Portal',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<NotifProvider>(
                builder: (_, n, __) => Stack(
                  children: [
                    IconButton(
                      onPressed: () => widget.onGoto(2),
                      icon: const Icon(Icons.notifications_none_rounded,
                          color: Colors.white),
                    ),
                    if (n.unread > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                              color: AppColors.red, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => widget.onGoto(3),
                child: Avatar(
                    path: _profile?.profilePicturePath, name: name, radius: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _greetingCard(name),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Action(
                        icon: Icons.campaign_outlined,
                        label: 'Report\nConcern',
                        bg: AppColors.navy,
                        fg: Colors.white,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CreatePostScreen())),
                      ),
                    ),
                    Expanded(
                      child: _Action(
                        icon: Icons.description_outlined,
                        label: 'Track\nRequest',
                        bg: AppColors.gold,
                        fg: AppColors.navy,
                        onTap: () => widget.onGoto(1),
                      ),
                    ),
                    Expanded(
                      child: _Action(
                        icon: Icons.forum_outlined,
                        label: 'Community\nFeed',
                        bg: AppColors.softBlue,
                        fg: AppColors.navy,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FeedScreen())),
                      ),
                    ),
                    Expanded(
                      child: _Action(
                        icon: Icons.notifications_active_outlined,
                        label: 'View\nAnnouncements',
                        bg: AppColors.softBlue,
                        fg: AppColors.navy,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AnnouncementsScreen())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Quick Info',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    children: [
                      _info(Icons.phone_outlined, 'Barangay Contact',
                          AppConfig.contactNumber),
                      const Divider(height: 22),
                      _info(Icons.mail_outline, 'Email Address',
                          AppConfig.contactEmail),
                      const Divider(height: 22),
                      _info(Icons.access_time, 'Office Hours',
                          AppConfig.officeHours),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('Recent Updates',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FeedScreen())),
                      child: Text('View all ›',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                _recent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _recent() {
    if (_ann == null && _error == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ann == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_ann!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('No announcements yet.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.muted)),
      );
    }
    return Column(
      children: [
        for (final a in _ann!.take(2)) FeedCard(item: FeedItem.fromAnnouncement(a)),
      ],
    );
  }

  Widget _greetingCard(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Barangay ${AppConfig.barangayName}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.green),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 13, color: AppColors.green),
                      const SizedBox(width: 4),
                      Text('Verified',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 96,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.softBlue, AppColors.softGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.location_city,
                size: 40, color: AppColors.navy),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.navy, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, fontWeight: FontWeight.w600)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
