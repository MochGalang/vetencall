# [Automasi Pembuatan Akun PJSIP]

Saat ini, pendaftaran akun di aplikasi hanya tersimpan di database MySQL (`sip_buddies`), tetapi server Asterisk Anda menggunakan **PJSIP** dengan konfigurasi statis manual. Untuk mengotomatiskan proses ini, ada dua arsitektur yang bisa dipilih oleh tim backend/server Anda. 

## Open Questions
Pilihan mana yang lebih disukai oleh teman Anda (Tim Server)?

1. **Opsi A: Realtime Database (Direkomendasikan, Scalable)**
   Backend Node.js akan meng-INSERT data ke dalam tabel database khusus PJSIP (`ps_endpoints`, `ps_aors`, `ps_auths`). Server Asterisk lalu dikonfigurasi untuk membaca database ini secara otomatis (menggunakan *Asterisk Sorcery*). Tidak perlu melakukan reload server setiap ada akun baru.

2. **Opsi B: File Generation + Auto Reload (Lebih Mudah Diterapkan)**
   Backend Node.js akan otomatis menulis teks konfigurasi ke dalam sebuah file (misal: `pjsip_custom.conf`), lalu Node.js akan otomatis menjalankan perintah `asterisk -rx 'pjsip reload'` di server untuk me-refresh sistem tanpa mematikan panggilan yang sedang berjalan.

## Proposed Changes

### Opsi A (Jika memilih Database Realtime)
#### [MODIFY] `backend/backend_updated.js`
- Menghapus query ke tabel `sip_buddies`.
- Menambahkan query INSERT ke tabel `ps_endpoints`, `ps_auths`, dan `ps_aors`.

**Tugas Teman Anda (Server):**
- Mengatur koneksi ODBC MySQL di Asterisk.
- Mengatur `sorcery.conf` dan `extconfig.conf` agar PJSIP membaca dari MySQL.

### Opsi B (Jika memilih File Generation)
#### [MODIFY] `backend/backend_updated.js`
- Mengimpor library `fs` (File System) dan `child_process`.
- Menambahkan fungsi untuk menulis format PJSIP (`[ekstensi] type=endpoint ...`) ke file `/etc/asterisk/pjsip_custom.conf`.
- Menjalankan `exec("asterisk -rx 'pjsip reload'")` secara otomatis.

**Tugas Teman Anda (Server):**
- Menambahkan baris `#include pjsip_custom.conf` di dalam file `pjsip.conf` Asterisk.
- Memberikan izin (permission) agar aplikasi Node.js bisa mengeksekusi perintah `asterisk -rx`.

## User Review Required
> [!IMPORTANT]
> Silakan teruskan rencana ini ke teman Anda (Tim Server), dan tanyakan kepadanya **Opsi mana yang ingin dia gunakan (Opsi A atau Opsi B)?**
> Setelah Anda memilih salah satu opsi, klik **Proceed** atau beritahu saya di chat, dan saya akan menuliskan kode backend-nya untuk Anda!
