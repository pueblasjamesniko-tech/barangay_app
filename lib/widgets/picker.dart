import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import 'common.dart';

final ImagePicker _picker = ImagePicker();
const int maxImageBytes = 5 * 1024 * 1024; // 5 MB

String _safeName(XFile f) {
  // The API decides the file type from the extension, so always keep a real one.
  final n = f.name;
  final dot = n.lastIndexOf('.');
  final ext = dot >= 0 ? n.substring(dot + 1).toLowerCase() : '';
  if (const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return n;
  return '${DateTime.now().millisecondsSinceEpoch}.jpg';
}

Future<Picked?> _toPicked(BuildContext context, XFile f) async {
  final bytes = await f.readAsBytes();
  if (bytes.length > maxImageBytes) {
    if (context.mounted) {
      showMsg(context, '"${f.name}" is larger than 5 MB.', error: true);
    }
    return null;
  }
  return Picked(bytes, _safeName(f));
}

Future<ImageSource?> _askSource(BuildContext context) async {
  if (kIsWeb) return ImageSource.gallery; // Chrome has no camera sheet
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Pick one image. [selfie] opens the front camera directly on a phone.
Future<Picked?> pickOne(BuildContext context, {bool selfie = false}) async {
  final ImageSource? src =
      (selfie && !kIsWeb) ? ImageSource.camera : await _askSource(context);
  if (src == null) return null;
  try {
    final x = await _picker.pickImage(
      source: src,
      maxWidth: 1600,
      imageQuality: 85,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (x == null) return null;
    if (!context.mounted) return null;
    return _toPicked(context, x);
  } catch (e) {
    if (context.mounted) {
      showMsg(context, 'Could not open the camera or gallery: $e', error: true);
    }
    return null;
  }
}

/// Pick several images (gallery) or one photo (camera).
Future<List<Picked>> pickMany(BuildContext context) async {
  final src = await _askSource(context);
  if (src == null) return [];
  try {
    final List<XFile> files;
    if (src == ImageSource.camera) {
      final x = await _picker.pickImage(
          source: src, maxWidth: 1600, imageQuality: 85);
      files = x == null ? [] : [x];
    } else {
      files = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    }
    final out = <Picked>[];
    for (final f in files) {
      if (!context.mounted) break;
      final p = await _toPicked(context, f);
      if (p != null) out.add(p);
    }
    return out;
  } catch (e) {
    if (context.mounted) {
      showMsg(context, 'Could not open the camera or gallery: $e', error: true);
    }
    return [];
  }
}
