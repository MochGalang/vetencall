# VetenCall Backend - Panduan Setup (untuk Tim Server / TKJ)

Backend ini dibangun menggunakan **Node.js** dan **Express** untuk menjembatani aplikasi mobile (Flutter) dengan database **MariaDB/MySQL** milik server **Asterisk (SIP Realtime)**.

---

## 📋 Prasyarat di Server Asterisk
Pastikan komponen berikut sudah terpasang di server Asterisk Anda:
1. **Node.js** (Versi 16 atau lebih baru) & **NPM**.
2. **MariaDB/MySQL** (yang digunakan untuk Asterisk Realtime).
3. Modul **Asterisk Realtime (ARA)** diaktifkan agar membaca data dari tabel `sip_buddies` (biasanya dikonfigurasi melalui `/etc/asterisk/extconfig.conf` dan `/etc/asterisk/res_config_mysql.conf` / `res_odbc.conf`).

---

## 🚀 Langkah Instalasi & Menjalankan Backend

1. **Salin Folder Backend:**
   Upload atau salin seluruh isi folder `backend` ini ke server Asterisk Anda (kecuali folder `node_modules` jika ada).

2. **Konfigurasi Environment (`.env`):**
   * Salin file `.env.example` menjadi `.env`:
     ```bash
     cp .env.example .env
     ```
   * Edit file `.env` dan sesuaikan kredensial database MariaDB serta detail Asterisk ARI Anda:
     ```env
     PORT=3000
     DB_HOST=localhost
     DB_USER=asterisk
     DB_PASSWORD=voip
     DB_NAME=asterisk
     
     ARI_URL=http://localhost:8088
     ARI_USERNAME=asterisk
     ARI_PASSWORD=voip
     ARI_APP_NAME=vetencall
     ```

3. **Install Dependensi:**
   Jalankan perintah berikut di dalam direktori `backend` di server:
   ```bash
   npm install
   ```

4. **Jalankan Aplikasi:**
   Untuk development:
   ```bash
   npm start
   ```
   Untuk production (disarankan menggunakan **PM2** agar tetap berjalan di background):
   ```bash
   # Install pm2 jika belum ada
   npm install -g pm2
   
   # Jalankan backend
   pm2 start index.js --name "vetencall-backend"
   ```

---

## 🗄️ Inisialisasi Database Otomatis
Saat pertama kali dijalankan (`node index.js`), backend ini akan otomatis membuat tabel-tabel berikut jika belum ada di database Anda:
* `users` - Untuk data registrasi pengguna aplikasi mobile.
* `sip_buddies` - Untuk penyimpanan akun SIP secara realtime yang dibaca Asterisk.
* `conversations` - Untuk menyimpan ID percakapan chat.
* `messages` - Untuk riwayat pesan chat room.

*Catatan: Pastikan user database yang Anda gunakan memiliki hak akses untuk `CREATE TABLE`.*
