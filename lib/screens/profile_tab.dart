import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/notif_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/picker.dart';
import 'chatbot_screen.dart';
import 'personal_info_screen.dart';
import 'settings_screen.dart';

class ProfileTab extends StatefulWidget {
  final void Function(int) onGoto;
  const ProfileTab({super.key, required this.onGoto});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Profile? _p;
  List<Complaint> _mine = const [];
  String? _error;
  bool _uploading = false;

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
      final p = await Repo.profile();
      List<Complaint> mine = _mine;
      try {
        final all = await Repo.complaints();
        mine = all.where((c) => c.userId == myId).toList();
      } catch (_) {
        // stats just keep their old values
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _mine = mine;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_p == null) {
        setState(() => _error =
            e is ApiException ? e.message : 'Could not load your profile.');
      }
    }
  }

  Future<void> _changePhoto() async {
    if (_uploading) return;
    final picked = await pickOne(context);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    final r = await Repo.uploadPhoto(picked);
    if (!mounted) return;
    setState(() => _uploading = false);
    showMsg(context, r.message, error: !r.ok);
    if (r.ok) refreshBus.value++;
  }

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabHeader(
          title: 'My Profile',
          trailing: IconButton(
            onPressed: () => _push(const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: _load, child: _body()),
        ),
      ],
    );
  }

  Widget _body() {
    if (_p == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_p == null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final p = _p!;
    final pending = _mine.where((c) => !c.isResolved).length;
    final resolved = _mine.where((c) => c.isResolved).length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        Center(
          child: GestureDetector(
            onTap: _changePhoto,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: AppColors.green, shape: BoxShape.circle),
                  child: Avatar(
                      path: p.profilePicturePath, name: p.fullName, radius: 48),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                        color: AppColors.navy, shape: BoxShape.circle),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(p.fullName,
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
        Text('${p.purokName.isEmpty ? 'Barangay' : p.purokName}, Maguikay',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.muted)),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _stat('${_mine.length}', 'Reports'),
            _stat('$pending', 'Pending'),
            _stat('$resolved', 'Resolved'),
            Consumer<NotifProvider>(
                builder: (_, n, __) => _stat('${n.unread}', 'Unread')),
          ],
        ),
        const SizedBox(height: 22),
        Text('My Information',
            style:
                GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          decoration: cardDecoration(),
          child: Column(
            children: [
              _row(Icons.person_outline, 'Personal Information',
                  () => _push(const PersonalInfoScreen())),
              const Divider(height: 1),
              _row(Icons.description_outlined, 'My Requests',
                  () => widget.onGoto(1)),
              const Divider(height: 1),
              _row(Icons.smart_toy_outlined, 'Help & FAQ Chatbot',
                  () => _push(const ChatbotScreen())),
              const Divider(height: 1),
              _row(Icons.settings_outlined, 'Settings',
                  () => _push(const SettingsScreen())),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10.5, color: AppColors.muted)),
            ],
          ),
        ),
      );

  Widget _row(IconData icon, String label, VoidCallback onTap) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.navy),
        title: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13.5, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      );
}
