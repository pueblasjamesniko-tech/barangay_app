import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../models/models.dart';
import 'repo.dart';

class AuthProvider extends ChangeNotifier {
  bool ready = false;
  String? token;
  UserSession? user;

  /// One-time message shown on the login screen (e.g. "session expired").
  String? notice;

  void clearNotice() => notice = null;

  /// Called once at startup: restores the saved login.
  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('token');
    final u = p.getString('user');
    if (t != null && u != null) {
      try {
        user = UserSession.fromJson(jsonDecode(u) as Map<String, dynamic>);
        token = t;
        ApiClient.instance.token = t;
      } catch (_) {
        await p.remove('token');
        await p.remove('user');
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<ApiResult> login(String emailOrUsername, String password) async {
    final r = await Repo.login(emailOrUsername, password);
    if (r.ok && r.token != null && r.data is Map<String, dynamic>) {
      token = r.token;
      user = UserSession.fromJson(r.data as Map<String, dynamic>);
      notice = null;
      ApiClient.instance.token = token;
      final p = await SharedPreferences.getInstance();
      await p.setString('token', token!);
      await p.setString('user', jsonEncode(user!.toJson()));
      notifyListeners();
    }
    return r;
  }

  void setFullName(String name) {
    if (user == null) return;
    user = user!.copyWith(fullName: name);
    SharedPreferences.getInstance()
        .then((p) => p.setString('user', jsonEncode(user!.toJson())));
    notifyListeners();
  }

  Future<void> logout({String? message}) async {
    if (token == null && user == null) return;
    token = null;
    user = null;
    notice = message;
    ApiClient.instance.token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    notifyListeners();
  }
}
