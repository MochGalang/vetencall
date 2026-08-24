# Request Fitur Baru: Sinkronisasi Kontak ala WhatsApp

**Dari:** Tim Frontend  
**Untuk:** Tim Backend  
**Status:** Diskusi & Perencanaan  

---

## 📱 Rencana Fitur Baru

Kita berencana mengubah sistem pertemanan/kontak di VetenCall agar mirip dengan WhatsApp. 
Alurnya nanti seperti ini:

1. Aplikasi (Frontend) akan meminta izin membaca kontak bawaan dari HP user.
2. Frontend akan mengambil **semua nomor** yang ada di kontak HP user.
3. Frontend mengirim daftar nomor tersebut ke Backend.
4. Backend mengecek nomor mana saja yang **sudah terdaftar** sebagai user di VetenCall.
5. Backend mengembalikan daftar user tersebut ke Frontend untuk ditampilkan sebagai kontak.

---

## ⚠️ TANTANGAN: Kita Menggunakan SIP Username, Bukan Nomor Telepon

WhatsApp bisa melakukan pencocokan karena user mendaftar menggunakan nomor HP asli, dan teman-temannya menyimpan nomor HP asli tersebut di kontak mereka.

Namun, di VetenCall, kita menggunakan **SIP Username** (seperti ekstensi, misal "888"). 

Oleh karena itu, kita punya **dua opsi arsitektur** yang harus kita sepakati sebelum fitur ini bisa dibuat:

### Opsi 1: Kita Mulai Menyimpan Nomor Telepon Asli (Sangat Disarankan)
- **Cara Kerja:** Saat user baru mendaftar VetenCall, selain membuat `sip_username`, user juga **diwajibkan memasukkan nomor telepon asli (HP)**. Nomor ini disimpan di database.
- **Pencocokan:** Saat frontend mengirim daftar nomor kontak HP, backend akan mencarinya di kolom `phone_number`.
- **Kelebihan:** Sangat natural bagi user. Cara kerjanya persis 100% seperti WhatsApp.

### Opsi 2: Menjadikan SIP Username sebagai "Nomor Telepon"
- **Cara Kerja:** Kita tidak menyimpan nomor HP asli. Sebagai gantinya, user harus menyimpan teman mereka di kontak bawaan HP dengan memasukkan `sip_username` (misal: "888") di kolom nomor telepon.
- **Pencocokan:** Saat frontend mengirim daftar "nomor" dari HP, backend akan mencocokkannya dengan kolom `sip_username` di database.
- **Kekurangan:** Sedikit membingungkan bagi user awam, karena mereka harus menyimpan "nomor pendek" (SIP) di kontak HP mereka agar terdeteksi di VetenCall.

---

## ❓ Task untuk Backend

Silakan putuskan kita akan menggunakan Opsi 1 atau Opsi 2. 

Apapun opsinya, aku butuh satu endpoint baru untuk melakukan sinkronisasi massal:

**Target Endpoint:** `POST /api/contacts/sync`

**Contoh Request dari Frontend:**
Frontend akan mengirim array berisi nomor-nomor yang didapat dari kontak HP.
```json
{
  "user_id": "123", // ID user yang sedang login
  "phone_numbers": [
    "081234567890", // Jika pakai Opsi 1
    "1002",         // Jika pakai Opsi 2
    "1005"
  ]
}
```

**Logika di Backend:**
Backend melakukan query ke tabel `users` untuk mencari user mana saja yang cocok dengan array tersebut.
- *Jika Opsi 1:* `WHERE phone_number IN (...)`
- *Jika Opsi 2:* `WHERE sip_username IN (...)`

**Contoh Response yang diharapkan (jika sukses):**
```json
{
  "success": true,
  "data": [
    {
      "id": "456",
      "username": "Budi",
      "sip_username": "1002"
    },
    {
      "id": "789",
      "username": "Siti",
      "sip_username": "1005"
    }
  ]
}
```

---

## 💬 Next Step

Tolong diskusikan soal pemilihan Opsi 1 vs Opsi 2 ini. Kalau database kita sudah siap dan kamu sudah bisa membuatkan endpoint `/api/contacts/sync` dengan spesifikasi di atas, kabari aku biar aku bisa langsung garap UI dan logika sinkronisasinya di Flutter (Frontend).

Thank you! 🚀
