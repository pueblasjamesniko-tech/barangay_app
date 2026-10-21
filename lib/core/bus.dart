import 'package:flutter/foundation.dart';

/// Bump this (refreshBus.value++) after something changes (new post, new photo, ...)
/// and every screen that listens to it reloads its data.
final ValueNotifier<int> refreshBus = ValueNotifier<int>(0);
