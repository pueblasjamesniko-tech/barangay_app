import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_provider.dart';
import '../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Show "session expired" etc. once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final n = auth.notice;
      if (n != null) {
        auth.clearNotice();
        showMsg(context, n, error: true);
      }
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await context.read<AuthProvider>().login(_id.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) showMsg(context, r.message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final white = GoogleFonts.poppins(color: Colors.white);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: AppLogo(size: 110)),
                  const SizedBox(height: 14),
                  Center(
                    child: Text.rich(
                      TextSpan(children: const [
                        TextSpan(text: 'Maguikay'),
                        TextSpan(
                            text: 'Connect',
                            style: TextStyle(color: AppColors.gold)),
                      ]),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Center(
                    child: Text('Official Barangay Portal',
                        style: white.copyWith(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 30),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                      ),
                      children: const [
                        TextSpan(text: 'Your voice,\nyour '),
                        TextSpan(
                            text: 'barangay.',
                            style: TextStyle(color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Report concerns, track requests, and stay updated with your barangay.',
                    style: white.copyWith(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  const FieldLabel('Email or username'),
                  AppField(
                    controller: _id,
                    hint: 'name@gmail.com or username',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your email or username'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Password'),
                  AppField(
                    controller: _pw,
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    password: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showMsg(context,
                          'Please contact the barangay office to reset your password.'),
                      child: Text('Forgot password?',
                          style: GoogleFonts.poppins(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                      label: 'Continue', loading: _busy, onPressed: _submit),
                  const SizedBox(height: 24),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style: white.copyWith(
                                fontSize: 12, color: Colors.white70)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: Text('Create an account',
                              style: GoogleFonts.poppins(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
