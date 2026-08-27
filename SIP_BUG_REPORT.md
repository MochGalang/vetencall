# Laporan Bug SIP Backend & Solusinya

Dokumen ini berisi analisis penyebab utama dua kendala SIP (Telepon/WebRTC) yang terjadi di frontend dan instruksi untuk memperbaikinya di sisi backend/server (Asterisk).

---

## 🛑 Bug 1: Error `Auth gagal beruntun` (Gagal Login SIP)

**Gejala:** 
Saat membuat akun baru, telepon bisa terhubung (berstatus `Registered`). Tapi jika mencoba login kembali menggunakan akun lama (atau setelah logout), selalu muncul error `Auth gagal beruntun` dan status SIP tidak bisa registered.

**Penyebab Utama (Akar Masalah):**
Terdapat celah logika pada endpoint API backend saat memproses password SIP.
1. Saat `/api/register`: Backend membuat `sip_password` berupa teks asli (*plaintext*) secara random, lalu menyimpannya ke tabel `sip_buddies` (untuk Asterisk) dan mengenkripsinya (Bcrypt Hash) ke tabel `users`.
2. Saat `/api/login`: Backend mengambil data dari tabel `users` dan mengembalikan nilai `sip_password` (yang sudah dalam bentuk **Hash**) ke aplikasi Flutter.
3. Aplikasi Flutter mencoba login ke server Asterisk menggunakan **Hash** tersebut. Tentu saja server Asterisk menolak (merespons `401 Unauthorized` berulang kali) karena Asterisk mencocokkannya dengan password *plaintext*.

**Cara Memperbaiki (Solusi Backend):**
Karena *hash* bcrypt tidak bisa dikembalikan menjadi *plaintext*, cara terbaik adalah mengambil password asli dari tabel `sip_buddies` saat pengguna melakukan login.

Ubah kode di `/api/login` (pada `backend/index.js`), dari yang sebelumnya hanya query ke tabel `users`, tambahkan *JOIN* atau query terpisah ke tabel `sip_buddies` untuk mengambil `secret` (password SIP yang asli).

*Contoh Perbaikan di `/api/login`:*
```javascript
// Setelah menemukan user di tabel users:
const sip_username = user.sip_username;

// Ambil password asli dari sip_buddies
const [buddies] = await pool.query(
    "SELECT secret FROM sip_buddies WHERE name = ?",
    [sip_username]
);

const plaintext_sip_password = buddies.length > 0 ? buddies[0].secret : user.sip_password;

res.json({
    success: true,
    data: {
        id: user.id.toString(),
        username: user.username,
        phone_number: user.phone_number,
        sip_username: user.sip_username,
        sip_password: plaintext_sip_password // <--- Kirim plaintext ke frontend, JANGAN kirim hash
    }
});
```

---

## 🛑 Bug 2: Panggilan Langsung Tertutup / Error `404 Not Found` (Hangup)

**Gejala:** 
Meskipun pengguna berhasil terdaftar di SIP (`✅ Registered!`), namun saat menekan tombol telepon, log menampilkan pesan `[SIP] << SIP/2.0 404 Not Found`, dan panggilan langsung otomatis ditutup (hangup).

**Penyebab Utama (Akar Masalah):**
Server Asterisk menolak meneruskan panggilan (INVITE) dan merespons dengan 404 Not Found. Hal ini terjadi karena 2 kemungkinan utama:
1. Penelepon memanggil Ekstensi (Sip Username) yang saat itu sedang Offline atau tidak terdaftar (*Unregistered*) di server Asterisk.
2. Server Asterisk belum dikonfigurasi (*Dialplan/Routing*) untuk bisa menghubungkan panggilan antar nomor ekstensi.

**Cara Memperbaiki (Solusi Server/Asterisk):**
Temanmu (Backend/Sysadmin) harus mengecek hal-hal berikut di Server Asterisk:

1. **Pastikan Akun Lawan Aktif & Online:** Saat melakukan tes telepon, **KEDUA PENGGUNA** (Penelepon & Penerima) harus sedang membuka aplikasinya dan log-nya menampilkan `✅ Registered!`. (Bisa dicek via CLI Asterisk dengan command `sip show peers` atau `pjsip show endpoints`).
2. **Cek Konfigurasi Dialplan (`extensions.conf`):**
   Di `backend/index.js`, terlihat saat registrasi akun baru dimasukkan ke context `internal` (`context = 'internal'`). 
   Pastikan di file `/etc/asterisk/extensions.conf` milik Asterisk terdapat rule untuk merutekan panggilan (Dial) di dalam *context* `internal`.

*Contoh minimal konfigurasi Dialplan yang BENAR (jika memakai driver chan_sip):*
```ini
[internal]
; Jika user di context internal menelpon ekstensi berapapun (_X.),
; maka sambungkan panggilan melalui SIP.
exten => _X.,1,Dial(SIP/${EXTEN},60)
exten => _X.,n,Hangup()
```
*(Catatan: Sesuaikan bagian `Dial(SIP...)` menjadi `Dial(PJSIP...)` jika backend menggunakan PJSIP alih-alih chan_sip).*

---

### Kesimpulan untuk Backend Developer:
1. **Perbaiki `/api/login`:** Jangan kirimkan `sip_password` berupa **hash bcrypt** ke frontend. Kirimkan teks asli (plaintext) dari field `secret` di tabel `sip_buddies`.
2. **Periksa Asterisk:** Pastikan file konfigurasi `extensions.conf` memiliki context `[internal]` yang berisi perintah `Dial()` agar ekstensi-ekstensi bisa saling menelepon.
