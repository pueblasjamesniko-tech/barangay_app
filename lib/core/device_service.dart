import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifies this phone to the API (one account = one device).
class DeviceService {
  DeviceService._();

  static const _key = 'device_id';
  static String? _id;
  static String? _name;

  /// Random ID created on first launch and kept on this phone.
  static Future<String> id() async {
    if (_id != null) return _id!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final value = (stored != null && stored.isNotEmpty) ? stored : _generate();
    if (value != stored) await prefs.setString(_key, value);
    _id = value;
    return value;
  }

  /// Readable name shown in the "already logged in on ..." message.
  /// Also use this in Settings to show "This device".
  static Future<String> name() async {
    if (_name != null) return _name!;
    var n = 'Unknown device';
    try {
      if (kIsWeb) {
        n = 'Web browser';
      } else {
        final info = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final a = await info.androidInfo;
          final m = a.manufacturer;
          final brand =
              m.isEmpty ? '' : '${m[0].toUpperCase()}${m.substring(1)}';
          n = '$brand ${a.model}'.trim();
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final i = await info.iosInfo;
          n = i.name.isNotEmpty ? i.name : i.model;
        }
      }
    } catch (_) {}
    _name = n;
    return n;
  }

  static String _generate() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
