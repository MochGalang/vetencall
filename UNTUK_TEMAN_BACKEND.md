# 📋 Panduan Lengkap Perbaikan Backend VetenCall

> Halo! Berikut **3 perbaikan penting** yang perlu kamu terapkan di server agar aplikasi bisa jalan sempurna. Semuanya di file `index.js` dan database MySQL/MariaDB ya.

---

## 🔧 Perbaikan 1 — Video Call (Asterisk SIP/WebRTC)

**Masalah:** Waktu user nge-Video Call, Asterisk malah strip baris `m=video` dari SDP-nya, jadi yang nyampe ke penerima cuma Voice Call biasa. Ini karena waktu register, kolom video di tabel `sip_buddies` tidak diisi.

### Langkah A — Tambah Kolom di `initDb()`

Tambahkan 4 pengecekan kolom ini di dalam fungsi `initDb()`, setelah blok `CREATE TABLE sip_buddies`:

```javascript
// Izin Video Call — tambahkan di dalam initDb()
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

### Langkah B — Update Query INSERT di `/api/register`

Ganti query `INSERT INTO sip_buddies` yang lama dengan ini:

```javascript
await pool.query(
    `INSERT INTO sip_buddies 
     (name, host, secret, context, username, type, avpf, icesupport, encryption, rtcp_mux, transport, nat, videosupport, max_video_streams, disallow, allow) 
     VALUES (?, 'dynamic', ?, 'internal', ?, 'friend', 'yes', 'yes', 'yes', 'yes', 'ws,udp', 'yes', 'yes', 1, 'all', 'vp8,vp9,h264,ulaw,alaw,opus')`,
    [sip_username, sip_password, sip_username]
);
```

> ⚠️ **Catatan:** User yang sudah terdaftar sebelumnya perlu di-update manual di DB (set `max_video_streams = 1`), atau suruh mereka daftar ulang.

---

## 🔧 Perbaikan 2 — Sorting Daftar Chat (seperti WhatsApp)

**Masalah:** Daftar chat tidak diurutkan berdasarkan pesan terbaru, dan tidak menampilkan preview pesan terakhir.

### Ganti seluruh endpoint `GET /api/conversations` dengan ini:

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
                (SELECT content FROM messages m 
                 WHERE m.conversation_id = c.id 
                 ORDER BY m.created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM messages m 
                 WHERE m.conversation_id = c.id 
                 ORDER BY m.created_at DESC LIMIT 1) as last_message_time,
                (SELECT COUNT(*) FROM messages m 
                 WHERE m.conversation_id = c.id 
                 AND m.sender_id != ?
                 AND (m.is_read = FALSE OR m.is_read IS NULL)) as unread_count
            FROM conversations c 
            JOIN users u ON (c.user1_id = u.id OR c.user2_id = u.id) 
            WHERE (c.user1_id = ? OR c.user2_id = ?) AND u.id != ?
            ORDER BY COALESCE(last_message_time, c.created_at) DESC
        `, [userId, userId, userId, userId]);
        
        res.json({ 
            success: true, 
            data: convs.map(c => ({ 
                id: c.conversation_id.toString(), 
                contact_id: c.contact_id.toString(),
                contact_name: c.contact_username, 
                contact_sip_username: c.contact_sip_username,
                last_message: c.last_message,
                last_message_time: c.last_message_time || c.created_at,
                unread_count: c.unread_count || 0
            })) 
        });
    } catch (error) {
        console.error('[API] Error getting conversations:', error);
        res.json({ success: false, data: [] });
    }
});
```

---

## 🔧 Perbaikan 3 — Badge Notifikasi Unread (seperti WhatsApp)

**Masalah:** Badge jumlah pesan belum dibaca tidak akurat — selalu 0 saat aplikasi dibuka ulang dari nol, padahal ada pesan yang belum dibaca.

**Cara kerja yang diinginkan:** Persis seperti WhatsApp — badge muncul sesuai jumlah pesan belum dibaca, meskipun aplikasi ditutup total.

### Langkah A — Tambah Kolom `is_read` di Tabel `messages`

Jalankan SQL ini **sekali** di database:

```sql
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMP NULL;
```

### Langkah B — Tambah Endpoint Baru `POST /api/chat/read`

Tambahkan endpoint baru ini di `index.js`. Endpoint ini dipanggil Flutter otomatis setiap kali user membuka percakapan:

```javascript
app.post('/api/chat/read', async (req, res) => {
    const { conversation_id, user_id } = req.body;
    if (!conversation_id || !user_id) {
        return res.json({ success: false, message: 'conversation_id dan user_id wajib diisi' });
    }
    try {
        await pool.query(
            `UPDATE messages 
             SET is_read = TRUE, read_at = NOW() 
             WHERE conversation_id = ? 
               AND sender_id != ? 
               AND (is_read = FALSE OR is_read IS NULL)`,
            [conversation_id, user_id]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('[API] Error marking messages as read:', error);
        res.json({ success: false });
    }
});
```

> ✅ Endpoint `GET /api/conversations` di **Perbaikan 2** sudah otomatis menghitung `unread_count` dari kolom `is_read` ini. Jadi dua perbaikan ini saling nyambung.

---

## ✅ Checklist Setelah Selesai

- [ ] Kolom video (`videosupport`, `max_video_streams`, `allow`, `disallow`) sudah ada di tabel `sip_buddies`
- [ ] Kolom `is_read` dan `read_at` sudah ada di tabel `messages`
- [ ] Endpoint `GET /api/conversations` sudah di-replace (mengembalikan `last_message`, `last_message_time`, `unread_count`)
- [ ] Endpoint baru `POST /api/chat/read` sudah ditambahkan
- [ ] **Service Node.js sudah di-restart** (`pm2 restart all` atau sejenisnya)

---

> 💬 **Semua perubahan ini bersifat *backward-compatible*** — tidak ada field lama yang dihapus atau di-rename, jadi aman untuk tim web yang juga pakai API yang sama.
