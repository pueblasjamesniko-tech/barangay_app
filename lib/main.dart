import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthProvider();

  // Any request that returns 401 means the login is no longer valid
  // (token expired after 60 minutes, or the account was opened on another phone).
  // Log out, close every open screen and show the login screen.
  ApiClient.instance.onUnauthorized = () {
    auth.logout(
        message: 'You were logged out. Your session expired or your account '
            'was opened on another device. Please log in again.');
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  };

  await auth.init();

  runApp(ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: const BarangayApp(),
  ));
}

class BarangayApp extends StatelessWidget {
  const BarangayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaguikayConnect',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      builder: (context, child) {
        // Respect the phone's text-size setting, but not so big that the layout breaks.
        final mq = MediaQuery.of(context);
        final scaled = mq.copyWith(
          textScaler: mq.textScaler.clamp(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.25,
          ),
        );
        // In Chrome the app is shown as a phone-width column.
        return MediaQuery(
          data: scaled,
          child: ColoredBox(
            color: const Color(0xFFE3E8F0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: child,
              ),
            ),
          ),
        );
      },
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.ready) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (auth.token == null) return const LoginScreen();
          return HomeShell(key: ValueKey(auth.user?.userId));
        },
      ),
    );
  }
}
