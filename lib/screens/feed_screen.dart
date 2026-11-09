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

/// Community feed = announcements + residents' reports, newest first.
/// [embedded] = true when it is one of the bottom tabs (no back arrow).
class FeedScreen extends StatefulWidget {
  final bool embedded;
  final void Function(int)? onGoto;
  const FeedScreen({super.key, this.embedded = false, this.onGoto});

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
        setState(() => _error =
            e is ApiException ? e.message : 'Could not load the feed.');
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
    final content = Column(
      children: [
        TabHeader(
          title: 'Community',
          subtitle: 'Announcements and reports from your barangay',
          onBack: widget.embedded ? null : () => Navigator.of(context).pop(),
          bottom: TextField(
            onChanged: (v) => setState(() => _q = v),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: appInputDecoration(
              hint: 'Search the community...',
              icon: Icons.search_rounded,
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
          child: RefreshIndicator(onRefresh: _load, child: _body()),
        ),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(backgroundColor: AppColors.bg, body: content);
  }

  Widget _body() {
    if (_items == null && _error == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: const [SkeletonCards(count: 3)],
      );
    }
    if (_items == null) {
      return ListView(children: [
        const SizedBox(height: 40),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final visible = _visible;
    final myName = context.read<AuthProvider>().user?.fullName ?? '';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          onTap: () => openReportFlow(context, widget.onGoto ?? (_) {}),
          child: Row(
            children: [
              Avatar(path: null, name: myName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Report a concern to the barangay...',
                    style: AppText.small),
              ),
              const Icon(Icons.add_a_photo_outlined, color: AppColors.navy),
            ],
          ),
        ),
        if (visible.isEmpty)
          EmptyState(
            icon: _q.trim().isEmpty
                ? Icons.forum_outlined
                : Icons.search_off_rounded,
            title: _q.trim().isEmpty ? 'Nothing here yet' : 'No results',
            message: _q.trim().isEmpty
                ? 'Announcements and reports will show up here.'
                : 'Try a different word.',
          )
        else
          for (final item in visible) FeedCard(item: item),
      ],
    );
  }
}
