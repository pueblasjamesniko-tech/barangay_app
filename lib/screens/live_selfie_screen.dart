import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/picker.dart' show maxImageBytes;

/// LIVE selfie with liveness check.
///
/// PHONE (Android / iPhone): the camera scans the face in real time. The
/// resident must do random challenges (always a BLINK, plus smile or head turn),
/// then look straight. Only then the photo is taken automatically.
///
/// CHROME (testing only): Google ML Kit does not run on the web, so Chrome
/// shows the plain camera with a capture button (no blink check).
///
///   final p = await Navigator.of(context).push<Picked>(
///     MaterialPageRoute(builder: (_) => const LiveSelfieScreen(),
///         fullscreenDialog: true));
class LiveSelfieScreen extends StatefulWidget {
  const LiveSelfieScreen({super.key});

  @override
  State<LiveSelfieScreen> createState() => _LiveSelfieScreenState();
}

enum _Challenge { blink, smile, turn }

const _stepSeconds = 15; // time allowed per challenge
const _rotations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

class _LiveSelfieScreenState extends State<LiveSelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _cam;
  CameraDescription? _desc;
  FaceDetector? _detector;

  String? _error;
  bool _starting = true;
  bool _capturing = false;
  Picked? _shot;

  // ---- liveness state ----
  bool get _useLiveness => !kIsWeb; // ML Kit = Android / iOS only
  bool _streaming = false;
  bool _processing = false;
  bool _finishing = false;
  List<_Challenge> _steps = [];
  int _stepIndex = 0;
  bool _lookStraight = false; // last phase before the photo is taken
  int _holdFrames = 0;
  bool _sawOpen = false, _sawClosed = false; // blink = open -> closed -> open
  DateTime _deadline = DateTime.now();
  bool _faceOk = false;
  String? _problem; // "Move closer", "No face found", ...
  String _notice = ''; // "Time is up", "Photo not clear", ...

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _detector?.close();
    _cam?.dispose(); // also stops the image stream
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _streaming = false;
      c.dispose();
      _cam = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _shot == null) {
      _start();
    }
  }

  // ------------------------------------------------------------ camera start
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
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      final c = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        // ML Kit wants NV21 (Android) or BGRA (iOS) frames
        imageFormatGroup: kIsWeb
            ? ImageFormatGroup.jpeg
            : (isIos ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21),
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await _cam?.dispose();
      _cam = c;
      _desc = cam;
      if (_useLiveness) {
        _detector ??= FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true, // eye-open + smile probability
            performanceMode: FaceDetectorMode.fast,
          ),
        );
      }
      setState(() => _starting = false);
      if (_useLiveness) await _beginChallenges();
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

  // ------------------------------------------------------- liveness: setup
  /// New random challenges: ALWAYS a blink + one of (smile / turn head),
  /// in random order, so a printed photo or a replayed video can not guess it.
  Future<void> _beginChallenges([String notice = '']) async {
    final extra = ([_Challenge.smile, _Challenge.turn]..shuffle()).first;
    _steps = [_Challenge.blink, extra]..shuffle();
    _stepIndex = 0;
    _lookStraight = false;
    _finishing = false;
    _resetStepState();
    _faceOk = false;
    _problem = null;
    _notice = notice;
    _deadline = DateTime.now().add(const Duration(seconds: _stepSeconds));
    if (mounted) setState(() {});
    await _startStream();
  }

  void _resetStepState() {
    _sawOpen = false;
    _sawClosed = false;
    _holdFrames = 0;
  }

  Future<void> _startStream() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized || _streaming) return;
    _streaming = true;
    await c.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    final c = _cam;
    if (c == null || !_streaming) return;
    _streaming = false;
    try {
      await c.stopImageStream();
    } catch (_) {}
  }

  // ------------------------------------------------- liveness: every frame
  Future<void> _onFrame(CameraImage img) async {
    if (_processing || _finishing || !mounted || _detector == null) return;
    _processing = true;
    try {
      final input = _toInputImage(img);
      if (input == null) return;
      final faces = await _detector!.processImage(input);
      if (!mounted || _finishing) return;
      _evaluate(faces, input.metadata!);
    } catch (_) {
      // skip this frame
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final cam = _desc;
    final c = _cam;
    if (cam == null || c == null) return null;
    final sensor = cam.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _rotations[c.value.deviceOrientation];
      if (comp == null) return null;
      comp = cam.lensDirection == CameraLensDirection.front
          ? (sensor + comp) % 360
          : (sensor - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final wanted = defaultTargetPlatform == TargetPlatform.iOS
        ? InputImageFormat.bgra8888
        : InputImageFormat.nv21;
    if (format != wanted || image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _evaluate(List<Face> faces, InputImageMetadata meta) {
    // time limit per challenge
    if (DateTime.now().isAfter(_deadline)) {
      _beginChallenges('Time is up. Let\'s try again.');
      return;
    }

    final swap = meta.rotation == InputImageRotation.rotation90deg ||
        meta.rotation == InputImageRotation.rotation270deg;
    final w = swap ? meta.size.height : meta.size.width;
    final h = swap ? meta.size.width : meta.size.height;

    String? problem;
    Face? face;
    if (faces.isEmpty) {
      problem = 'No face found. Face the camera.';
    } else if (faces.length > 1) {
      problem = 'Only one person in the frame, please.';
    } else {
      face = faces.first;
      final b = face.boundingBox;
      final cx = b.center.dx / w, cy = b.center.dy / h;
      if (b.width / w < 0.30) {
        problem = 'Move closer.';
      } else if (b.width / w > 0.85) {
        problem = 'Move back a little.';
      } else if (cx < 0.25 || cx > 0.75 || cy < 0.2 || cy > 0.8) {
        problem = 'Center your face in the frame.';
      }
    }

    final ok = problem == null;
    if (ok != _faceOk || problem != _problem) {
      setState(() {
        _faceOk = ok;
        _problem = problem;
        if (ok) _notice = '';
      });
    }
    if (!ok || face == null) {
      _holdFrames = 0;
      return;
    }

    final l = face.leftEyeOpenProbability;
    final r = face.rightEyeOpenProbability;
    final smile = face.smilingProbability;
    final yaw = face.headEulerAngleY;

    // ---- last phase: look straight with open eyes, then take the photo
    if (_lookStraight) {
      final straight =
          (yaw ?? 0).abs() < 12 && (l ?? 1) > 0.6 && (r ?? 1) > 0.6;
      _holdFrames = straight ? _holdFrames + 1 : 0;
      if (_holdFrames >= 8) _finish();
      return;
    }

    switch (_steps[_stepIndex]) {
      case _Challenge.blink:
        if (l == null || r == null) return;
        final open = l > 0.6 && r > 0.6;
        final closed = l < 0.3 && r < 0.3;
        if (!_sawOpen) {
          if (open) _sawOpen = true;
        } else if (!_sawClosed) {
          if (closed) _sawClosed = true;
        } else if (open) {
          _nextStep(); // open -> closed -> open = one blink
        }
        break;
      case _Challenge.smile:
        _holdFrames = (smile ?? 0) > 0.7 ? _holdFrames + 1 : 0;
        if (_holdFrames >= 4) _nextStep();
        break;
      case _Challenge.turn:
        _holdFrames = (yaw ?? 0).abs() >= 20 ? _holdFrames + 1 : 0;
        if (_holdFrames >= 3) _nextStep();
        break;
    }
  }

  void _nextStep() {
    _resetStepState();
    _deadline = DateTime.now().add(const Duration(seconds: _stepSeconds));
    setState(() {
      _stepIndex++;
      if (_stepIndex >= _steps.length) {
        _stepIndex = _steps.length - 1;
        _lookStraight = true;
      }
    });
  }

  // ------------------------------------------------------ take the real photo
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final c = _cam;
    if (c == null) return;
    setState(() => _capturing = true);
    try {
      await _stopStream();
      await Future.delayed(const Duration(milliseconds: 250));
      final x = await c.takePicture();

      // Check the REAL photo too: it must contain exactly one face.
      try {
        final faces =
            await _detector!.processImage(InputImage.fromFilePath(x.path));
        if (faces.length != 1) {
          if (mounted) {
            setState(() => _capturing = false);
            await _beginChallenges(
                'The photo was not clear. Please try again.');
          }
          return;
        }
      } catch (_) {
        // could not re-check the file, accept the photo
      }

      await _acceptPhoto(x);
    } on CameraException catch (e) {
      if (mounted) {
        showMsg(context, _friendly(e), error: true);
        await _beginChallenges();
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  // Chrome (no ML Kit): plain capture button
  Future<void> _captureManual() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      await _acceptPhoto(await c.takePicture());
    } on CameraException catch (e) {
      if (mounted) showMsg(context, _friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _acceptPhoto(XFile x) async {
    final bytes = await x.readAsBytes();
    if (bytes.length > maxImageBytes) {
      if (mounted) {
        showMsg(context, 'The photo is larger than 5 MB. Please try again.',
            error: true);
        if (_useLiveness) await _beginChallenges();
      }
      return;
    }
    // The API decides the file type from the extension, so name it correctly.
    final isPng = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final name =
        'selfie_${DateTime.now().millisecondsSinceEpoch}.${isPng ? 'png' : 'jpg'}';
    if (!mounted) return;
    setState(() => _shot = Picked(bytes, name));
  }

  void _retake() {
    setState(() => _shot = null);
    if (_useLiveness) _beginChallenges();
  }

  // ----------------------------------------------------------------- screens
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

  String get _instruction {
    if (_lookStraight) return 'Great! Now look straight at the camera';
    switch (_steps[_stepIndex]) {
      case _Challenge.blink:
        return 'Blink your eyes';
      case _Challenge.smile:
        return 'Smile for the camera';
      case _Challenge.turn:
        return 'Slowly turn your head to the side';
    }
  }

  Widget _cameraView() {
    final c = _cam;
    if (c == null || !c.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    final live = _useLiveness && _steps.isNotEmpty;
    final frameColor = live && _faceOk ? AppColors.green : AppColors.gold;

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(child: CameraPreview(c)), // the LIVE camera feed
              IgnorePointer(
                child: Container(
                  width: 230,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: frameColor, width: 3),
                    borderRadius:
                        const BorderRadius.all(Radius.elliptical(115, 150)),
                  ),
                ),
              ),
              if (live)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: _instructionCard(),
                ),
              if (_capturing)
                const CircularProgressIndicator(color: AppColors.gold),
            ],
          ),
        ),
        if (live) _progressDots(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            live
                ? 'Good lighting, no mask, cap or sunglasses. The photo is taken automatically.'
                : 'Chrome test mode: blink check works on the phone app only.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
        ),
        if (!live)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
              onTap: _captureManual,
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
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _instructionCard() {
    final warn = _problem ?? (_notice.isNotEmpty ? _notice : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _instruction,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (warn != null) ...[
            const SizedBox(height: 4),
            Text(
              warn,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.gold, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progressDots() {
    final total = _steps.length + 1; // challenges + "look straight"
    final done = _lookStraight ? _steps.length : _stepIndex;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final filled = i < done;
          final current = i == done;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: current ? 22 : 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: filled
                  ? AppColors.green
                  : current
                      ? AppColors.gold
                      : Colors.white24,
            ),
          );
        }),
      ),
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
                      onPressed: _retake,
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
