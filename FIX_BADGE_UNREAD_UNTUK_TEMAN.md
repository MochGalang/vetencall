# 🔴 Fix Badge Notifikasi Pesan Belum Dibaca (Unread Count)

> **Konteks:** Sekarang badge di daftar chat hanya muncul kalau aplikasi terbuka (via WebSocket). Kalau aplikasi ditutup total lalu dibuka lagi, badge tidak muncul meski ada pesan yang belum dibaca. Fix ini bikin badge akurat persis seperti WhatsApp.

---

## Langkah 1 — Tambah Kolom di Tabel `messages`

Jalankan SQL ini **sekali saja** di database MySQL/MariaDB kamu:

```sql
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMP NULL;
```

---

## Langkah 2 — Tambah Endpoint Baru `POST /api/chat/read`

Tambahkan endpoint baru ini di `index.js`:

```javascript
app.post('/api/chat/read', async (req, res) => {
    const { conversation_id, user_id } = req.body;
    if (!conversation_id || !user_id) {
        return res.json({ success: false, message: 'conversation_id dan user_id wajib diisi' });
    }
    try {
        // Tandai semua pesan di conversation ini sebagai sudah dibaca
        // (hanya pesan yang BUKAN dari user sendiri)
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

---

## Langkah 3 — Update Endpoint `GET /api/conversations`

Di endpoint conversations yang sudah ada, **tambahkan subquery `unread_count`** ke dalam SELECT query-nya:

```sql
-- Tambahkan ini ke dalam SELECT:
(SELECT COUNT(*) 
 FROM messages m 
 WHERE m.conversation_id = c.id 
   AND m.sender_id != ? 
   AND (m.is_read = FALSE OR m.is_read IS NULL)) as unread_count
```

Dan di bagian parameter query (`pool.query(..., [params])`), tambahkan `userId` di posisi pertama parameter.

Lalu di bagian response `.map(c => ({...}))`, **ganti** baris `unread_count: 0` dengan:

```javascript
unread_count: c.unread_count || 0   // ← dari DB, bukan hardcode 0 lagi
```

---

## ✅ Checklist

- [ ] Kolom `is_read` dan `read_at` sudah ada di tabel `messages`
- [ ] Endpoint `POST /api/chat/read` sudah ditambahkan di `index.js`
- [ ] Endpoint `GET /api/conversations` sudah mengembalikan `unread_count` dari DB
- [ ] **Node.js sudah di-restart** setelah perubahan

---

## 🔄 Cara Kerjanya (Alur Lengkap)

```
Teman kirim pesan
    ↓ Pesan disimpan di DB dengan is_read = FALSE
    
User buka aplikasi → GET /api/conversations
    ↓ Server hitung: COUNT(*) WHERE is_read = FALSE
    ↓ Badge muncul: "3 pesan belum dibaca" ✅

User buka chat → Flutter kirim POST /api/chat/read
    ↓ Server update: SET is_read = TRUE

User tutup & buka aplikasi lagi → GET /api/conversations
    ↓ Server hitung ulang: COUNT(*) = 0
    ↓ Badge tidak muncul ✅
```

> 💬 **Aman untuk tim web** — tidak ada field lama yang dihapus, hanya nambah kolom dan endpoint baru.
