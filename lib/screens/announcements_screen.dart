import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/feed_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement>? _items;
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
      final l = await Repo.announcements();
      if (!mounted) return;
      setState(() {
        _items = l;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_items == null) {
        setState(() => _error =
            e is ApiException ? e.message : 'Could not load announcements.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Announcements',
            subtitle: 'From the barangay office',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _body()),
          ),
        ],
      ),
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
    if (_items!.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 60),
        EmptyState(
          icon: Icons.campaign_outlined,
          title: 'No announcements yet',
          message: 'New announcements from the barangay will show up here.',
        ),
      ]);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items!.length,
      itemBuilder: (_, i) =>
          FeedCard(item: FeedItem.fromAnnouncement(_items![i])),
    );
  }
}
