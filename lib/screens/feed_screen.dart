import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/feed_card.dart';
import 'create_post_screen.dart';

/// Community feed = announcements + residents' posts, newest first.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<FeedItem>? _items;
  String? _error;
  int _filter = 0; // 0 All, 1 Announcements, 2 Reports
  String _q = '';

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
      final anns = await Repo.announcements();
      final cs = await Repo.complaints();
      final list = <FeedItem>[
        ...anns.map(FeedItem.fromAnnouncement),
        ...cs.map(FeedItem.fromComplaint),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_items == null) {
        setState(() =>
            _error = e is ApiException ? e.message : 'Could not load the feed.');
      }
    }
  }

  List<FeedItem> get _visible {
    Iterable<FeedItem> l = _items ?? const <FeedItem>[];
    if (_filter == 1) l = l.where((i) => i.isAnnouncement);
    if (_filter == 2) l = l.where((i) => !i.isAnnouncement);
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      l = l.where((i) =>
          i.body.toLowerCase().contains(q) ||
          i.authorName.toLowerCase().contains(q));
    }
    return l.toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Community',
            subtitle: 'Announcements and reports from your barangay',
            onBack: () => Navigator.of(context).pop(),
            bottom: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: GoogleFonts.poppins(fontSize: 13.5),
              decoration: appInputDecoration(
                hint: 'Search posts, announcements...',
                icon: Icons.search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilterChips(
            labels: const ['All', 'Announcements', 'Reports'],
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(user?.fullName ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(String myName) {
    if (_items == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items == null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final visible = _visible;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreatePostScreen())),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: cardDecoration(),
            child: Row(
              children: [
                Avatar(path: null, name: myName, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("What's on your mind?",
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.muted)),
                ),
                const Icon(Icons.image_outlined, color: AppColors.navy),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          const EmptyState(
            icon: Icons.forum_outlined,
            title: 'Nothing here yet',
            message: 'Posts and announcements will show up here.',
          )
        else
          for (final item in visible) FeedCard(item: item),
      ],
    );
  }
}
