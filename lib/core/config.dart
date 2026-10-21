class AppConfig {
  /// IPv4 address of the laptop that runs the API (run `ipconfig` on that laptop)
  /// plus the port from launchSettings.json. Both devices must be on the same hotspot.
  /// This is the ONLY line you change when the hotspot gives the laptop a new IP.
  static const String baseUrl = 'http://192.168.49.185:5299';

  // Shown on the Home screen (edit to the real barangay details)
  static const String barangayName = 'Manguikay';
  static const String contactNumber = '0932 456 7789';
  static const String contactEmail = 'manguikay@barangay.gov.ph';
  static const String officeHours = 'Mon - Fri, 8:00 AM - 5:00 PM';

  /// Turns an API path like "uploads/complaints/1/a.jpg" into a full URL.
  static String imageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final p = path.trim().replaceAll('\\', '/');
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '$baseUrl/${p.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
