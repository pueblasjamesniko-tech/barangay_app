import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bus.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';

/// Edit the fields the API lets a resident change:
/// full name, age, gender, address, contact number (PUT /api/Profile).
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const _genders = ['Male', 'Female', 'Other'];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  Profile? _p;
  String? _gender;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _address, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Repo.profile();
      if (!mounted) return;
      setState(() {
        _p = p;
        _error = null;
        _name.text = p.fullName;
        _age.text = p.age?.toString() ?? '';
        _address.text = p.address ?? '';
        _contact.text = p.contactNumber ?? '';
        _gender = _genders.contains(p.gender) ? p.gender : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          e is ApiException ? e.message : 'Could not load your information.');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    final age = int.tryParse(_age.text.trim());
    final r = await Repo.updateProfile(
      fullName: _name.text.trim(),
      age: age,
      gender: _gender,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      contactNumber: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    showMsg(context, r.message, error: !r.ok);
    if (!r.ok) return;
    auth.setFullName(_name.text.trim());
    refreshBus.value++;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Personal Information',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_p == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_p == null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorState(message: _error!, onRetry: _load),
      ]);
    }
    final p = _p!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _readOnly('Username', p.username, Icons.alternate_email),
            _readOnly('Email address', p.email, Icons.mail_outline),
            _readOnly('Purok / Zone', p.purokName, Icons.place_outlined),
            const SizedBox(height: 6),
            const FieldLabel('Full name', onDark: false),
            AppField(
              controller: _name,
              hint: 'Enter your full name',
              icon: Icons.person_outline,
              onDark: false,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Full name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Age', onDark: false),
            AppField(
              controller: _age,
              hint: 'Your age',
              icon: Icons.cake_outlined,
              onDark: false,
              keyboardType: TextInputType.number,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final n = int.tryParse(s);
                return (n == null || n < 1 || n > 120) ? 'Enter a valid age' : null;
              },
            ),
            const SizedBox(height: 14),
            const FieldLabel('Gender', onDark: false),
            DropdownButtonFormField<String>(
              value: _gender,
              isExpanded: true,
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
              decoration: appInputDecoration(
                  hint: 'Select gender', icon: Icons.wc_outlined, onDark: false),
              items: [
                for (final g in _genders)
                  DropdownMenuItem<String>(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Address', onDark: false),
            AppField(
              controller: _address,
              hint: 'House no., street',
              icon: Icons.home_outlined,
              onDark: false,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Contact number', onDark: false),
            AppField(
              controller: _contact,
              hint: '09XX XXX XXXX',
              icon: Icons.phone_outlined,
              onDark: false,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 26),
            PrimaryButton(label: 'Save changes', loading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _readOnly(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(label, onDark: false),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEF6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(value.isEmpty ? '-' : value,
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.muted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
