import 'package:flutter/foundation.dart';
import 'repo.dart';

/// Keeps the unread-notification count for the red dots.
class NotifProvider extends ChangeNotifier {
  int unread = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    try {
      final list = await Repo.notifications();
      setUnread(list.where((n) => !n.isRead).length);
    } catch (_) {
      // ignore: the dot just stays as it was
    }
  }

  void setUnread(int n) {
    if (_disposed || n == unread) return;
    unread = n;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
