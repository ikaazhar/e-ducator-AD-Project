// lib/screens/forgot_password_screen.dart
//
// Skrin lupa kata laluan (aliran kod OTP, tanpa pautan).
// Langkah 1: masukkan e-mel → Supabase hantar kod pengesahan.
// Langkah 2: masukkan kod + kata laluan baru → sahkan & tetapkan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_codeSent && !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().sendPasswordResetCode(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jika e-mel berdaftar, kod pengesahan telah dihantar. '
            'Sila semak e-mel anda.',
          ),
        ),
      );
    } on PasswordResetException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().verifyResetCodeAndUpdatePassword(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } on PasswordResetException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Berjaya'),
        content: const Text(
          'Kata laluan anda telah ditukar. '
          'Sila log masuk dengan kata laluan baru.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Log Masuk'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.slate,
      appBar: AppBar(title: const Text('Lupa Kata Laluan')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: _codeSent ? _buildStepCode() : _buildStepEmail(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Langkah 1: e-mel ─────────────────────────────────────────────────────
  List<Widget> _buildStepEmail() {
    return [
      const Icon(Icons.lock_reset, size: 56, color: AppTheme.navy),
      const SizedBox(height: 12),
      const Text(
        'Lupa Kata Laluan',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppTheme.navy,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Masukkan e-mel anda untuk menerima kod pengesahan.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textMuted),
      ),
      const SizedBox(height: 28),
      TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'E-mel',
          prefixIcon: Icon(Icons.mail_outline),
        ),
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Sila masukkan e-mel' : null,
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading ? null : _sendCode,
        child: _loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Hantar Kod'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Kembali ke Log Masuk'),
      ),
    ];
  }

  // ─── Langkah 2: kod + kata laluan baru ────────────────────────────────────
  List<Widget> _buildStepCode() {
    return [
      const Icon(Icons.pin_outlined, size: 56, color: AppTheme.navy),
      const SizedBox(height: 12),
      const Text(
        'Masukkan Kod Pengesahan',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppTheme.navy,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Kod pengesahan telah dihantar ke ${_emailCtrl.text.trim()}.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textMuted),
      ),
      const SizedBox(height: 28),
      TextFormField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Kod Pengesahan',
          prefixIcon: Icon(Icons.pin_outlined),
          counterText: '',
        ),
        validator: (v) => (v == null || v.trim().length < 6)
            ? 'Masukkan kod dari e-mel anda'
            : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'Kata Laluan Baru',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: (v) =>
            (v == null || v.length < 6) ? 'Sekurang-kurangnya 6 aksara' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _confirmCtrl,
        obscureText: _obscure,
        decoration: const InputDecoration(
          labelText: 'Sahkan Kata Laluan',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        validator: (v) =>
            (v != _passwordCtrl.text) ? 'Kata laluan tidak sepadan' : null,
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading ? null : _resetPassword,
        child: _loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Tetapkan Kata Laluan'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _loading ? null : _sendCode,
        child: const Text('Hantar semula kod'),
      ),
      TextButton(
        onPressed: _loading
            ? null
            : () => setState(() {
                  _codeSent = false;
                  _codeCtrl.clear();
                }),
        child: const Text('Tukar e-mel'),
      ),
    ];
  }
}
