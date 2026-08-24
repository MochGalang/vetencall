# Bug Report: Badge Unread Muncul Lagi Setelah Diklik

**Dibuat untuk:** Tim Backend
**Tanggal:** 2026-07-30
**Prioritas:** High - Sudah Dikonfirmasi
**Status Frontend:** Sudah difix sementara dengan workaround lokal

---

## Status: SUDAH DIKONFIRMASI

Setelah investigasi dari sisi frontend, **penyebab bug sudah dipastikan**:

**Endpoint POST /api/chat/read BELUM ADA di backend.**

Bukti dari log Flutter saat halaman chat dibuka:

    [MarkRead] Memanggil POST /chat/read untuk conversation: 16
    [MarkRead] Response: {success: false, message: Koneksi ke server gagal:
    FormatException: SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON}
    [MarkRead] GAGAL! Endpoint mungkin belum ada di backend.

Artinya: server mengembalikan halaman HTML 404 (bukan JSON),
karena route POST /api/chat/read belum terdaftar di backend.

---

## Deskripsi Bug

Ketika user mengklik chat yang memiliki badge unread (angka notifikasi),
badge tersebut menghilang sesaat, tapi beberapa saat kemudian muncul kembali.

## Alur Bug

1. User klik chat -> badge hilang (hanya secara lokal di Flutter)
2. User masuk ke halaman chat
3. Flutter memanggil POST /api/chat/read -> GAGAL (404, endpoint belum ada)
4. User kembali ke halaman daftar chat
5. Flutter memanggil GET /api/conversations?user_id=...
6. Server masih kembalikan unread_count > 0 (tidak pernah di-reset)
7. Badge muncul lagi!

---

## Yang Harus Dibuat di Backend

**Endpoint baru: POST /api/chat/read**

**Request Body:**
    {
      "conversation_id": "16",
      "user_id": "123"
    }

**Response yang diharapkan (sukses):**
    {
      "success": true,
      "message": "Messages marked as read"
    }

---

## Implementasi Database

Pilih salah satu opsi sesuai struktur DB kamu:

**Opsi A - Jika ada kolom is_read di tabel messages:**
    UPDATE messages
    SET is_read = true, read_at = NOW()
    WHERE conversation_id = :conversation_id
      AND sender_id != :user_id
      AND is_read = false;

**Opsi B - Jika ada kolom unread_count di tabel conversations:**
    UPDATE conversations
    SET unread_count = 0
    WHERE id = :conversation_id;

    -- ATAU jika ada tabel conversation_members:
    UPDATE conversation_members
    SET unread_count = 0
    WHERE conversation_id = :conversation_id
      AND user_id = :user_id;

**Opsi C - Jika pakai tabel message_reads:**
    INSERT INTO message_reads (conversation_id, user_id, last_read_at)
    VALUES (:conversation_id, :user_id, NOW())
    ON CONFLICT (conversation_id, user_id)
    DO UPDATE SET last_read_at = NOW();

---

## Contoh Implementasi Node.js/Express

    // File: routes/chat.js (atau file routes yang kamu pakai)

    router.post('/chat/read', async (req, res) => {
      const { conversation_id, user_id } = req.body;

      if (!conversation_id || !user_id) {
        return res.json({ success: false, message: 'conversation_id dan user_id wajib diisi' });
      }

      try {
        // SESUAIKAN query ini dengan struktur database kamu!

        // Contoh dengan unread_count di tabel conversations:
        await db.query(
          'UPDATE conversations SET unread_count = 0 WHERE id = $1',
          [conversation_id]
        );

        // ATAU contoh dengan is_read di tabel messages:
        // await db.query(
        //   'UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id != $2 AND is_read = false',
        //   [conversation_id, user_id]
        // );

        return res.json({ success: true, message: 'Messages marked as read' });
      } catch (error) {
        console.error('[MarkRead] Error:', error);
        return res.json({ success: false, message: 'Server error' });
      }
    });

---

## Yang Perlu Dicek di GET /api/conversations

Pastikan endpoint ini menghitung unread_count dengan benar setelah mark-as-read.
Cek apakah query-nya menghitung dari kolom is_read atau dari unread_count yang di-reset.

Contoh query yang benar (jika pakai is_read di messages):
    SELECT
      c.id,
      c.contact_name,
      COUNT(m.id) FILTER (WHERE m.is_read = false AND m.sender_id != :user_id) AS unread_count
    FROM conversations c
    LEFT JOIN messages m ON m.conversation_id = c.id
    WHERE c.user_id = :user_id
    GROUP BY c.id;

---

## Integrasi dengan Frontend

Frontend SUDAH memanggil endpoint ini setiap kali halaman chat dibuka.
Di file frontend/lib/chat_conversation_page.dart sudah ada kode:

    ApiService.post('/chat/read', {
      'conversation_id': widget.conversationId,
      'user_id': _currentUserId,
    });

URL yang dipanggil: POST http://52.2.21.5:3001/api/chat/read

Setelah endpoint dibuat dan berfungsi, frontend tidak perlu diubah apapun.
Badge unread akan otomatis berfungsi dengan benar.

---

## Catatan Penting

- Frontend saat ini punya workaround sementara (menyimpan ID conversation yang
  sudah dibaca secara lokal di dalam Set).
- Workaround ini tidak persistent: kalau app di-restart, badge bisa muncul lagi.
- Solusi permanen HARUS di backend agar unread_count benar-benar di-reset di database.
- Setelah endpoint selesai dan berfungsi (response success: true), beritahu tim
  frontend agar workaround lokal bisa dihapus.

Kalau ada pertanyaan tentang struktur database, diskusikan dulu sebelum implementasi!
