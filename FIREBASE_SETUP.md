# Menyiapkan Fasnote dengan Firebase

Fasnote memakai Flutter untuk Android dan web. Firebase Authentication menangani akun, Cloud Firestore menyimpan data, dan Cloud Storage bersifat opsional untuk gambar produk/logo. XAMPP, PHP, Laravel, dan MySQL tidak dibutuhkan untuk menjalankan konfigurasi ini.

## 1. Buat layanan Firebase

1. Buat project di Firebase Console.
2. Pada **Authentication → Sign-in method**, aktifkan **Email/Password**.
3. Buat database **Cloud Firestore** dalam production mode. Pilih region yang dekat dengan pengguna; lokasi database tidak dapat diubah setelah dibuat.
4. Di **Project settings → Your apps**, daftarkan aplikasi Android menggunakan `applicationId` dari `android/app/build.gradle` (atau `build.gradle.kts`) dan daftarkan aplikasi web.
5. Catat nilai API key, Project ID, Messaging Sender ID, App ID web, dan App ID Android dari Project settings. Untuk web, isikan juga Auth domain (`<project-id>.firebaseapp.com`) jika disediakan.

> Jangan masukkan service-account private key ke aplikasi. Nilai konfigurasi Firebase client bukan pengganti aturan keamanan; akses database dilindungi oleh Authentication dan rules.

## 2. Terapkan aturan Firestore

File `firestore.rules` membatasi akses data per toko. Kasir yang terdaftar dapat mengelola data toko, sedangkan akun Owner hanya dapat membacanya. Peran disimpan di koleksi `user_roles` dan hanya dapat diatur melalui Firebase Console oleh administrator. File `firebase.json` menunjuk ke rules dalam repositori ini. Pasang Firebase CLI dan login, lalu dari direktori proyek jalankan:

```powershell
firebase use --add
firebase deploy --only firestore:rules
```

Pilih project Firebase yang sama saat `firebase use --add`. Jika belum memakai Firebase CLI, salin isi `firestore.rules` ke **Firestore Database → Rules** di Console dan terbitkan rules tersebut.

## 3. Atur akun Owner dan Kasir

1. Buat akun melalui halaman Daftar Fasnote. Akun baru berperan sebagai Kasir sampai dipetakan ke toko.
2. Buka **Authentication → Users** dan salin UID akun.
3. Buka **Firestore Database → Data**, buat koleksi `user_roles`, lalu gunakan UID sebagai ID dokumen.
4. Untuk akun Owner, buat field `role` bertipe string bernilai `owner` dan `businessOwnerUid` bertipe string berisi UID akun Owner itu sendiri.
5. Untuk akun Kasir, buat field `role` bertipe string bernilai `cashier` dan `businessOwnerUid` bertipe string berisi UID Owner tokonya.
6. Terbitkan rules terbaru. Akun Kasir dan Owner kemudian membaca data toko yang berada di `users/{UID Owner}`. Owner hanya mendapat tampilan Barang, Stok, dan Laporan; rules juga menolak perubahan data dari akun Owner.

Rules menolak perubahan dokumen `user_roles` dari aplikasi. Pengaturan peran harus dilakukan oleh administrator di Firebase Console.

## 4. (Opsional) Aktifkan penyimpanan gambar

Foto produk dan logo memakai Firebase Storage. Fitur data lain—akun, invoice, laporan, produk dan stok—tetap dapat dipakai tanpa Storage; jangan pilih gambar bila Storage belum disiapkan.

Untuk mengaktifkan foto, buat bucket Storage di Firebase Console, lalu terapkan `storage.rules` melalui tab Rules atau Firebase CLI:

```powershell
firebase deploy --only storage
```

Periksa halaman harga Firebase sebelum mengaktifkan Storage: pembuatan bucket baru untuk Cloud Storage for Firebase memerlukan paket Blaze (pay-as-you-go) dan penggunaan dapat menimbulkan biaya. Jangan aktifkan paket tersebut tanpa menyetujui ketentuan tagihan.

## 5. Jalankan aplikasi

Buka PowerShell di direktori proyek dan jalankan untuk web:

```powershell
flutter pub get
flutter run -d chrome
```

Konfigurasi Web dari project PTA1 sudah menjadi nilai bawaan di `lib/services/firebase_config.dart`. Untuk Android, daftarkan aplikasi Android dengan package name `com.example.aplikasi_invoice`, lalu jalankan dengan App ID Android yang diperoleh dari Console:

```powershell
flutter run -d emulator-5554 --dart-define=FIREBASE_ANDROID_APP_ID=ANDROID_APP_ID_ANDA
```

Bucket bawaan project `pta1-bd19f` sudah diatur di aplikasi sebagai `pta1-bd19f.firebasestorage.app`. Jika memakai bucket lain, tambahkan `--dart-define=FIREBASE_STORAGE_BUCKET=BUCKET_ANDA` pada perintah. Untuk login web, tambahkan domain hosting ke **Authentication → Settings → Authorized domains**.

## 6. Buat dan pasang website

Jalankan perintah build berikut:

```powershell
flutter build web
```

Hasil website statis berada di `build/web`. Folder itu dapat dipasang pada Firebase Hosting atau penyedia hosting statis lain. Tambahkan domain hosting ke daftar Authorized domains. Firebase Auth dan Firestore yang sama akan menyajikan data yang sama pada aplikasi Android dan website setelah pengguna masuk dengan akun yang sesuai.

## Catatan data

Penggantian backend ke Firestore tidak menyalin database lama secara otomatis. Produk, pelanggan, profil, dan invoice sebelumnya perlu diimpor dengan proses migrasi tersendiri bila datanya akan dipertahankan. Data toko disimpan dalam ruang UID Owner; akun Kasir yang dipetakan ke toko tersebut menggunakan data yang sama.
