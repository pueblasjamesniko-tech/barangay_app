import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

String requestRef(int id) => '#${id.toString().padLeft(5, '0')}';

/// "Requests" tab: everything the logged-in resident has submitted, with its status.
/// The API returns all complaints, so we keep only the ones that belong to this user.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<Complaint>? _mine;
  String? _error;
  int _filter = 0; // 0 All, 1 Pending, 2 Resolved

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
      final all = await Repo.complaints();
      final mine = all.where((c) => c.userId == myId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_mine == null) {
        setState(() => _error =
            e is ApiException ? e.message : 'Could not load your requests.');
      }
    }
  }

  List<Complaint> get _visible {
    final l = _mine ?? const <Complaint>[];
    if (_filter == 1) return l.where((c) => !c.isResolved).toList();
    if (_filter == 2) return l.where((c) => c.isResolved).toList();
    return l;
  }

  void _openNew() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TabHeader(
          title: 'My Requests',
          subtitle: 'Track the status of your reports',
        ),
        const SizedBox(height: 12),
        FilterChips(
          labels: const ['All', 'Pending', 'Resolved'],
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
    if (_mine == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mine == null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final items = _visible;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.description_outlined,
            title: _filter == 0 ? 'No requests yet' : 'Nothing in this list',
            message: _filter == 0
                ? 'When you report a concern, you can follow its status here.'
                : 'Try another filter.',
          ),
          if (_filter == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: PrimaryButton(label: 'Report a concern', onPressed: _openNew),
            ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: items.length,
      itemBuilder: (_, i) => RequestTile(complaint: items[i]),
    );
  }
}

class RequestTile extends StatelessWidget {
  final Complaint complaint;
  const RequestTile({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RequestDetailScreen(complaint: c))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Request ${requestRef(c.id)}',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                StatusChip(c.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.text.trim().isEmpty ? '(Photo only)' : c.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(timeAgo(c.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.muted)),
                if (c.photos.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.image_outlined,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text('${c.photos.length}',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RequestDetailScreen extends StatelessWidget {
  final Complaint complaint;
  const RequestDetailScreen({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Request ${requestRef(c.id)}',
            subtitle: 'Submitted ${DateFormat('MMM d, y - h:mm a').format(c.createdAt)}',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Status',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: AppColors.muted)),
                          const Spacer(),
                          StatusChip(c.status),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Details',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(
                        c.text.trim().isEmpty ? '(No description)' : c.text,
                        style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                      ),
                      if (c.photos.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        PhotoGrid(photos: c.photos),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You will get a notification when the barangay updates this request.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
