import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool hasAccount;
  const AuthScreen({super.key, required this.hasAccount});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _signingUp;
  bool _busy = false;
  bool _hidePassword = true;
  String _selectedRole = 'cashier';

  @override
  void initState() {
    super.initState();
    _signingUp = !widget.hasAccount;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final error = _signingUp
        ? await AuthService.signUp(
            name: _name.text, email: _email.text, password: _password.text)
        : await AuthService.signIn(
            email: _email.text,
            password: _password.text,
            selectedRole: _selectedRole);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
              role: _signingUp ? 'cashier' : _selectedRole)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.receipt_long,
                              color: Colors.white, size: 30)),
                      const SizedBox(height: 28),
                      Text(
                          _signingUp
                              ? 'Buat akun Fasnote'
                              : 'Selamat datang kembali',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                          _signingUp
                              ? 'Daftar untuk mulai menggunakan Fasnote.'
                              : 'Masuk untuk melanjutkan ke Fasnote.',
                          style: TextStyle(
                              color: dark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 28),
                      if (_signingUp) ...[
                        _field(_name, 'Nama', Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama wajib diisi'
                                : null),
                        const SizedBox(height: 14),
                      ],
                      if (!_signingUp) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Masuk sebagai',
                              style: Theme.of(context).textTheme.labelLarge),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'cashier',
                                label: Text('Kasir'),
                                icon: Icon(Icons.point_of_sale_outlined)),
                            ButtonSegment(
                                value: 'owner',
                                label: Text('Owner'),
                                icon: Icon(Icons.store_outlined)),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: _busy
                              ? null
                              : (selection) => setState(
                                  () => _selectedRole = selection.first),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _field(_email, 'Email', Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null ||
                                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(v.trim()))
                              ? 'Masukkan email yang valid'
                              : null),
                      const SizedBox(height: 14),
                      _field(_password, 'Kata sandi', Icons.lock_outline,
                          obscure: _hidePassword,
                          suffix: IconButton(
                              icon: Icon(_hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword)),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'Gunakan minimal 8 karakter'
                              : null),
                      if (_signingUp) ...[
                        const SizedBox(height: 14),
                        _field(
                            _confirm, 'Ulangi kata sandi', Icons.lock_outline,
                            obscure: true,
                            validator: (v) => v != _password.text
                                ? 'Kata sandi belum sama'
                                : null),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(_signingUp ? 'Daftar' : 'Masuk',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                          )),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _signingUp = !_signingUp),
                          child: Text(_signingUp
                              ? 'Sudah punya akun? Masuk'
                              : 'Belum punya akun? Daftar')),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {String? Function(String?)? validator,
      TextInputType? keyboardType,
      bool obscure = false,
      Widget? suffix}) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16)),
    );
  }
}
