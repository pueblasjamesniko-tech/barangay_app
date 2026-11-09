import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/picker.dart';

/// Opens the report screen. If the resident taps "View my reports" afterwards,
/// jump to the My Reports tab (index 2).
Future<void> openReportFlow(
    BuildContext context, void Function(int) onGoto) async {
  final goToReports = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
  );
  if (goToReports == true) onGoto(2);
}

/// "Report a concern": one short form, then a clear "sent" confirmation.
/// The API stores the text and photos, so the topic and location are written
/// into the text (as a #hashtag and a "Location:" line) where the barangay can read them.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxPhotos = 5;
  static const List<String> _topics = [
    'Garbage',
    'Road',
    'Water',
    'Electricity',
    'Noise',
    'Safety',
    'Other',
  ];

  final _text = TextEditingController();
  final _where = TextEditingController();
  final List<Picked> _photos = [];
  String? _topic;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _where.dispose();
    super.dispose();
  }

  bool get _canSend => _text.text.trim().isNotEmpty || _photos.isNotEmpty;

  Future<void> _addPhotos() async {
    if (_photos.length >= _maxPhotos) {
      showMsg(context, 'You can add up to $_maxPhotos photos.', error: true);
      return;
    }
    final picked = await pickMany(context);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final p in picked) {
        if (_photos.length < _maxPhotos) _photos.add(p);
      }
    });
  }

  String _compose() {
    final b = StringBuffer(_text.text.trim());
    final loc = _where.text.trim();
    if (loc.isNotEmpty) {
      if (b.isNotEmpty) b.write('\n\n');
      b.write('Location: $loc');
    }
    if (_topic != null && _topic != 'Other') {
      if (b.isNotEmpty) b.write('\n\n');
      b.write('#$_topic');
    }
    return b.toString();
  }

  Future<void> _send() async {
    if (!_canSend) {
      showMsg(context, 'Write what happened or add a photo first.',
          error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await Repo.createComplaint(_compose(), _photos);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = r.message;
      });
      return;
    }
    refreshBus.value++;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _success();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Report a concern',
            subtitle: 'Tell the barangay what is happening',
            onBack: () => Navigator.of(context).pop(false),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    InfoBanner(_error!, kind: BannerKind.error),
                    const SizedBox(height: 14),
                  ],
                  Text('1. What is the problem?', style: AppText.heading),
                  const SizedBox(height: 4),
                  Text(
                    'Example: Garbage has not been collected on our street since Monday.',
                    style: AppText.small,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _text,
                    minLines: 5,
                    maxLines: 9,
                    maxLength: 900,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: appInputDecoration(
                        hint: 'Write what happened, where and when...'),
                  ),
                  const SizedBox(height: 14),
                  Text('2. What is it about? (optional)',
                      style: AppText.heading),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _topics)
                        ChoiceChip(
                          label: Text(t),
                          selected: _topic == t,
                          showCheckmark: false,
                          selectedColor: AppColors.navy,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: _topic == t
                                  ? AppColors.navy
                                  : AppColors.border),
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _topic == t ? Colors.white : AppColors.text,
                          ),
                          onSelected: (sel) =>
                              setState(() => _topic = sel ? t : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('3. Where is it? (optional)', style: AppText.heading),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _where,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: appInputDecoration(
                      hint: 'Purok, street or landmark',
                      icon: Icons.place_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text('4. Add photos (optional)',
                            style: AppText.heading),
                      ),
                      Text('${_photos.length} of $_maxPhotos',
                          style: AppText.caption),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photos help the barangay understand the problem faster. JPG or PNG, up to 5 MB each.',
                    style: AppText.small,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < _photos.length; i++) _thumb(i),
                      if (_photos.length < _maxPhotos) _addBox(),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const InfoBanner(
                    'Your report is also shown in the Community feed, so your '
                    'neighbors can see it. Please do not write phone numbers or '
                    'other private details.',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: 'Send report',
                icon: Icons.send_rounded,
                loading: _busy,
                onPressed: _canSend ? _send : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                    color: AppColors.softGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 60, color: AppColors.green),
              ),
              const SizedBox(height: 22),
              Text('Report sent!',
                  textAlign: TextAlign.center, style: AppText.title),
              const SizedBox(height: 8),
              Text(
                'The barangay has received your report. Its status is now '
                '"Pending". We will send you an alert when it is updated.',
                textAlign: TextAlign.center,
                style: AppText.small,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'View my reports',
                icon: Icons.assignment_rounded,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Back to home',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addBox() => InkWell(
        onTap: _addPhotos,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.navy, width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.navy, size: 28),
              const SizedBox(height: 4),
              Text('Add photo',
                  style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy)),
            ],
          ),
        ),
      );

  Widget _thumb(int i) => SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(_photos[i].bytes,
                  fit: BoxFit.cover, gaplessPlayback: true),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: InkWell(
                onTap: () => setState(() => _photos.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Color(0xCC000000), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
}
