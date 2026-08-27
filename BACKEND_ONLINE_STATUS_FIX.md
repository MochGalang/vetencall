# Panduan Perbaikan Bug Status Online/Offline (Untuk Backend Developer)

Dokumen ini berisi panduan teknis untuk Backend Developer guna memperbaiki masalah status "Offline" palsu saat user membuka halaman chat dari daftar Kontak.

---

## 🛑 Akar Masalah
Saat ini, aplikasi Flutter (Frontend) sangat bergantung pada data inisial `is_online` saat menavigasi ke halaman chat. Namun, endpoint `/api/contacts` (dan `/api/conversations`) hanya mengambil data dari database MySQL (`users` / `conversations`), dan **tidak menyertakan status online *real-time* user** di *response JSON*. 

Karena `is_online` tidak ada di data kontak, Frontend terpaksa berasumsi bahwa kontak tersebut sedang `Offline`.

## 🛠 Solusi (Implementasi di Node.js)
Karena kamu sudah menyimpan daftar koneksi WebSocket aktif di variabel memori global:
```javascript
const clients = new Map(); // Map untuk menyimpan userId -> Set<WebSocket>
```
Kamu hanya perlu "menyisipkan" status aktif dari `clients` Map ini ke dalam *response* API yang mengambil daftar kontak atau obrolan.

### 1. Perbaikan pada Endpoint `/api/contacts`
Cari endpoint `app.get('/api/contacts', ...)` di `index.js`, lalu ubah bagian `res.json` menjadi seperti ini:

**Sebelumnya:**
```javascript
const [contacts] = await pool.query("SELECT id, username, sip_username FROM users WHERE id != ?", [userId]);
res.json({ success: true, data: contacts.map(c => ({ id: c.id.toString(), username: c.username, sip_username: c.sip_username })) });
```

**Ubah Menjadi:**
```javascript
const [contacts] = await pool.query("SELECT id, username, sip_username FROM users WHERE id != ?", [userId]);

// Sisipkan status is_online dari memori WebSocket (clients Map)
const enrichedContacts = contacts.map(c => {
    const contactIdStr = c.id.toString();
    const isOnline = clients.has(contactIdStr) && clients.get(contactIdStr).size > 0;
    
    return { 
        id: contactIdStr, 
        username: c.username, 
        sip_username: c.sip_username,
        is_online: isOnline // <-- Data baru yang dibutuhkan frontend
    };
});

res.json({ success: true, data: enrichedContacts });
```

### 2. Perbaikan pada Endpoint `/api/conversations` (Jika Belum Ada)
Lakukan hal yang sama pada `app.get('/api/conversations', ...)`. Pastikan sebelum membalas `res.json({ success: true, data: convs })`, kamu memetakan array `convs` untuk menambahkan `is_online`:

```javascript
// Setelah query SELECT dari database selesai
const enrichedConvs = convs.map(c => {
    const contactIdStr = c.contact_id.toString();
    const isOnline = clients.has(contactIdStr) && clients.get(contactIdStr).size > 0;
    
    return {
        ...c,
        is_online: isOnline // <-- Tambahkan ini
    };
});

res.json({ success: true, data: enrichedConvs });
```

---

### Hasil Akhir
Dengan perbaikan di atas, setiap kali frontend memanggil `/api/contacts` atau `/api/conversations`, aplikasi akan langsung mengetahui secara *real-time* apakah lawan bicaranya sedang terhubung ke WebSocket atau tidak, sehingga tidak ada lagi asumsi "Offline" secara *default*.
