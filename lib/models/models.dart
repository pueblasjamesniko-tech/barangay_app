import 'dart:typed_data';
import 'package:dio/dio.dart' show MultipartFile;
import '../core/json.dart';

/// An image the user picked (kept as bytes so it works on phone AND Chrome).
class Picked {
  final Uint8List bytes;
  final String name;
  const Picked(this.bytes, this.name);
  MultipartFile toMultipart() => MultipartFile.fromBytes(bytes, filename: name);
}

class UserSession {
  final int userId;
  final String fullName;
  final String purokName;
  final String email;
  final String username;
  const UserSession({
    required this.userId,
    required this.fullName,
    required this.purokName,
    required this.email,
    required this.username,
  });

  factory UserSession.fromJson(Map<String, dynamic> m) => UserSession(
        userId: asInt(m['userid']),
        fullName: asStr(m['fullname']),
        purokName: asStr(m['purokname']),
        email: asStr(m['email']),
        username: asStr(m['username']),
      );

  Map<String, dynamic> toJson() => {
        'userid': userId,
        'fullname': fullName,
        'purokname': purokName,
        'email': email,
        'username': username,
      };

  UserSession copyWith({String? fullName}) => UserSession(
        userId: userId,
        fullName: fullName ?? this.fullName,
        purokName: purokName,
        email: email,
        username: username,
      );
}

class Purok {
  final int id;
  final String name;
  const Purok(this.id, this.name);
  factory Purok.fromJson(Map<String, dynamic> m) =>
      Purok(asInt(m['purokid']), asStr(m['purokname']));
}

class Complaint {
  final int id;
  final int userId;
  final String fullName;
  final String? profilePicturePath;
  final String text;
  final String status;
  final DateTime createdAt;
  final List<String> photos;
  const Complaint({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.profilePicturePath,
    required this.text,
    required this.status,
    required this.createdAt,
    required this.photos,
  });

  bool get isResolved => status.toLowerCase() == 'resolved';

  factory Complaint.fromJson(Map<String, dynamic> m) => Complaint(
        id: asInt(m['complaintid']),
        userId: asInt(m['userid']),
        fullName: asStr(m['fullname']),
        profilePicturePath: asStrN(m['profilepicturepath']),
        text: asStr(m['complainttext']),
        status: asStr(m['status'], 'Pending'),
        createdAt: asDate(m['createdat']),
        photos: asStrList(m['photos']),
      );
}

class Announcement {
  final int id;
  final String adminName;
  final String? adminProfilePicturePath;
  final String caption;
  final DateTime createdAt;
  final List<String> photos;
  const Announcement({
    required this.id,
    required this.adminName,
    required this.adminProfilePicturePath,
    required this.caption,
    required this.createdAt,
    required this.photos,
  });

  factory Announcement.fromJson(Map<String, dynamic> m) => Announcement(
        id: asInt(m['announcementid']),
        adminName: asStr(m['adminname']),
        adminProfilePicturePath: asStrN(m['adminprofilepicturepath']),
        caption: asStr(m['caption']),
        createdAt: asDate(m['createdat']),
        photos: asStrList(m['photos']),
      );
}

/// One card in the community feed: either a resident post or an announcement.
class FeedItem {
  final Complaint? complaint;
  final Announcement? announcement;
  const FeedItem._(this.complaint, this.announcement);

  factory FeedItem.fromComplaint(Complaint c) => FeedItem._(c, null);
  factory FeedItem.fromAnnouncement(Announcement a) => FeedItem._(null, a);

  bool get isAnnouncement => announcement != null;

  DateTime get createdAt => announcement?.createdAt ?? complaint!.createdAt;

  String get authorName => announcement != null
      ? (announcement!.adminName.isEmpty
          ? 'Barangay Office'
          : announcement!.adminName)
      : complaint!.fullName;

  String? get authorPic => announcement != null
      ? announcement!.adminProfilePicturePath
      : complaint!.profilePicturePath;

  String get body => announcement != null ? announcement!.caption : complaint!.text;

  List<String> get photos => announcement?.photos ?? complaint!.photos;
}

class AppNotification {
  final int id;
  final int complaintId;
  final String message;
  bool isRead;
  final DateTime createdAt;
  AppNotification({
    required this.id,
    required this.complaintId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> m) => AppNotification(
        id: asInt(m['notificationid']),
        complaintId: asInt(m['complaintid']),
        message: asStr(m['message']),
        isRead: asBool(m['isread']),
        createdAt: asDate(m['createdat']),
      );
}

class Profile {
  final int userId;
  final String fullName;
  final String email;
  final String username;
  final String? contactNumber;
  final int? age;
  final String? gender;
  final String? address;
  final String? profilePicturePath;
  final DateTime createdAt;
  final String purokName;
  const Profile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.username,
    required this.contactNumber,
    required this.age,
    required this.gender,
    required this.address,
    required this.profilePicturePath,
    required this.createdAt,
    required this.purokName,
  });

  factory Profile.fromJson(Map<String, dynamic> m) => Profile(
        userId: asInt(m['userid']),
        fullName: asStr(m['fullname']),
        email: asStr(m['email']),
        username: asStr(m['username']),
        contactNumber: asStrN(m['contactnumber']),
        age: asIntN(m['age']),
        gender: asStrN(m['gender']),
        address: asStrN(m['address']),
        profilePicturePath: asStrN(m['profilepicturepath']),
        createdAt: asDate(m['createdat']),
        purokName: asStr(m['purokname']),
      );
}

class Faq {
  final int id;
  final String question;
  final String answer;
  const Faq(this.id, this.question, this.answer);
  factory Faq.fromJson(Map<String, dynamic> m) =>
      Faq(asInt(m['faqid']), asStr(m['question']), asStr(m['answer']));
}
