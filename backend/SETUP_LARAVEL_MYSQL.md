# Tahap pembuatan Fasnote dengan Laravel dan MySQL

## Arsitektur yang dibuat

- Flutter tetap menjadi aplikasi Android yang digunakan pengguna.
- Laravel 12 (PHP) menjadi backend/API yang menerima permintaan, memvalidasi data, dan mengatur hak akses.
- MySQL menjadi penyimpanan terpusat untuk akun, invoice, item invoice, pelanggan, produk, dan profil usaha.
- Laravel Sanctum menerbitkan token untuk login aplikasi Android.

Laravel bukan basis data: Laravel adalah framework backend, sedangkan MySQL adalah basis datanya. Aplikasi Flutter mengirim dan mengambil data melalui API Laravel.

## Tahap 1 — Siapkan perangkat pengembangan

Pasang PHP 8.2 atau lebih baru yang kompatibel dengan Laravel 12, Composer, XAMPP dengan MySQL, Flutter SDK, dan Android Studio/Android Emulator. Di komputer pengembangan ini PHP XAMPP terdeteksi 8.2.12, maka proyek memakai Laravel 12.

Pastikan Composer dan PHP dapat dipanggil dari terminal. Jalankan `php -v` dan `composer --version` untuk melihat versinya.

## Tahap 2 — Buat proyek Laravel dari awal

Perintah berikut adalah untuk membuat salinan proyek baru di folder kosong. Proyek yang sedang digunakan sudah berada di folder `backend`, jadi jangan jalankan perintah create-project di atas folder `backend` yang sudah ada.

Dari folder kerja baru:

    composer create-project laravel/laravel:^12.0 backend
    cd backend
    php artisan install:api

Perintah `install:api` menyiapkan routing API dan Laravel Sanctum. Pada proyek Fasnote ini, Laravel 12, Sanctum, route API, controller, model, dan migration sudah dibuat di folder `backend`.

## Tahap 3 — Buat database MySQL

1. Buka XAMPP Control Panel, lalu jalankan MySQL.
2. Buka `http://localhost/phpmyadmin`.
3. Buat database bernama `fasnote` dengan collation `utf8mb4_unicode_ci`.

Atau jalankan SQL di phpMyAdmin:

    CREATE DATABASE fasnote
      CHARACTER SET utf8mb4
      COLLATE utf8mb4_unicode_ci;

## Tahap 4 — Hubungkan Laravel ke MySQL

Buka `backend/.env` dan pastikan pengaturan lokal seperti berikut. Sesuaikan user/password jika konfigurasi MySQL berbeda:

    APP_NAME=Fasnote
    APP_ENV=local
    APP_DEBUG=true
    APP_URL=http://127.0.0.1:8000
    DB_CONNECTION=mysql
    DB_HOST=127.0.0.1
    DB_PORT=3306
    DB_DATABASE=fasnote
    DB_USERNAME=root
    DB_PASSWORD=

`backend/.env.example` berisi contoh konfigurasi yang boleh dibagikan. Jangan bagikan atau masukkan `backend/.env` ke Git karena file itu berisi konfigurasi lokal dan kunci aplikasi.

## Tahap 5 — Bentuk tabel dan siapkan penyimpanan gambar

Dari folder `backend`, jalankan:

    composer install
    php artisan key:generate
    php artisan migrate
    php artisan storage:link

Migration membuat tabel pengguna/token, pelanggan, produk, invoice, item invoice, dan profil usaha. Foto produk dan logo disimpan pada `backend/storage/app/public`, lalu diakses lewat folder `backend/public/storage`.

## Tahap 6 — Jalankan backend Laravel

Tetap dari folder `backend`, jalankan:

    php artisan serve --host=0.0.0.0 --port=8000

Biarkan terminal tetap terbuka. Periksa `http://127.0.0.1:8000/api/health`; respons yang diharapkan adalah `{"status":"ok"}`.

## Tahap 7 — Jalankan aplikasi Flutter di Android

Dari folder utama proyek Flutter (folder yang berisi `pubspec.yaml`):

    flutter pub get
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

Alamat `10.0.2.2` dipakai Android Emulator untuk mengakses komputer host. Untuk ponsel fisik, sambungkan komputer dan ponsel ke Wi-Fi yang sama, lalu gunakan alamat IPv4 komputer, misalnya:

    flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api

Ganti contoh IP dengan alamat komputer yang sebenarnya dan izinkan port 8000 di firewall bila diperlukan. HTTP hanya untuk pengembangan lokal; server produksi perlu domain HTTPS.

## Tahap 8 — Alur penyimpanan data

1. Pengguna daftar atau masuk melalui API Laravel.
2. Laravel memeriksa akun dan memberikan token Sanctum.
3. Aplikasi mengirim token saat membaca atau mengubah data.
4. Laravel hanya mengakses data milik akun yang sedang masuk.
5. Data tersimpan di MySQL, sehingga dapat dipakai lagi dari perangkat lain setelah masuk dengan akun yang sama.

Endpoint utama yang sudah dibuat:

| Fitur | Endpoint |
|---|---|
| Status server | `GET /api/health` |
| Daftar / masuk / keluar | `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/logout` |
| Pelanggan | `GET/POST /api/customers`, `PUT/DELETE /api/customers/{id}` |
| Produk | `GET/POST /api/products`, `PUT/DELETE /api/products/{id}` |
| Invoice dan item | `GET/POST /api/invoices`, `GET/PUT/DELETE /api/invoices/{id}` |
| Laporan rentang tanggal | `GET /api/invoices?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD` |
| Profil usaha | `GET/PUT /api/business-profile` |

## Tahap 9 — Website dan pemindahan data lama

Backend API ini dapat dipakai oleh aplikasi Android dan website. Halaman website Laravel (misalnya dashboard Blade untuk laporan dan persediaan) belum dibuat dalam tahap ini, sehingga masih perlu dikerjakan agar hasil akhirnya memenuhi judul skripsi berbasis website.

Data SQLite yang sudah ada di instalasi lama tidak otomatis disalin ke MySQL. Salin atau ekspor data penting terlebih dahulu; jika data lama perlu dipindahkan, buat dan jalankan proses impor terpisah sebelum menghapus aplikasi lama.

CORS saat ini dikonfigurasi untuk pengembangan lokal. Sebelum dipasang di internet, batasi `CORS_ALLOWED_ORIGINS`, gunakan HTTPS, matikan `APP_DEBUG`, dan siapkan kredensial database produksi.