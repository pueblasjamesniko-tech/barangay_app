import 'package:dio/dio.dart' show FormData;
import '../core/api.dart';
import '../models/models.dart';

/// Every call to your existing API lives here.
class Repo {
  static final ApiClient _api = ApiClient.instance;

  static List<T> _list<T>(ApiResult r, T Function(Map<String, dynamic>) f) {
    if (!r.ok) throw ApiException(r.message);
    final d = r.data;
    if (d is! List) return <T>[];
    return d.map((e) => f(e as Map<String, dynamic>)).toList();
  }

  // ---------- auth ----------
  static Future<ApiResult> login(String emailOrUsername, String password) =>
      _api.postJson('/api/Login',
          {'emailOrUsername': emailOrUsername, 'password': password});

  static Future<List<Purok>> puroks() async =>
      _list(await _api.get('/api/Register/puroks'), Purok.fromJson);

  static Future<ApiResult> register({
    required String fullName,
    required int purokId,
    required String email,
    required String username,
    required String password,
    required String idType,
    required Picked idFront,
    required Picked idBack,
    required Picked selfie,
  }) {
    final form = FormData();
    form.fields.addAll([
      MapEntry('FullName', fullName),
      MapEntry('PurokId', '$purokId'),
      MapEntry('Email', email),
      MapEntry('Username', username),
      MapEntry('Password', password),
      MapEntry('IdType', idType),
    ]);
    form.files.addAll([
      MapEntry('IdFrontImage', idFront.toMultipart()),
      MapEntry('IdBackImage', idBack.toMultipart()),
      MapEntry('LiveSelfieImage', selfie.toMultipart()),
    ]);
    return _api.postForm('/api/Register', form);
  }

  // ---------- complaints (feed + my requests) ----------
  static Future<List<Complaint>> complaints() async =>
      _list(await _api.get('/api/Complaint'), Complaint.fromJson);

  static Future<ApiResult> createComplaint(String text, List<Picked> photos) {
    final form = FormData();
    if (text.trim().isNotEmpty) {
      form.fields.add(MapEntry('ComplaintText', text.trim()));
    }
    for (final p in photos) {
      form.files.add(MapEntry('Photos', p.toMultipart()));
    }
    return _api.postForm('/api/Complaint', form);
  }

  // ---------- announcements ----------
  static Future<List<Announcement>> announcements() async =>
      _list(await _api.get('/api/Announcement'), Announcement.fromJson);

  // ---------- notifications ----------
  static Future<List<AppNotification>> notifications() async =>
      _list(await _api.get('/api/Notification'), AppNotification.fromJson);

  static Future<ApiResult> markRead(int id) =>
      _api.postJson('/api/Notification/read/$id');

  static Future<ApiResult> markAllRead() =>
      _api.postJson('/api/Notification/read-all');

  // ---------- profile ----------
  static Future<Profile> profile() async {
    final r = await _api.get('/api/Profile');
    if (!r.ok) throw ApiException(r.message);
    if (r.data is! Map<String, dynamic>) {
      throw ApiException('Profile not found.');
    }
    return Profile.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<ApiResult> updateProfile({
    required String fullName,
    int? age,
    String? gender,
    String? address,
    String? contactNumber,
  }) =>
      _api.putJson('/api/Profile', {
        'fullName': fullName,
        'age': age,
        'gender': gender,
        'address': address,
        'contactNumber': contactNumber,
      });

  static Future<ApiResult> uploadPhoto(Picked photo) {
    final form = FormData();
    form.files.add(MapEntry('Photo', photo.toMultipart()));
    return _api.postForm('/api/Profile/photo', form);
  }

  static Future<ApiResult> changePassword(String current, String newPassword) =>
      _api.postJson('/api/Profile/password',
          {'currentPassword': current, 'newPassword': newPassword});

  static Future<ApiResult> deleteAccount() => _api.delete('/api/Profile');

  // ---------- chatbot FAQ ----------
  static Future<List<Faq>> faqs() async =>
      _list(await _api.get('/api/ChatbotFaq'), Faq.fromJson);
}
