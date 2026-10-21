import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../services/auth_provider.dart';
import '../services/repo.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    Navigator.of(context).popUntil((r) => r.isFirst);
    await auth.logout();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'Your account will be removed and you will no longer be able to log in. '
            'This cannot be undone from the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    final r = await Repo.deleteAccount();
    if (!context.mounted) return;
    if (!r.ok) {
      showMsg(context, r.message, error: true);
      return;
    }
    nav.popUntil((route) => route.isFirst);
    await auth.logout(message: 'Your account was deleted.');
  }

  Future<void> _changePassword(BuildContext context) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (done == true && context.mounted) {
      showMsg(context, 'Password changed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Settings',
            subtitle: user == null ? null : '@${user.username}',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: cardDecoration(),
                  child: Column(
                    children: [
                      _tile(Icons.lock_outline, 'Change password',
                          () => _changePassword(context)),
                      const Divider(height: 1),
                      _tile(Icons.logout, 'Log out', () => _logout(context)),
                      const Divider(height: 1),
                      _tile(Icons.delete_outline, 'Delete account',
                          () => _deleteAccount(context),
                          color: AppColors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text('Server: ${AppConfig.baseUrl}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap,
          {Color color = AppColors.navy}) =>
      ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: color == AppColors.red ? color : AppColors.text)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await Repo.changePassword(_cur.text, _new.text);
    if (!mounted) return;
    if (r.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppField(
                controller: _cur,
                hint: 'Current password',
                icon: Icons.lock_outline,
                password: true,
                onDark: false,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 12),
              AppField(
                controller: _new,
                hint: 'New password (8+ characters)',
                icon: Icons.lock_reset,
                password: true,
                onDark: false,
                validator: (v) => (v == null || v.length < 8)
                    ? 'At least 8 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              AppField(
                controller: _new2,
                hint: 'Confirm new password',
                icon: Icons.lock_reset,
                password: true,
                onDark: false,
                validator: (v) => v != _new.text ? 'Passwords do not match' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
