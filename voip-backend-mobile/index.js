require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const ari = require('ari-client');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const multer = require('multer');


const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors({
    origin: true,
    credentials: true
}));
app.use(express.json());

// ==========================================
// 0. INIT FIREBASE ADMIN (FCM)
// ==========================================
const admin = require('firebase-admin');
try {
    const serviceAccount = require('./firebase-service-account.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('🔥 Firebase Admin initialized successfully');
} catch (e) {
    console.log('⚠️ Failed to initialize Firebase Admin. Push notifications will be disabled:', e.message);
}

// ==========================================
// 1. KONEKSI KE MARIADB / MYSQL
// ==========================================
const pool = mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    user: process.env.DB_USER || 'asterisk',
    password: process.env.DB_PASSWORD || 'voip',
    database: process.env.DB_NAME || 'asterisk',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// CREATE TABLES IF NOT EXISTS (Agar semua fungsi jalan)
async function initDb() {
    try {
        const queries = [
            `CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(255), phone_number VARCHAR(255), password VARCHAR(255), sip_username VARCHAR(255), sip_password VARCHAR(255), fcm_token TEXT)`,
            `CREATE TABLE IF NOT EXISTS sip_buddies (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), host VARCHAR(255), secret VARCHAR(255), context VARCHAR(255), username VARCHAR(255), type VARCHAR(255), avpf VARCHAR(255), icesupport VARCHAR(255), encryption VARCHAR(255), rtcp_mux VARCHAR(255), transport VARCHAR(255), nat VARCHAR(255) DEFAULT 'yes')`,
            `CREATE TABLE IF NOT EXISTS conversations (id INT AUTO_INCREMENT PRIMARY KEY, user1_id INT, user2_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS messages (id INT AUTO_INCREMENT PRIMARY KEY, conversation_id INT, sender_id INT, content TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS groups (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS group_members (id INT AUTO_INCREMENT PRIMARY KEY, group_id INT, user_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS blocked_contacts (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, blocked_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS muted_conversations (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, conversation_id INT, is_muted BOOLEAN DEFAULT TRUE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`
        ];
        for (let q of queries) await pool.query(q);
        
        // Pengecekan kolom yang mungkin belum ada di database lama
        try {
            await pool.query("SHOW COLUMNS FROM sip_buddies LIKE 'nat'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE sip_buddies ADD COLUMN nat VARCHAR(255) DEFAULT 'yes'");
            });
            await pool.query("SHOW COLUMNS FROM users LIKE 'fcm_token'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE users ADD COLUMN fcm_token TEXT");
            });
            await pool.query("SHOW COLUMNS FROM users LIKE 'is_online'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE users ADD COLUMN is_online BOOLEAN DEFAULT FALSE");
            });
            await pool.query("SHOW COLUMNS FROM users LIKE 'last_seen'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE users ADD COLUMN last_seen TIMESTAMP NULL");
            });
            await pool.query("SHOW COLUMNS FROM messages LIKE 'message_type'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE messages ADD COLUMN message_type VARCHAR(50) DEFAULT 'text'");
            });
            await pool.query("SHOW COLUMNS FROM messages LIKE 'media_url'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE messages ADD COLUMN media_url TEXT NULL");
            });
        } catch (colErr) {
            console.log("⚠️ Alter table skip (already exists or error):", colErr.message);
        }
        
        console.log("✅ Database tables checked/initialized.");
    } catch (e) {
        console.error("❌ DB Init error:", e);
    }
}


// ==========================================
// 2. AUTHENTICATION (LOGIN & REGISTER)
// ==========================================
app.post('/api/register', async (req, res) => {
    const { username, phone_number, password } = req.body;
    if (!username || !phone_number || !password) return res.status(400).json({ success: false, message: "Data tidak lengkap." });

    try {
        const [existing] = await pool.query("SELECT id FROM users WHERE phone_number = ? OR username = ?", [phone_number, username]);
        if (existing.length > 0) return res.status(400).json({ success: false, message: "Nomor HP/Username sudah terdaftar." });

        const hashedPassword = await bcrypt.hash(password, 10);
        const sip_username = phone_number;
        const sip_password = password; // Use raw plaintext password for Asterisk Digest Auth

        await pool.query(
            "INSERT INTO users (username, phone_number, password, sip_username, sip_password) VALUES (?, ?, ?, ?, ?)",
            [username, phone_number, hashedPassword, sip_username, sip_password]
        );

        await pool.query(
            `INSERT INTO sip_buddies (name, host, secret, context, username, type, avpf, icesupport, encryption, rtcp_mux, transport, nat) 
            VALUES (?, 'dynamic', ?, 'internal', ?, 'friend', 'yes', 'yes', 'yes', 'yes', 'ws,udp', 'yes')`,
            [sip_username, sip_password, sip_username]
        );
// Tambahkan endpoint realtime PJSIP
await pool.query(
    `INSERT INTO ps_aors (id, max_contacts, remove_existing)
     VALUES (?, 1, 'yes')
     ON DUPLICATE KEY UPDATE
     max_contacts = VALUES(max_contacts),
     remove_existing = VALUES(remove_existing)`,
    [sip_username]
);

await pool.query(
    `INSERT INTO ps_auths (id, auth_type, password, username)
     VALUES (?, 'userpass', ?, ?)
     ON DUPLICATE KEY UPDATE
     password = VALUES(password),
     username = VALUES(username)`,
    [sip_username, sip_password, sip_username]
);

await pool.query(
    `INSERT INTO ps_endpoints (
        id,
        transport,
        aors,
        auth,
        context,
        disallow,
        allow,
        direct_media,
        force_rport,
        rewrite_contact,
        rtp_symmetric,
        timers,
        webrtc
    )
    VALUES (
        ?,
        'transport-ws',
        ?,
        ?,
        'from-internal',
        'all',
        'opus,ulaw,alaw',
        'no',
        'yes',
        'yes',
        'yes',
        'no',
        'yes'
    )
    ON DUPLICATE KEY UPDATE
        aors = VALUES(aors),
        auth = VALUES(auth)`,
    [sip_username, sip_username, sip_username]
);


        const [newUser] = await pool.query(
    "SELECT id, username, phone_number FROM users WHERE phone_number = ?",
    [phone_number]
);

const { exec } = require('child_process');
exec('asterisk -rx "pjsip reload"', (err) => {
    if (err) console.error('[Asterisk] Error reloading PJSIP:', err);
});

res.json({
    success: true,
    message: "Registrasi berhasil",
    data: {
        id: newUser[0].id.toString(),
        username: newUser[0].username,
        phone_number: newUser[0].phone_number,
        sip_username,
        sip_password
    }
});
    } catch (error) {
        res.status(500).json({ success: false, message: "Server error: " + error.message });
    }
});

app.post('/api/login', async (req, res) => {
    const { sip_username, password } = req.body;

    if (!sip_username || !password) {
        return res.status(400).json({ success: false, message: 'SIP username dan password wajib diisi.' });
    }

    try {
        console.log(`[Login] Mencari user: ${sip_username}`);
        const [users] = await pool.query(
            "SELECT * FROM users WHERE sip_username = ? OR phone_number = ?",
            [sip_username, sip_username]
        );

        if (users.length === 0) {
            console.log(`[Login] User tidak ditemukan: ${sip_username}`);
            return res.status(401).json({ success: false, message: 'Ekstensi SIP atau Nomor HP tidak ditemukan.' });
        }

        const user = users[0];
        console.log(`[Login] User ditemukan: ${user.username}, memverifikasi password...`);

        // User ingin login menggunakan password SIP yang random
        const isMatch = await bcrypt.compare(password,user.password);
        if (!isMatch) {
            console.log(`[Login] Password salah untutk user: ${sip_username}`);
	return res.status(401).json({ success: false, message: 'password salah.' });
	}

        console.log(`[Login] ✅ Login sukses: ${user.username} (${user.sip_username})`);
        res.json({
            success: true,
            data: {
                id: user.id.toString(),
                username: user.username,
                phone_number: user.phone_number,
                sip_username: user.sip_username,
                sip_password: user.sip_password
            }
        });
    } catch (error) {
        console.error('[Login] ❌ Error:', error.message);
        res.status(500).json({ success: false, message: 'Server error: ' + error.message });
    }
});

// ==========================================
// 3. CONTACTS & CONVERSATIONS
// ==========================================
app.get('/api/contacts', async (req, res) => {
    const userId = req.query.user_id;
    try {
        // Ambil semua user kecuali diri sendiri
        const [contacts] = await pool.query("SELECT id, username, sip_username FROM users WHERE id != ?", [userId]);
        
        // Sisipkan status is_online dari memori WebSocket (clients Map)
        const enrichedContacts = contacts.map(c => {
            const contactIdStr = c.id.toString();
            const isOnline = clients.has(contactIdStr) && clients.get(contactIdStr).size > 0;
            
            return { 
                id: contactIdStr, 
                username: c.username, 
                sip_username: c.sip_username,
                is_online: isOnline
            };
        });

        res.json({ success: true, data: enrichedContacts });
    } catch (error) {
        res.json({ success: false, data: [] });
    }
});

//----

app.post('/api/contacts/sync', async (req, res) => {
    const { user_id, phone_numbers } = req.body;

    if (!user_id || !Array.isArray(phone_numbers)) {
        return res.status(400).json({
            success: false,
            message: 'user_id dan phone_numbers wajib diisi'
        });
    }

    if (phone_numbers.length === 0) {
        return res.json({
            success: true,
            data: []
        });
    }

    try {
        const placeholders = phone_numbers.map(() => '?').join(',');

        const [rows] = await pool.query(
            `
            SELECT
                id,
                username,
                phone_number,
                sip_username
            FROM users
            WHERE phone_number IN (${placeholders})
              AND id != ?
            `,
            [...phone_numbers, user_id]
        );

        res.json({
            success: true,
            data: rows.map(user => {
                const contactIdStr = user.id.toString();
                const isOnline = clients.has(contactIdStr) && clients.get(contactIdStr).size > 0;
                
                return {
                    id: contactIdStr,
                    username: user.username,
                    phone_number: user.phone_number,
                    sip_username: user.sip_username,
                    is_online: isOnline
                };
            })
        });

    } catch (err) {
        console.error('[CONTACT_SYNC]', err);

        res.status(500).json({
            success: false,
            message: err.message
        });
    }
});


app.post('/api/conversations', async (req, res) => {
    const { user1_id, user2_id } = req.body;
    try {
        // Cek apakah conversation sudah ada
        const [existing] = await pool.query(
            "SELECT id FROM conversations WHERE (user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)",
            [user1_id, user2_id, user2_id, user1_id]
        );
        if (existing.length > 0) {
            return res.json({ success: true, conversation_id: existing[0].id.toString() });
        }
        
        // Buat baru
        const [result] = await pool.query(
            "INSERT INTO conversations (user1_id, user2_id) VALUES (?, ?)",
            [user1_id, user2_id]
        );
        res.json({ success: true, conversation_id: result.insertId.toString() });
    } catch (error) {
        console.error('[API] Error creating conversation:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

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
                u.is_online,
                u.last_seen as contact_last_seen,
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
            data: convs.map(c => {
                const contactIdStr = c.contact_id.toString();
                const isOnline = clients.has(contactIdStr) && clients.get(contactIdStr).size > 0;
                
                return { 
                    id: c.conversation_id.toString(), 
                    contact_id: contactIdStr,
                    contact_name: c.contact_username, 
                    contact_sip_username: c.contact_sip_username,
                    is_online: isOnline,
                    last_seen: c.contact_last_seen,
                    last_message: c.last_message,
                    last_message_time: c.last_message_time || c.created_at,
                    unread_count: parseInt(c.unread_count) || 0
                };
            }) 
        });
    } catch (error) {
        console.error('[API] Error getting conversations:', error);
        res.json({ success: false, data: [] });
    }
});

// ==========================================
// 3.5 GROUPS & BLOCKED CONTACTS
// ==========================================

// --- GROUPS ---
app.post('/api/groups', async (req, res) => {
    const { name, member_ids } = req.body;
    if (!name || !Array.isArray(member_ids)) {
        return res.status(400).json({ success: false, message: 'Invalid data' });
    }
    try {
        const [result] = await pool.query("INSERT INTO groups (name) VALUES (?)", [name]);
        const groupId = result.insertId;
        
        for (let memberId of member_ids) {
            await pool.query("INSERT INTO group_members (group_id, user_id) VALUES (?, ?)", [groupId, memberId]);
        }
        res.json({ success: true, group_id: groupId });
    } catch (error) {
        console.error('[API] Error creating group:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.get('/api/groups', async (req, res) => {
    const userId = req.query.user_id;
    if (!userId) return res.json({ success: false, data: [] });
    try {
        const [groups] = await pool.query(`
            SELECT g.id, g.name, g.created_at
            FROM groups g
            JOIN group_members gm ON g.id = gm.group_id
            WHERE gm.user_id = ?
        `, [userId]);
        res.json({ success: true, data: groups });
    } catch (error) {
        res.json({ success: false, data: [] });
    }
});

app.get('/api/users/:target_id/common-groups', async (req, res) => {
    const userId = req.query.user_id;
    const targetId = req.params.target_id;
    if (!userId || !targetId) return res.json({ success: false, data: [] });
    
    try {
        const [groups] = await pool.query(`
            SELECT g.id as group_id, g.name as group_name
            FROM groups g
            JOIN group_members gm1 ON g.id = gm1.group_id
            JOIN group_members gm2 ON g.id = gm2.group_id
            WHERE gm1.user_id = ? AND gm2.user_id = ?
        `, [userId, targetId]);
        
        res.json({
            success: true,
            data: groups.map(g => ({
                group_id: g.group_id.toString(),
                group_name: g.group_name
            }))
        });
    } catch (error) {
        console.error('[API] Error getting common groups:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.get('/api/users/:target_id/block-status', async (req, res) => {
    const userId = req.query.user_id;
    const targetId = req.params.target_id;
    if (!userId || !targetId) return res.status(400).json({ success: false });
    try {
        const [byMe] = await pool.query("SELECT id FROM blocked_contacts WHERE user_id = ? AND blocked_id = ?", [userId, targetId]);
        const [byThem] = await pool.query("SELECT id FROM blocked_contacts WHERE user_id = ? AND blocked_id = ?", [targetId, userId]);
        res.json({
            success: true,
            is_blocked_by_me: byMe.length > 0,
            has_blocked_me: byThem.length > 0
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post('/api/users/block', async (req, res) => {
    const { blocker_id, blocked_id, action } = req.body;
    try {
        if (action === 'block') {
            const [existing] = await pool.query("SELECT id FROM blocked_contacts WHERE user_id = ? AND blocked_id = ?", [blocker_id, blocked_id]);
            if (existing.length === 0) {
                await pool.query("INSERT INTO blocked_contacts (user_id, blocked_id) VALUES (?, ?)", [blocker_id, blocked_id]);
            }
        } else if (action === 'unblock') {
            await pool.query("DELETE FROM blocked_contacts WHERE user_id = ? AND blocked_id = ?", [blocker_id, blocked_id]);
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});


// --- BLOCKED CONTACTS ---
app.post('/api/contacts/block', async (req, res) => {
    const { user_id, blocked_id } = req.body;
    try {
        const [existing] = await pool.query("SELECT id FROM blocked_contacts WHERE user_id = ? AND blocked_id = ?", [user_id, blocked_id]);
        if (existing.length === 0) {
            await pool.query("INSERT INTO blocked_contacts (user_id, blocked_id) VALUES (?, ?)", [user_id, blocked_id]);
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post('/api/contacts/unblock', async (req, res) => {
    const { user_id, blocked_id } = req.body;
    try {
        await pool.query("DELETE FROM blocked_contacts WHERE user_id = ? AND blocked_id = ?", [user_id, blocked_id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

app.get('/api/contacts/blocked', async (req, res) => {
    const userId = req.query.user_id;
    if (!userId) return res.json({ success: false, data: [] });
    try {
        const [blocked] = await pool.query(`
            SELECT u.id, u.username, u.sip_username
            FROM users u
            JOIN blocked_contacts b ON u.id = b.blocked_id
            WHERE b.user_id = ?
        `, [userId]);
        res.json({ 
            success: true, 
            data: blocked.map(b => ({
                id: b.id.toString(),
                username: b.username,
                sip_username: b.sip_username
            }))
        });
    } catch (error) {
        res.json({ success: false, data: [] });
    }
});


// ==========================================
// 4. CHAT SYSTEM & PUSH NOTIFICATION
// ==========================================
async function sendPushNotification(receiver_id, title, body, conversation_id = null) {
    if (!admin) return;
    try {
        if (conversation_id) {
            const [muted] = await pool.query("SELECT id FROM muted_conversations WHERE user_id = ? AND conversation_id = ? AND is_muted = TRUE", [receiver_id, conversation_id]);
            if (muted.length > 0) {
                console.log(`[FCM] Notification muted for user ${receiver_id} in conversation ${conversation_id}`);
                return;
            }
        }
        const [rows] = await pool.query("SELECT fcm_token FROM users WHERE id = ?", [receiver_id]);
        if (rows.length > 0 && rows[0].fcm_token) {
            const message = {
                notification: { title, body },
                data: { title, body, type: 'chat' },
                token: rows[0].fcm_token,
                android: { priority: 'high' },
                apns: { payload: { aps: { contentAvailable: true } } }
            };
            await admin.messaging().send(message);
            console.log(`[FCM] Push sent to user ${receiver_id}`);
        }
    } catch (e) {
        console.error(`[FCM] Error sending push to user ${receiver_id}:`, e.message);
    }
}

// --- MUTED CONVERSATIONS ---
app.post('/api/conversations/mute', async (req, res) => {
    const { user_id, conversation_id, is_muted } = req.body;
    try {
        if (is_muted) {
            const [existing] = await pool.query("SELECT id FROM muted_conversations WHERE user_id = ? AND conversation_id = ?", [user_id, conversation_id]);
            if (existing.length === 0) {
                await pool.query("INSERT INTO muted_conversations (user_id, conversation_id, is_muted) VALUES (?, ?, TRUE)", [user_id, conversation_id]);
            } else {
                await pool.query("UPDATE muted_conversations SET is_muted = TRUE WHERE user_id = ? AND conversation_id = ?", [user_id, conversation_id]);
            }
        } else {
            await pool.query("DELETE FROM muted_conversations WHERE user_id = ? AND conversation_id = ?", [user_id, conversation_id]);
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post('/api/fcm-token', async (req, res) => {
    const { user_id, fcm_token } = req.body;
    try {
        await pool.query("UPDATE users SET fcm_token = ? WHERE id = ?", [fcm_token, user_id]);
        res.json({ success: true });
    } catch (e) {
        res.json({ success: false });
    }
});

app.post('/api/notify-call', async (req, res) => {
    const { caller_id, receiver_sip_username, caller_name } = req.body;
    if (!admin) return res.status(500).json({ success: false, message: "FCM not initialized" });

    try {
        const [rows] = await pool.query("SELECT id, fcm_token FROM users WHERE sip_username = ?", [receiver_sip_username]);
        if (rows.length > 0 && rows[0].fcm_token) {
            const message = {
                notification: { 
                    title: "Panggilan Masuk", 
                    body: `${caller_name} memanggil Anda` 
                },
                data: { 
                    type: 'call',
                    caller_id: caller_id.toString(),
                    caller_name: caller_name
                },
                token: rows[0].fcm_token,
                android: { priority: 'high' },
                apns: { payload: { aps: { contentAvailable: true, sound: 'default' } } }
            };
            await admin.messaging().send(message);
            console.log(`[FCM] Call Push sent to ${receiver_sip_username}`);
            res.json({ success: true });
        } else {
            res.json({ success: false, message: "User not found or no FCM token" });
        }
    } catch (e) {
        console.error(`[FCM] Error notify-call:`, e.message);
        res.status(500).json({ success: false, error: e.message });
    }
});

app.get('/api/chat', async (req, res) => {
    const convId = req.query.conversation_id;
    try {
        const [messages] = await pool.query("SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC", [convId]);
        res.json({ 
            success: true, 
            data: messages.map(m => ({ 
                id: m.id.toString(), 
                sender_id: m.sender_id.toString(), 
                content: m.content,
                message_type: m.message_type || 'text',
                media_url: m.media_url,
                created_at: m.created_at 
            })) 
        });
    } catch (error) {
        res.json({ success: false, data: [] });
    }
});

app.post('/api/chat', async (req, res) => {
    const { conversation_id, sender_id, receiver_id, content, message_type = 'text', media_url = null } = req.body;
    try {
        const [result] = await pool.query(
            "INSERT INTO messages (conversation_id, sender_id, content, message_type, media_url) VALUES (?, ?, ?, ?, ?)",
            [conversation_id, sender_id, content, message_type, media_url]
        );

   	 const msgPayload = JSON.stringify({
            type: 'new_message',
            data: {
                id: result.insertId.toString(),
                conversation_id: conversation_id.toString(),
                sender_id: sender_id.toString(),
                content: content,
                message_type,
                media_url,
                created_at: new Date().toISOString()
            }
        });

        if (clients.has(sender_id.toString())) {
            clients.get(sender_id.toString()).forEach(client => {
                if (client.readyState === 1) {
                    client.send(msgPayload);
                }
            });
        }

        if (receiver_id && clients.has(receiver_id.toString())) {
            clients.get(receiver_id.toString()).forEach(client => {
                if (client.readyState === 1) {
                    client.send(msgPayload);
                }
            });
        } else if (receiver_id) {
            // User offline → kirim push notification
            const [senderRows] = await pool.query(
                "SELECT username FROM users WHERE id = ?",
                [sender_id]
            );

            const senderName =
                senderRows.length > 0 ? senderRows[0].username : "Seseorang";

            sendPushNotification(
                receiver_id,
                `Pesan dari ${senderName}`,
                content,
                conversation_id
            );
        }

        res.json({
            success: true,
            data: {
                id: result.insertId.toString()
            }
        });

    } catch (error) {
        console.error('[API] Error POST /api/chat:', error);
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

//mark as read

app.post('/api/chat/read', async (req, res) => {
	console.log('[read] Request masuk:', req.body);

    const { conversation_id, user_id } = req.body;

    if (!conversation_id || !user_id) {
        return res.json({
            success: false,
            message: 'conversation_id dan user_id wajib diisi'
        });
    }

    try {
        await pool.query(
            `UPDATE messages
             SET is_read = TRUE,
                 read_at = NOW()
             WHERE conversation_id = ?
               AND sender_id != ?
               AND (is_read = FALSE OR is_read IS NULL)`,
            [conversation_id, user_id]
        );

res.json({
            success: true,
            message: 'Messages marked as read'
        });

    } catch (error) {
        console.error('[API] Error marking messages as read:', error);

        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// ==========================================
// MARK AS READ
// ==========================================
app.post('/api/chat/read', async (req, res) => {
    console.log('[READ] Request masuk:', req.body);

    const { conversation_id, user_id } = req.body;

    if (!conversation_id || !user_id) {
        return res.json({
            success: false,
            message: 'conversation_id dan user_id wajib diisi'
        });
    }

    try {
        await pool.query(
            `UPDATE messages
             SET is_read = TRUE,
                 read_at = NOW()
             WHERE conversation_id = ?
               AND sender_id != ?
               AND (is_read = FALSE OR is_read IS NULL)`,
            [conversation_id, user_id]
        );

        res.json({
            success: true,
            message: 'Messages marked as read'
        });

    } catch (error) {
        console.error('[API] Error marking messages as read:', error);

        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// ==========================================
// 5. SCHEDULED SMS MESSAGES
// ==========================================
const schedule = require('node-schedule');
const axios = require('axios'); // Untuk integrasi API SMS provider

app.post('/api/schedule-sms', async (req, res) => {
    const { phone_number, message, scheduled_time } = req.body;
    // scheduled_time format ISO string (contoh: "2026-07-09T10:00:00Z")

    if (!phone_number || !message || !scheduled_time) {
        return res.status(400).json({ success: false, message: 'Data tidak lengkap. Butuh phone_number, message, dan scheduled_time.' });
    }

    try {
        const date = new Date(scheduled_time);
        
        if (date < new Date()) {
            return res.status(400).json({ success: false, message: 'Waktu schedule sudah lewat.' });
        }

        // Mulai schedule job
        schedule.scheduleJob(date, async function() {
            console.log(`⏰ [SCHEDULE] Waktunya mengirim SMS ke ${phone_number}...`);
            try {
                // Integrasi API Twilio (Standar Global untuk SMS OTP)
                // Kamu bisa daftar di twilio.com, lalu masukkan data ini ke file .env kamu nanti
                const accountSid = process.env.TWILIO_ACCOUNT_SID;
                const authToken = process.env.TWILIO_AUTH_TOKEN;
                const fromPhone = process.env.TWILIO_PHONE_NUMBER;

                if (accountSid && authToken && fromPhone) {
                    const params = new URLSearchParams();
                    params.append('To', phone_number);
                    params.append('From', fromPhone);
                    params.append('Body', message);

                    await axios.post(
                        `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
                        params,
                        {
                            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                            auth: { username: accountSid, password: authToken }
                        }
                    );
                } else {
                    console.log(`⚠️ [SCHEDULE] Kredensial Twilio di .env kosong. Mode Simulasi aktif.`);
                }
                
                console.log(`✅ [SCHEDULE] Berhasil "mengirim" SMS ke ${phone_number}: "${message}"`);
            } catch (err) {
                console.error(`❌ [SCHEDULE] Gagal mengirim SMS ke ${phone_number}:`, err.message);
            }
        });

        res.json({ 
            success: true, 
            message: `Pesan berhasil dijadwalkan ke ${phone_number} pada ${date.toLocaleString()}` 
        });
    } catch (error) {
        console.error('[API] Error scheduling SMS:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ==========================================
// 6. ASTERISK ARI
// ==========================================

let ariClient = null;

// Simpan channel yang sedang masuk ke aplikasi ARI
const activeAriChannels = new Map();

async function setupARI() {

    try {

        ariClient = await ari.connect(
            process.env.ARI_URL,
            process.env.ARI_USERNAME,
            process.env.ARI_PASSWORD
        );

        console.log('========================================');
        console.log('✅ Connected to Asterisk ARI successfully!');
        console.log('ARI APP:', process.env.ARI_APP_NAME);
        console.log('========================================');


        // ==========================================
        // EVENT: CHANNEL MASUK KE STASIS
        // ==========================================

        ariClient.on('StasisStart', async (event, channel) => {

            console.log('========================================');
            console.log('🔥 [ARI] CHANNEL MASUK KE STASIS');
            console.log('Channel ID:', channel.id);
            console.log('Channel Name:', channel.name);
            console.log('State:', channel.state);
            console.log('Caller:', channel.caller.number);
            console.log('Connected:', channel.connected.number);
            console.log('========================================');

            // Simpan channel
            activeAriChannels.set(channel.id, channel);

            console.log(
                `[ARI] Total active ARI channels: ${activeAriChannels.size}`
            );

        });


        // ==========================================
        // EVENT: CHANNEL KELUAR DARI STASIS
        // ==========================================

        ariClient.on('StasisEnd', (event, channel) => {

            console.log('========================================');
            console.log('❌ [ARI] CHANNEL KELUAR DARI STASIS');
            console.log('Channel ID:', channel.id);
            console.log('Channel Name:', channel.name);
            console.log('========================================');

            activeAriChannels.delete(channel.id);

        });


        // ==========================================
        // START ARI APPLICATION
        // ==========================================

        ariClient.start(process.env.ARI_APP_NAME);

    } catch (err) {

        console.error('========================================');
        console.error('⚠️ ARI belum terkoneksi.');
        console.error(err.message);
        console.error('========================================');

    }

}

setupARI();

// ==========================================
// 7. CONFERENCE CALL / ARI BRIDGE
// ==========================================

app.post('/api/calls/conference', async (req, res) => {
    try {
        const {
            channel_id_1,
            channel_id_2,
            target_sip_extension
        } = req.body;

        // Pastikan ARI terkoneksi
        if (!ariClient) {
            return res.status(503).json({
                success: false,
                message: 'ARI belum terkoneksi.'
            });
        }

        // Validasi input
        if (!channel_id_1 || !channel_id_2) {
            return res.status(400).json({
                success: false,
                message: 'channel_id_1 dan channel_id_2 wajib diisi.'
            });
        }

        console.log('========================================');
        console.log('[CONFERENCE] Memulai conference bridge');
        console.log('[CONFERENCE] Channel 1:', channel_id_1);
        console.log('[CONFERENCE] Channel 2:', channel_id_2);
        console.log('[CONFERENCE] Target:', target_sip_extension || '-');
        console.log('========================================');

        // Pastikan kedua channel benar-benar masih ada
        const channel1 = await ariClient.channels.get({
            channelId: channel_id_1
        });

        const channel2 = await ariClient.channels.get({
            channelId: channel_id_2
        });

        console.log(
            '[CONFERENCE] Channel 1 ditemukan:',
            channel1.name,
            channel1.state
        );

        console.log(
            '[CONFERENCE] Channel 2 ditemukan:',
            channel2.name,
            channel2.state
        );

        // Buat bridge mixing baru
        const bridge = await ariClient.bridges.create({
            type: 'mixing',
            name: `conference-${Date.now()}`
        });

        console.log(
            '[CONFERENCE] Bridge berhasil dibuat:',
            bridge.id
        );

        // Masukkan channel pertama
        await bridge.addChannel({
            channel: channel_id_1
        });

        console.log(
            '[CONFERENCE] Channel 1 masuk bridge'
        );

        // Masukkan channel kedua
        await bridge.addChannel({
            channel: channel_id_2
        });

        console.log(
            '[CONFERENCE] Channel 2 masuk bridge'
        );

        console.log('========================================');
        console.log('[CONFERENCE] Conference bridge berhasil dibuat!');
        console.log('[CONFERENCE] Bridge ID:', bridge.id);
        console.log('========================================');

        // Response
        return res.json({
            success: true,
            message: '1010 dan 2020 berhasil dimasukkan ke conference bridge.',
            bridge_id: bridge.id,
            bridge_name: bridge.name,
            channels: [
                {
                    id: channel_id_1,
                    name: channel1.name
                },
                {
                    id: channel_id_2,
                    name: channel2.name
                }
            ],
            target_sip_extension: target_sip_extension || null
        });

    } catch (err) {
        console.error('========================================');
        console.error('[CONFERENCE] ERROR');
        console.error(err);
        console.error('========================================');

        return res.status(500).json({
            success: false,
            message: 'Gagal membuat conference bridge.',
            error: err.message
        });
    }
});

// ==========================================
// 7. OUTBOUND AI TTS
// ==========================================
app.post('/api/outbound-tts', async (req, res) => {

    const { target_number, message } = req.body;

    if (!target_number || !message) {
        return res.status(400).json({
            success: false,
            message: 'Nomor tujuan dan pesan wajib diisi.'
        });
    }

    try {

        console.log(`[AI-TTS] Memanggil ${target_number}`);

        const safeMessage = message.replace(/ /g, '_');

        const callFile = `
Channel: SIP/${target_number}
CallerID: "AI Assistant" <1000>
Context: ai-broadcast
Extension: s
Priority: 1
Set: AI_MESSAGE=${safeMessage}
WaitTime: 30
`.trim();

        const filename = `ai_tts_${Date.now()}.call`;

        const tmpFile = path.join('/tmp', filename);

        const outgoingFile = path.join(
            '/var/spool/asterisk/outgoing',
            filename
        );

        fs.writeFileSync(tmpFile, callFile);

        exec(`mv ${tmpFile} ${outgoingFile}`, (err) => {

            if (err) {

                console.error(err);

                return res.status(500).json({
                    success: false,
                    message: 'Gagal mengirim file ke Asterisk.'
                });

            }

            console.log(`[AI-TTS] Call file berhasil dibuat.`);

            res.json({
                success: true,
                message: 'Panggilan AI sedang diproses.'
            });

        });

    } catch (err) {

        console.error(err);

        res.status(500).json({
            success: false,
            message: err.message
        });

    }

});

// ==========================================
// PROFILE ENDPOINTS
// ==========================================

// Pastikan folder uploads ada
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

// Konfigurasi Multer untuk upload foto
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const userId = req.body.user_id || 'unknown';
        const ext = path.extname(file.originalname);
        cb(null, `${userId}_${Date.now()}${ext}`);
    }
});
const upload = multer({ storage });

// Endpoint upload foto profil
app.post('/api/profile/upload-photo', upload.single('photo'), async (req, res) => {
    try {
        const { user_id } = req.body;
        if (!user_id || !req.file) {
            return res.status(400).json({ success: false, message: 'user_id dan photo wajib ada' });
        }
        const photoUrl = `/uploads/${req.file.filename}`;
        await pool.execute('UPDATE users SET profile_picture = ? WHERE id = ?', [photoUrl, user_id]);
        res.json({ success: true, data: { profile_pic: photoUrl } });
    } catch (e) {
        console.error('Upload photo error:', e);
        res.status(500).json({ success: false, message: e.message });
    }
});

// Endpoint upload file media
app.post('/api/upload', upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, message: 'file wajib ada' });
        }
        const fileUrl = `/uploads/${req.file.filename}`;
        res.json({ success: true, url: fileUrl });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// Endpoint update nama profil
app.post('/api/profile/update', async (req, res) => {
    try {
        const { user_id, username } = req.body;
        if (!user_id) return res.status(400).json({ success: false, message: 'user_id wajib ada' });
        await pool.execute('UPDATE users SET username = ? WHERE id = ?', [username, user_id]);
        res.json({ success: true, message: 'Profil berhasil diperbarui' });
    } catch (e) {
        console.error('Update profile error:', e);
        res.status(500).json({ success: false, message: e.message });
    }
});

// Serve file uploads secara statis
app.use('/uploads', express.static(uploadDir));

// ==========================================
// START SERVER & WEBSOCKET
// ==========================================



const { WebSocketServer } = require('ws');
const server = app.listen(PORT, '0.0.0.0', () => {
    initDb(); // Jalankan setelah server start sesuai saran TKJ
    console.log(`🚀 Node.js VoIP Backend running on http://0.0.0.0:${PORT}`);
});

// Set up WebSocket Server for Real-Time Chat
const wss = new WebSocketServer({ server });
const clients = new Map(); // Map untuk menyimpan userId -> Set<WebSocket>

wss.on('connection', (ws) => {
    let currentUserId = null;

    ws.on('message', async (message) => {
        try {
            const data = JSON.parse(message);
            
            if (data.type === 'auth') {
                currentUserId = data.user_id.toString();
                if (!clients.has(currentUserId)) {
                    clients.set(currentUserId, new Set());
                }
                clients.get(currentUserId).add(ws);
                console.log(`[WS] User ${currentUserId} connected. Total connections: ${clients.get(currentUserId).size}`);
                
                // Update DB and broadcast
                await pool.query("UPDATE users SET is_online = 1 WHERE id = ?", [currentUserId]);
                const statusPayload = JSON.stringify({
                    type: 'user_status',
                    data: { user_id: parseInt(currentUserId), is_online: true, last_seen: new Date().toISOString() }
                });
                wss.clients.forEach(client => {
                    if (client.readyState === 1) client.send(statusPayload);
                });
            } 
            else if (data.type === 'send_message') {
                const { conversation_id, sender_id, receiver_id, content, message_type = 'text', media_url = null } = data;
                
                // --- CEK BLOKIR ---
                if (receiver_id) {
                    const [blockedRows] = await pool.query(
                        "SELECT id FROM blocked_contacts WHERE (user_id = ? AND blocked_id = ?) OR (user_id = ? AND blocked_id = ?)",
                        [sender_id, receiver_id, receiver_id, sender_id]
                    );
                    if (blockedRows.length > 0) {
                        console.log(`[WS] Pesan ditolak karena blokir antara ${sender_id} dan ${receiver_id}`);
                        return; // Jangan simpan, jangan broadcast
                    }
                }
                
                const [result] = await pool.query(
                    "INSERT INTO messages (conversation_id, sender_id, content, message_type, media_url) VALUES (?, ?, ?, ?, ?)",
                    [conversation_id, sender_id, content, message_type, media_url]
                );

                const msgPayload = JSON.stringify({
                    type: 'new_message',
                    data: { 
                        id: result.insertId.toString(), 
                        conversation_id: conversation_id.toString(), 
                        sender_id: sender_id.toString(), 
                        content,
                        message_type,
                        media_url,
                        created_at: new Date().toISOString()
                    }
                });

                // Kirim balik ke pengirim agar UI update seketika
                if (clients.has(sender_id.toString())) {
                    clients.get(sender_id.toString()).forEach(client => {
                        if (client.readyState === 1) client.send(msgPayload);
                    });
                }
                
                // Kirim ke penerima melalui WebSocket jika sedang online
                if (receiver_id && clients.has(receiver_id.toString())) {
                    clients.get(receiver_id.toString()).forEach(client => {
                        if (client.readyState === 1) client.send(msgPayload);
                    });
                }
                
                // Kirim Push Notification via FCM jika penerima offline
                if (receiver_id) {
                    const [senderRows] = await pool.query("SELECT username FROM users WHERE id = ?", [sender_id]);
                    const senderName = senderRows.length > 0 ? senderRows[0].username : "Seseorang";
                    sendPushNotification(receiver_id, `Pesan dari ${senderName}`, content, conversation_id);
                }
            }
            else if (data.type === 'typing') {
                const { sender_id, receiver_id, is_typing } = data;
                const typingPayload = JSON.stringify({
                    type: 'typing',
                    data: { sender_id: sender_id.toString(), is_typing }
                });
                if (receiver_id && clients.has(receiver_id.toString())) {
                    clients.get(receiver_id.toString()).forEach(client => {
                        if (client.readyState === 1) client.send(typingPayload);
                    });
                }
            }
        } catch (err) {
            console.error('[WS] Error processing message:', err);
        }
    });

    ws.on('close', async () => {
        if (currentUserId && clients.has(currentUserId)) {
            const userClients = clients.get(currentUserId);
            userClients.delete(ws);
            if (userClients.size === 0) {
                clients.delete(currentUserId);
                console.log(`[WS] User ${currentUserId} fully disconnected.`);
                
                // Update DB and broadcast
                const lastSeen = new Date().toISOString();
                await pool.query("UPDATE users SET is_online = 0, last_seen = NOW() WHERE id = ?", [currentUserId]);
                const statusPayload = JSON.stringify({
                    type: 'user_status',
                    data: { user_id: parseInt(currentUserId), is_online: false, last_seen: lastSeen }
                });
                wss.clients.forEach(client => {
                    if (client.readyState === 1) client.send(statusPayload);
                });
            } else {
                console.log(`[WS] User ${currentUserId} disconnected one device. Remaining: ${userClients.size}`);
            }
        }
    });
});
