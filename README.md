# Fasnota

Fasnota adalah aplikasi Flutter yang dapat dijalankan di Android dan web. Login menggunakan Firebase Authentication, sedangkan invoice, pelanggan, produk, persediaan, dan profil usaha disimpan di Cloud Firestore per akun pengguna.

## Menyiapkan dan menjalankan

Ikuti [panduan konfigurasi Firebase](FIREBASE_SETUP.md). Panduan tersebut mencakup konfigurasi Android/web, aturan keamanan Firestore, menjalankan aplikasi, dan membuat versi web.

## Fitur yang tersedia

- Buat dan kelola invoice; invoice yang dibuat dari katalog produk mengurangi stok secara otomatis.
- Tetapkan stok awal saat produk dibuat dan catat stok masuk dari halaman Data Barang.
- Batalkan atau ubah invoice untuk menyesuaikan kembali stok secara otomatis.
- Lihat rekap penjualan berdasarkan rentang tanggal.
- Ekspor rekap ke Excel dan PDF.
- Data cloud dibatasi per akun Firebase yang sedang masuk.

Baris invoice yang dimasukkan manual tanpa memilih produk katalog tidak mengubah stok. Data lokal/SQLite dan MySQL lama tidak otomatis dipindahkan ke Firestore.

Folder `backend/` berisi percobaan Laravel/MySQL sebelumnya dan tidak dipakai oleh aplikasi Flutter pada konfigurasi saat ini.
