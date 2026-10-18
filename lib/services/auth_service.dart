import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<bool> get hasAccount async =>
      (await SharedPreferences.getInstance()).getString(_emailKey) != null;

  static Future<bool> get isSignedIn async => _auth.currentUser != null;

  static Future<String> get displayName async {
    final user = _auth.currentUser;
    if (user?.displayName?.isNotEmpty == true) return user!.displayName!;
    return (await SharedPreferences.getInstance()).getString(_nameKey) ?? '';
  }

  static Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();
      await _saveLocalProfile(name.trim(), email.trim().toLowerCase());
      return null;
    } on FirebaseAuthException catch (error) {
      return _messageFor(error);
    } catch (_) {
      return 'Pendaftaran gagal. Periksa koneksi internet dan konfigurasi Firebase.';
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _saveLocalProfile(
        credential.user?.displayName ?? '',
        credential.user?.email ?? email.trim().toLowerCase(),
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _messageFor(error);
    } catch (_) {
      return 'Tidak dapat masuk. Periksa koneksi internet dan konfigurasi Firebase.';
    }
  }

  static Future<void> _saveLocalProfile(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 8 karakter.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi tidak sesuai.';
      case 'network-request-failed':
        return 'Koneksi internet terputus. Coba lagi.';
      default:
        return error.message ?? 'Terjadi kesalahan autentikasi.';
    }
  }
}
