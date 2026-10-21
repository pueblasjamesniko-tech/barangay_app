import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';
import '../widgets/common.dart';
import '../widgets/picker.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Values must match what the API accepts for IdType
  static const _idTypes = {
    'NationalId': 'National ID (PhilSys)',
    'License': "Driver's License",
    'VotersId': "Voter's ID",
    'PostalId': 'Postal ID',
    'Other': 'Other valid ID',
  };

  final _f1 = GlobalKey<FormState>();
  final _f2 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  int _step = 1;
  List<Purok>? _puroks;
  String? _purokError;
  int? _purokId;
  String? _idType;
  Picked? _front;
  Picked? _back;
  Picked? _selfie;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPuroks();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _username, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPuroks() async {
    try {
      final l = await Repo.puroks();
      if (!mounted) return;
      setState(() => _puroks = l);
    } catch (e) {
      if (!mounted) return;
      setState(() => _purokError =
          e is ApiException ? e.message : 'Could not load the purok list.');
    }
  }

  void _next() {
    if (!_f1.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 2);
  }

  Future<void> _pick(int which) async {
    final p = await pickOne(context, selfie: which == 3);
    if (p == null || !mounted) return;
    setState(() {
      if (which == 1) _front = p;
      if (which == 2) _back = p;
      if (which == 3) _selfie = p;
    });
  }

  Future<void> _submit() async {
    if (!_f2.currentState!.validate()) return;
    if (_front == null || _back == null || _selfie == null) {
      showMsg(context,
          'Please add the front and back of your ID and a live selfie.',
          error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await Repo.register(
      fullName: _name.text.trim(),
      purokId: _purokId!,
      email: _email.text.trim(),
      username: _username.text.trim(),
      password: _pw.text,
      idType: _idType!,
      idFront: _front!,
      idBack: _back!,
      selfie: _selfie!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      showMsg(context, r.message, error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Registration submitted'),
        content: const Text(
            'Your account is now waiting for admin verification. '
            'You can log in once the barangay approves it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_step == 2) {
                      setState(() => _step = 1);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _step == 2
                            ? 'Back to personal information'
                            : 'Back to login',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                    children: const [
                      TextSpan(text: 'Create your '),
                      TextSpan(
                          text: 'account',
                          style: TextStyle(color: AppColors.gold)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _step == 1
                      ? "Let's get started with you basic information."
                      : 'Set up your account and verify your identity.',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 14),
                Text('Step $_step of 2',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 10.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _bar(true)),
                    const SizedBox(width: 6),
                    Expanded(child: _bar(_step == 2)),
                  ],
                ),
                const SizedBox(height: 22),
                if (_step == 1) _stepOne() else _stepTwo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(bool on) => Container(
        height: 6,
        decoration: BoxDecoration(
          color: on ? AppColors.gold : const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      );

  // ---------------- step 1 ----------------
  Widget _stepOne() {
    return Form(
      key: _f1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Personal Information'),
          const FieldLabel('Full name'),
          AppField(
            controller: _name,
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'Enter your full name'
                : null,
          ),
          const SizedBox(height: 14),
          const FieldLabel('Purok / Zone'),
          _purokDropdown(),
          const SizedBox(height: 14),
          const FieldLabel('Email address'),
          AppField(
            controller: _email,
            hint: 'name@gmail.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final s = (v ?? '').trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 26),
          PrimaryButton(
              label: 'Continue', icon: Icons.arrow_forward, onPressed: _next),
        ],
      ),
    );
  }

  Widget _purokDropdown() {
    if (_purokError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_purokError!,
                style: GoogleFonts.poppins(
                    color: AppColors.errorOnDark, fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _purokError = null);
              _loadPuroks();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (_puroks == null) {
      return Container(
        height: 54,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Text('Loading puroks...',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.muted)),
      );
    }
    return DropdownButtonFormField<int>(
      value: _purokId,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
      decoration:
          appInputDecoration(hint: 'Select your Purok / Zone', icon: Icons.place_outlined),
      items: [
        for (final p in _puroks!)
          DropdownMenuItem<int>(
            value: p.id,
            child: Text(p.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _purokId = v),
      validator: (v) => v == null ? 'Select your purok' : null,
    );
  }

  // ---------------- step 2 ----------------
  Widget _stepTwo() {
    return Form(
      key: _f2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Account information'),
          const FieldLabel('Username'),
          AppField(
            controller: _username,
            hint: 'Choose a username',
            icon: Icons.person_outline,
            validator: (v) => RegExp(r'^[A-Za-z0-9_.]{4,30}$')
                    .hasMatch((v ?? '').trim())
                ? null
                : '4-30 characters: letters, numbers, _ or .',
          ),
          const SizedBox(height: 14),
          const FieldLabel('Password'),
          AppField(
            controller: _pw,
            hint: 'At least 8 characters',
            icon: Icons.lock_outline,
            password: true,
            validator: (v) => (v == null || v.length < 8)
                ? 'Password must be at least 8 characters'
                : null,
          ),
          const SizedBox(height: 14),
          const FieldLabel('Confirm password'),
          AppField(
            controller: _pw2,
            hint: 'Re-enter your password',
            icon: Icons.lock_outline,
            password: true,
            validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 22),
          _heading('Verify your identity'),
          Text(
            'The barangay checks these before approving your account. Photos only, max 5 MB each.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 12),
          const FieldLabel('ID type'),
          DropdownButtonFormField<String>(
            value: _idType,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
            decoration:
                appInputDecoration(hint: 'Select ID type', icon: Icons.badge_outlined),
            items: [
              for (final e in _idTypes.entries)
                DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _idType = v),
            validator: (v) => v == null ? 'Select the type of ID' : null,
          ),
          const SizedBox(height: 14),
          _UploadBox(
            title: 'ID - front',
            hint: 'JPG or PNG, max 5 MB',
            icon: Icons.credit_card,
            picked: _front,
            onTap: () => _pick(1),
          ),
          const SizedBox(height: 12),
          _UploadBox(
            title: 'ID - back',
            hint: 'JPG or PNG, max 5 MB',
            icon: Icons.credit_card,
            picked: _back,
            onTap: () => _pick(2),
          ),
          const SizedBox(height: 12),
          _UploadBox(
            title: 'Live selfie',
            hint: 'Take a clear photo of your face',
            icon: Icons.camera_alt_outlined,
            picked: _selfie,
            onTap: () => _pick(3),
          ),
          const SizedBox(height: 26),
          PrimaryButton(
              label: 'Submit registration', loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final Picked? picked;
  final VoidCallback onTap;
  const _UploadBox({
    required this.title,
    required this.hint,
    required this.icon,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: picked == null ? const Color(0x66FFFFFF) : AppColors.gold,
            width: 1.4,
          ),
        ),
        child: picked == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.gold, size: 32),
                  const SizedBox(height: 6),
                  Text(title,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  Text(hint,
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 10.5)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(picked!.bytes,
                      fit: BoxFit.cover, gaplessPlayback: true),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$title - tap to change',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
