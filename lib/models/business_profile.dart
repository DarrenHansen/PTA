import 'dart:convert';
import 'dart:typed_data';

import 'bank_account.dart';

/// Data profil usaha yang disimpan di Cloud Firestore.
class BusinessProfile {
  int? id;
  String businessName;
  String businessAddress;
  String businessPhone;
  String businessEmail;
  String logoPath;
  String logoBase64;
  Uint8List? logoBytes;
  List<BankAccount> bankAccounts;
  String notes;

  BusinessProfile({
    this.id,
    this.businessName = '',
    this.businessAddress = '',
    this.businessPhone = '',
    this.businessEmail = '',
    this.logoPath = '',
    this.logoBase64 = '',
    this.logoBytes,
    this.bankAccounts = const [],
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'business_name': businessName,
        'business_address': businessAddress,
        'business_phone': businessPhone,
        'business_email': businessEmail,
        'logo_path': logoPath,
        'logo_base64': logoBase64,
        'logo_bytes': logoBytes,
        'bank_accounts':
            bankAccounts.map((account) => account.toMap()).toList(),
        'notes': notes,
      };

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    dynamic rawAccounts = map['bank_accounts'];
    if (rawAccounts is String && rawAccounts.isNotEmpty) {
      try {
        rawAccounts = jsonDecode(rawAccounts);
      } catch (_) {
        rawAccounts = const [];
      }
    }
    final accounts = rawAccounts is List ? rawAccounts : const [];
    return BusinessProfile(
      id: (map['id'] as num?)?.toInt(),
      businessName: map['business_name']?.toString() ?? '',
      businessAddress: map['business_address']?.toString() ?? '',
      businessPhone: map['business_phone']?.toString() ?? '',
      businessEmail: map['business_email']?.toString() ?? '',
      logoPath: map['logo_path']?.toString() ?? '',
      logoBase64: map['logo_base64']?.toString() ?? '',
      bankAccounts: accounts
          .whereType<Map>()
          .map((account) =>
              BankAccount.fromMap(Map<String, dynamic>.from(account)))
          .toList(),
      notes: map['notes']?.toString() ?? '',
    );
  }

  BusinessProfile copyWith({
    int? id,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? logoPath,
    String? logoBase64,
    Uint8List? logoBytes,
    List<BankAccount>? bankAccounts,
    String? notes,
  }) =>
      BusinessProfile(
        id: id ?? this.id,
        businessName: businessName ?? this.businessName,
        businessAddress: businessAddress ?? this.businessAddress,
        businessPhone: businessPhone ?? this.businessPhone,
        businessEmail: businessEmail ?? this.businessEmail,
        logoPath: logoPath ?? this.logoPath,
        logoBase64: logoBase64 ?? this.logoBase64,
        logoBytes: logoBytes ?? this.logoBytes,
        bankAccounts: bankAccounts ?? this.bankAccounts,
        notes: notes ?? this.notes,
      );

  bool get isEmpty => businessName.isEmpty && businessAddress.isEmpty;
}
