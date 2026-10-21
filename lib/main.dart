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

  // The API's login token lasts 60 minutes. When it expires any request returns 401:
  // log out, close every open screen and show the login screen.
  ApiClient.instance.onUnauthorized = () {
    auth.logout(message: 'Your session has expired. Please log in again.');
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
      // In Chrome the app is shown as a phone-width column
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE3E8F0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
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
