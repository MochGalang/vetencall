# Panduan Perbaikan Backend VetenCall (Node.js & Asterisk)

Halo! Ada 2 perbaikan penting yang perlu diterapkan di sisi backend (server) agar fitur aplikasi berjalan sempurna di sisi klien (Flutter).

## 1. Perbaikan Fitur Video Call (WebRTC SDP Video)
**Masalah:** Saat ini ketika user menelpon dengan kamera (Video Call), backend Asterisk membuang (strip) baris video (`m=video`) pada pesan SDP yang diteruskan. Ini terjadi karena saat registrasi (pembuatan akun SIP di tabel `sip_buddies`), kolom konfigurasi video tidak disertakan. Akibatnya fitur Video Call nyangkut jadi Voice Call.

**Solusi:** Update fungsi inisialisasi database dan endpoint registrasi di `index.js`.

**A. Pada Fungsi `initDb()`**
Tambahkan pembuatan kolom baru untuk konfigurasi video di bagian pengecekan kolom lama (setelah proses `CREATE TABLE`):
```javascript
// Tambahkan 4 pengecekan kolom ini untuk izin video
await pool.query("SHOW COLUMNS FROM sip_buddies LIKE 'videosupport'").then(async ([rows]) => {
    if (rows.length === 0) await pool.query("ALTER TABLE sip_buddies ADD COLUMN videosupport VARCHAR(10) DEFAULT 'yes'");
});
await pool.query("SHOW COLUMNS FROM sip_buddies LIKE 'max_video_streams'").then(async ([rows]) => {
    if (rows.length === 0) await pool.query("ALTER TABLE sip_buddies ADD COLUMN max_video_streams INT DEFAULT 1");
});
await pool.query("SHOW COLUMNS FROM sip_buddies LIKE 'allow'").then(async ([rows]) => {
    if (rows.length === 0) await pool.query("ALTER TABLE sip_buddies ADD COLUMN allow VARCHAR(255) DEFAULT 'vp8,vp9,h264,ulaw,alaw,opus'");
});
await pool.query("SHOW COLUMNS FROM sip_buddies LIKE 'disallow'").then(async ([rows]) => {
    if (rows.length === 0) await pool.query("ALTER TABLE sip_buddies ADD COLUMN disallow VARCHAR(255) DEFAULT 'all'");
});
```

**B. Pada Endpoint `app.post('/api/register', ...)`**
Ubah query `INSERT INTO sip_buddies` agar kolom-kolom baru di atas ikut dimasukkan. Replace query lamanya dengan ini:
```javascript
await pool.query(
    `INSERT INTO sip_buddies (name, host, secret, context, username, type, avpf, icesupport, encryption, rtcp_mux, transport, nat, videosupport, max_video_streams, disallow, allow) 
    VALUES (?, 'dynamic', ?, 'internal', ?, 'friend', 'yes', 'yes', 'yes', 'yes', 'ws,udp', 'yes', 'yes', 1, 'all', 'vp8,vp9,h264,ulaw,alaw,opus')`,
    [sip_username, sip_password, sip_username]
);
```

---

## 2. Perbaikan Sorting Daftar Chat (Seperti WhatsApp)
**Masalah:** Saat ini tampilan daftar chat (HomeChat) tidak mengambil data pesan terakhir dan tidak diurutkan berdasarkan waktu ngechat terbaru.

**Solusi:** Update endpoint `/api/conversations` di `index.js` agar mengambil `last_message`, `last_message_time`, dan di-sort (ORDER BY).

**Replace seluruh endpoint `app.get('/api/conversations', ...)` lama dengan kode ini:**
```javascript
app.get('/api/conversations', async (req, res) => {
    const userId = req.query.user_id;
    try {
        const [convs] = await pool.query(`
            SELECT 
                c.id as conversation_id, 
                u.id as contact_id, 
                u.username as contact_username, 
                u.sip_username as contact_sip_username,
                c.created_at,
                (SELECT content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_time
            FROM conversations c 
            JOIN users u ON (c.user1_id = u.id OR c.user2_id = u.id) 
            WHERE (c.user1_id = ? OR c.user2_id = ?) AND u.id != ?
            ORDER BY COALESCE(last_message_time, c.created_at) DESC
        `, [userId, userId, userId]);
        
        res.json({ 
            success: true, 
            data: convs.map(c => ({ 
                id: c.conversation_id.toString(), 
                contact_id: c.contact_id.toString(),
                contact_name: c.contact_username, 
                contact_sip_username: c.contact_sip_username,
                last_message: c.last_message,
                last_message_time: c.last_message_time || c.created_at,
                unread_count: 0
            })) 
        });
    } catch (error) {
        console.error('[API] Error getting conversations:', error);
        res.json({ success: false, data: [] });
    }
});
```

---
**Catatan Akhir:** 
Setelah meng-update file `index.js`, **wajib restart service Node.js-nya**. Untuk sistem Asterisk, user yang sudah telanjur mendaftar sebelumnya perlu dihapus dan register ulang, atau nilainya harus diedit manual (ubah `max_video_streams` ke 1) langsung di database MariaDB/MySQL. Untuk user baru yang daftar setelah update ini diterapkan, semuanya akan otomatis beres!

---

## 3. Perbaikan Badge Notifikasi Pesan Belum Dibaca (Unread Count)

**Masalah:** Badge angka di daftar chat tidak pernah hilang karena backend tidak menyimpan status "sudah dibaca" per pesan, sehingga `unread_count` selalu 0 atau tidak akurat.

**Solusi:**

### A. Tambahkan Kolom `is_read` di Tabel `messages`
Jalankan SQL ini di database kamu:
```sql
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMP NULL;
```

### B. Tambahkan Endpoint Baru `POST /api/chat/read`
Tambahkan endpoint ini di `index.js`. Endpoint ini dipanggil Flutter setiap kali user membuka percakapan:
```javascript
app.post('/api/chat/read', async (req, res) => {
    const { conversation_id, user_id } = req.body;
    if (!conversation_id || !user_id) {
        return res.json({ success: false, message: 'conversation_id dan user_id wajib diisi' });
    }
    try {
        // Update semua pesan di conversation ini yang BUKAN dari user sendiri menjadi sudah dibaca
        await pool.query(
            `UPDATE messages SET is_read = TRUE, read_at = NOW() 
             WHERE conversation_id = ? AND sender_id != ? AND (is_read = FALSE OR is_read IS NULL)`,
            [conversation_id, user_id]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('[API] Error marking messages as read:', error);
        res.json({ success: false });
    }
});
```

### C. Update Endpoint `/api/conversations` agar Mengembalikan `unread_count` yang Akurat

Ubah bagian SELECT di endpoint conversations (dari **Perbaikan #2** di atas), tambahkan subquery `unread_count`:
```javascript
// Ganti baris: unread_count: 0
// Dengan ini di SELECT query-nya:
(SELECT COUNT(*) FROM messages m 
 WHERE m.conversation_id = c.id 
 AND m.sender_id != ${userId} 
 AND (m.is_read = FALSE OR m.is_read IS NULL)) as unread_count
```

Sehingga bagian `data` response-nya berubah menjadi:
```javascript
data: convs.map(c => ({ 
    id: c.conversation_id.toString(), 
    contact_id: c.contact_id.toString(),
    contact_name: c.contact_username, 
    contact_sip_username: c.contact_sip_username,
    last_message: c.last_message,
    last_message_time: c.last_message_time || c.created_at,
    unread_count: c.unread_count || 0  // <-- Sekarang dari DB, bukan hardcode 0
})) 
```

