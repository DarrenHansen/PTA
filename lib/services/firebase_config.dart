import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Public client configuration for the Firebase Web app. Environment values
  // can override these defaults for another Firebase project/build.
  static const _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDSS9q2t1N5m7s98Q60o4RBIV6UYpL_lFI',
  );
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'pta1-bd19f',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '717099556688',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'pta1-bd19f.firebasestorage.app',
  );
  static const _webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:717099556688:web:bac964610e1217ce9a1655',
  );
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'pta1-bd19f.firebaseapp.com',
  );

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      (kIsWeb ? _webAppId.isNotEmpty : _androidAppId.isNotEmpty);

  static bool get hasStorage => _storageBucket.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError('Konfigurasi Firebase belum diisi.');
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: kIsWeb ? _webAppId : _androidAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain:
          _authDomain.isEmpty ? '$_projectId.firebaseapp.com' : _authDomain,
      storageBucket: hasStorage ? _storageBucket : null,
    );
  }
}
