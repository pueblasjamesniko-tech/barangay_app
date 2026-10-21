import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/picker.dart';

/// "Report Concern" / create post. The API stores text + photos (no category/location).
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxPhotos = 5;
  final _text = TextEditingController();
  final List<Picked> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

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

  Future<void> _post() async {
    if (_text.text.trim().isEmpty && _photos.isEmpty) {
      showMsg(context, 'Write something or add at least one photo.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await Repo.createComplaint(_text.text, _photos);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      showMsg(context, r.message, error: true);
      return;
    }
    showMsg(context, r.message);
    refreshBus.value++;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthProvider>().user?.fullName ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Report Concern',
            subtitle: 'Your post goes to the barangay as Pending',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(path: null, name: name, radius: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 4,
                            maxLines: 8,
                            maxLength: 1000,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  'Describe your concern or share an update...',
                              hintStyle: GoogleFonts.poppins(
                                  fontSize: 13.5, color: AppColors.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Add Photos',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('JPG or PNG, max 5 MB each, up to $_maxPhotos photos',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < _photos.length; i++) _thumb(i),
                      if (_photos.length < _maxPhotos) _addBox(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(label: 'Post', loading: _busy, onPressed: _post),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addBox() => GestureDetector(
        onTap: _addPhotos,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.4),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, color: AppColors.navy, size: 28),
              SizedBox(height: 4),
              Text('Add', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      );

  Widget _thumb(int i) => SizedBox(
        width: 96,
        height: 96,
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
              child: GestureDetector(
                onTap: () => setState(() => _photos.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Color(0xB3000000), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      );
}
