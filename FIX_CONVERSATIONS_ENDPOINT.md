# 🚨 Hotfix: Endpoint GET /api/conversations Error

**Masalah:** Endpoint `/api/conversations` mengembalikan `{"success":false,"data":[]}` karena ada **SQL error** di subquery `unread_count`. Template literal `${userId}` tidak boleh dipakai di dalam string SQL — harus pakai `?` (parameterized query).

---

## ✅ Solusi — Replace SELURUH endpoint conversations dengan kode ini:

```javascript
app.get('/api/conversations', async (req, res) => {
    const userId = req.query.user_id;
    if (!userId) return res.json({ success: false, data: [] });
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
                unread_count: parseInt(c.unread_count) || 0
            })) 
        });
    } catch (error) {
        console.error('[API] Error getting conversations:', error);
        res.json({ success: false, data: [] });
    }
});
```

---

## 🔍 Apa yang berubah dari versi sebelumnya?

| Bagian | Sebelum (❌ Error) | Sesudah (✅ Benar) |
|--------|--------------------|-------------------|
| Parameter subquery | `m.sender_id != ${userId}` | `m.sender_id != ?` |
| Jumlah param array | `[userId, userId, userId]` (3) | `[userId, userId, userId, userId]` (4) |
| unread_count parsing | `c.unread_count \|\| 0` | `parseInt(c.unread_count) \|\| 0` |
| Guard null userId | Tidak ada | `if (!userId) return ...` |

---

## ✅ Cara verifikasi setelah fix:

Buka browser, akses URL ini (ganti `USER_ID` dengan ID user yang valid):
```
http://52.2.21.5:3001/api/conversations?user_id=USER_ID
```

Hasilnya harus:
```json
{"success":true,"data":[...]}
```

> ⚠️ **Wajib restart Node.js setelah edit** — `pm2 restart all` atau sejenisnya.
