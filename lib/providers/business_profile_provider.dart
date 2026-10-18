import 'dart:async';

import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/business_profile.dart';

/// Business profile state backed by the authenticated API.
class BusinessProfileProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  BusinessProfile _profile = BusinessProfile();
  bool _isLoading = false;
  bool lastLogoUploadFailed = false;
  String? lastLogoUploadError;
  bool lastLogoStoredInFirestore = false;
  String? lastSaveError;

  BusinessProfile get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _dbHelper.getBusinessProfile();
      if (data != null) _profile = BusinessProfile.fromMap(data);
    } catch (error) {
      debugPrint('Error loading business profile: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile(BusinessProfile profile) async {
    lastLogoUploadFailed = false;
    lastLogoUploadError = null;
    lastLogoStoredInFirestore = false;
    lastSaveError = null;
    try {
      final saved = await _dbHelper
          .saveBusinessProfile(profile.toMap())
          .timeout(const Duration(seconds: 28));
      if (saved == null) {
        lastSaveError =
            'Data profil tidak dapat dibaca kembali setelah disimpan.';
        return false;
      }
      lastLogoUploadFailed = saved.remove('_logo_upload_failed') == true;
      lastLogoUploadError = saved.remove('_logo_upload_error')?.toString();
      lastLogoStoredInFirestore =
          saved.remove('_logo_stored_in_firestore') == true;
      _profile = BusinessProfile.fromMap(saved);
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Error saving business profile: $error');
      lastSaveError = error is TimeoutException
          ? 'Penyimpanan melewati batas waktu. Periksa koneksi internet lalu coba lagi.'
          : 'Profil gagal disimpan. Periksa koneksi dan pengaturan Firebase lalu coba lagi.';
      return false;
    }
  }
}
