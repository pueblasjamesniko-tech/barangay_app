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

/// "My Reports": everything this resident has sent, with its status.
/// The API returns all complaints, so we keep only the ones that belong to this user.
class RequestsTab extends StatefulWidget {
  final void Function(int)? onGoto;
  const RequestsTab({super.key, this.onGoto});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<Complaint>? _mine;
  String? _error;
  int _filter = 0; // 0 All, 1 Pending, 2 In progress, 3 Resolved

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
            e is ApiException ? e.message : 'Could not load your reports.');
      }
    }
  }

  int _count(ReportStage s) => (_mine ?? const <Complaint>[])
      .where((c) => stageOf(c.status) == s)
      .length;

  List<Complaint> get _visible {
    final l = _mine ?? const <Complaint>[];
    switch (_filter) {
      case 1:
        return l
            .where((c) => stageOf(c.status) == ReportStage.pending)
            .toList();
      case 2:
        return l
            .where((c) => stageOf(c.status) == ReportStage.inProgress)
            .toList();
      case 3:
        return l
            .where((c) => stageOf(c.status) == ReportStage.resolved)
            .toList();
      default:
        return l;
    }
  }

  void _openNew() => openReportFlow(context, widget.onGoto ?? (_) {});

  @override
  Widget build(BuildContext context) {
    final total = _mine?.length ?? 0;
    return Column(
      children: [
        const TabHeader(
          title: 'My Reports',
          subtitle: 'Follow the progress of your reports',
        ),
        const SizedBox(height: 12),
        FilterChips(
          labels: [
            'All ($total)',
            'Pending (${_count(ReportStage.pending)})',
            'In progress (${_count(ReportStage.inProgress)})',
            'Resolved (${_count(ReportStage.resolved)})',
          ],
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: const [SkeletonCards(count: 3)],
      );
    }
    if (_mine == null) {
      return ListView(children: [
        const SizedBox(height: 40),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final items = _visible;
    if (items.isEmpty) {
      final none = (_mine ?? const <Complaint>[]).isEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 24),
          EmptyState(
            icon: Icons.assignment_outlined,
            title: none ? 'No reports yet' : 'Nothing in this list',
            message: none
                ? 'When you report a concern, you can follow its progress here.'
                : 'Try another filter above.',
            action: none
                ? PrimaryButton(
                    label: 'Report a concern',
                    icon: Icons.add_rounded,
                    onPressed: _openNew)
                : null,
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => RequestTile(complaint: items[i]),
    );
  }
}

Color _stripColor(ReportStage s) {
  switch (s) {
    case ReportStage.resolved:
      return AppColors.green;
    case ReportStage.inProgress:
      return AppColors.navy;
    case ReportStage.pending:
      return AppColors.gold;
  }
}

class RequestTile extends StatelessWidget {
  final Complaint complaint;
  const RequestTile({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RequestDetailScreen(complaint: c))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: _stripColor(stageOf(c.status))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Report ${requestRef(c.id)}',
                              style: AppText.label),
                        ),
                        StatusChip(c.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.text.trim().isEmpty ? '(Photo only)' : c.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 15, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(timeAgo(c.createdAt), style: AppText.caption),
                        if (c.photos.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          const Icon(Icons.image_outlined,
                              size: 15, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text('${c.photos.length}', style: AppText.caption),
                        ],
                        const Spacer(),
                        Text('View',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy)),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.navy),
                      ],
                    ),
                  ],
                ),
              ),
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
            title: 'Report ${requestRef(c.id)}',
            subtitle:
                'Sent ${DateFormat('MMM d, y - h:mm a').format(c.createdAt)}',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('Progress', style: AppText.heading)),
                          StatusChip(c.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Tracker(stage: stageOf(c.status)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your report', style: AppText.heading),
                      const SizedBox(height: 8),
                      Text(
                        c.text.trim().isEmpty ? '(No description)' : c.text,
                        style: AppText.body,
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
                  'We will send you an alert when the barangay updates this report.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three steps: Received -> In progress -> Resolved.
class _Tracker extends StatelessWidget {
  final ReportStage stage;
  const _Tracker({required this.stage});

  @override
  Widget build(BuildContext context) {
    const titles = ['Report received', 'In progress', 'Resolved'];
    const notes = [
      'The barangay has your report.',
      'The barangay is working on it.',
      'Your concern has been addressed.',
    ];
    final current = stage.index; // 0 pending, 1 in progress, 2 resolved
    final allDone = stage == ReportStage.resolved;

    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _dot(
                      done: i < current || allDone,
                      active: i == current && !allDone),
                  if (i < 2)
                    Container(
                      width: 2,
                      height: 30,
                      color: (i < current || allDone)
                          ? AppColors.green
                          : AppColors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < 2 ? 14 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[i],
                        style: AppText.label.copyWith(
                          color: (i <= current || allDone)
                              ? AppColors.text
                              : AppColors.muted,
                        ),
                      ),
                      Text(notes[i], style: AppText.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _dot({required bool done, required bool active}) {
    if (done) {
      return Container(
        width: 26,
        height: 26,
        decoration:
            const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: active ? AppColors.softGold : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: active ? AppColors.gold : AppColors.border, width: 2),
      ),
      child: active
          ? const Icon(Icons.more_horiz, size: 16, color: AppColors.goldDark)
          : null,
    );
  }
}
