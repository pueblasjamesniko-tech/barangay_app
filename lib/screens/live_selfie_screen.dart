import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/picker.dart' show maxImageBytes;

/// Opens the real front camera (phone OR Chrome webcam), shows a live preview,
/// and returns a [Picked] photo. There is NO gallery option on purpose,
/// so the barangay knows the face photo was taken right now.
///
/// Usage:
///   final p = await Navigator.of(context).push<Picked>(
///     MaterialPageRoute(builder: (_) => const LiveSelfieScreen(),
///         fullscreenDialog: true));
class LiveSelfieScreen extends StatefulWidget {
  const LiveSelfieScreen({super.key});

  @override
  State<LiveSelfieScreen> createState() => _LiveSelfieScreenState();
}

class _LiveSelfieScreenState extends State<LiveSelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _cam;
  String? _error;
  bool _starting = true;
  bool _capturing = false;
  Picked? _shot; // the photo that was just taken (waiting for confirm)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  // Phone: release the camera when the app goes to background, reopen after.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _cam = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _shot == null) {
      _start();
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw CameraException(
            'NoCamera', 'No camera was found on this device.');
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await _cam?.dispose();
      setState(() {
        _cam = c;
        _starting = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = _friendly(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'Could not open the camera: $e';
      });
    }
  }

  String _friendly(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
      case 'NotAllowedError':
        return 'Camera permission was blocked.\n'
            'Allow the camera for this app/site, then tap Try again.';
      case 'NoCamera':
      case 'NotFoundError':
        return 'No camera was found on this device.';
      case 'NotReadableError':
        return 'The camera is being used by another app. Close it and try again.';
      default:
        return e.description ?? 'Could not open the camera (${e.code}).';
    }
  }

  Future<void> _capture() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final x = await c.takePicture();
      final bytes = await x.readAsBytes();
      if (bytes.length > maxImageBytes) {
        if (mounted) {
          showMsg(context, 'The photo is larger than 5 MB. Please try again.',
              error: true);
        }
        return;
      }
      // The API decides the file type from the extension, so name it correctly.
      final isPng = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
      final name =
          'selfie_${DateTime.now().millisecondsSinceEpoch}.${isPng ? 'png' : 'jpg'}';
      if (!mounted) return;
      setState(() => _shot = Picked(bytes, name));
    } on CameraException catch (e) {
      if (mounted) showMsg(context, _friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Live selfie',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_starting) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null) return _errorView();
    if (_shot != null) return _reviewView();
    return _cameraView();
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 56),
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Try again', onPressed: _start),
            ],
          ),
        ),
      );

  Widget _cameraView() {
    final c = _cam;
    if (c == null || !c.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(child: CameraPreview(c)), // the LIVE camera feed
              // Face guide (just a frame, does not affect the photo)
              IgnorePointer(
                child: Container(
                  width: 230,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gold, width: 3),
                    borderRadius:
                        const BorderRadius.all(Radius.elliptical(115, 150)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            'Put your face inside the frame, good lighting, no mask or cap.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 6),
          child: GestureDetector(
            onTap: _capture,
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.gold),
                child: _capturing
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: AppColors.navy))
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewView() => Column(
        children: [
          Expanded(
            child: Center(
              child: Image.memory(_shot!.bytes, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => setState(() => _shot = null),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Use photo',
                    icon: Icons.check,
                    onPressed: () => Navigator.of(context).pop(_shot),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
