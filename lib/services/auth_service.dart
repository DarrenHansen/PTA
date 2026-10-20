import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

class AuthService {
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<Map<String, String>> loadAccessProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Masuk terlebih dahulu.');
    final snapshot = await FirebaseFirestore.instance
        .collection('user_roles')
        .doc(user.uid)
        .get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final role = data['role'] == 'owner' ? 'owner' : 'cashier';
    final rawBusinessOwnerUid = data['businessOwnerUid'];
    final businessOwnerUid =
        rawBusinessOwnerUid is String ? rawBusinessOwnerUid.trim() : null;
    return {
      'role': role,
      'businessOwnerUid':
          businessOwnerUid?.isNotEmpty == true ? businessOwnerUid! : user.uid,
    };
  }

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
      DBHelper.instance.setBusinessOwnerUid(credential.user!.uid);
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
    required String selectedRole,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final access = await loadAccessProfile();
      if (access['role'] != selectedRole) {
        await _clearFailedSignIn();
        return selectedRole == 'owner'
            ? 'Akun ini belum terdaftar sebagai Owner. Minta pengelola sistem mengatur perannya.'
            : 'Akun ini terdaftar sebagai Owner. Pilih masuk sebagai Owner.';
      }
      DBHelper.instance.setBusinessOwnerUid(access['businessOwnerUid']!);
      await _saveLocalProfile(
        credential.user?.displayName ?? '',
        credential.user?.email ?? email.trim().toLowerCase(),
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _messageFor(error);
    } on FirebaseException catch (error) {
      await _clearFailedSignIn();
      return _messageForFirebase(error);
    } catch (_) {
      await _clearFailedSignIn();
      return 'Login Firebase berhasil, tetapi sesi aplikasi gagal disiapkan. '
          'Periksa konfigurasi Firestore dan coba lagi.';
    }
  }

  static Future<void> _clearFailedSignIn() async {
    try {
      await signOut();
    } catch (_) {
      // Preserve the original login error if Firebase sign-out also fails.
    }
  }

  static Future<void> _saveLocalProfile(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    DBHelper.instance.setBusinessOwnerUid(null);
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

  static String _messageForFirebase(FirebaseException error) {
    if (error.plugin == 'cloud_firestore') {
      switch (error.code) {
        case 'permission-denied':
          return 'Login berhasil, tetapi Firestore menolak membaca profil akun. '
              'Terbitkan aturan Firestore dari file firestore.rules di Firebase Console.';
        case 'failed-precondition':
        case 'not-found':
          return 'Login berhasil, tetapi Cloud Firestore belum siap. '
              'Pastikan database Firestore sudah dibuat di project Firebase yang sama.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Login berhasil, tetapi Firestore tidak dapat dijangkau. '
              'Periksa koneksi internet lalu coba lagi.';
      }
    }
    return 'Login berhasil, tetapi layanan ${error.plugin} gagal menyiapkan sesi '
        '(${error.code}). ${error.message ?? 'Periksa konfigurasi Firebase.'}';
  }
}
