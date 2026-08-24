require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const ari = require('ari-client');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// ==========================================
// 0. INIT FIREBASE ADMIN (FCM)
// ==========================================
let admin = null;
try {
    const adminModule = require('firebase-admin');
    const serviceAccount = require('./firebase-service-account.json');
    adminModule.initializeApp({
        credential: adminModule.credential.cert(serviceAccount)
    });
    admin = adminModule;
    console.log('🔥 Firebase Admin initialized successfully');
} catch (e) {
    console.log('⚠️ Firebase Admin disabled (push notifications off):', e.message);
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
            `CREATE TABLE IF NOT EXISTS sip_buddies (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), host VARCHAR(255), secret VARCHAR(255), context VARCHAR(255), username VARCHAR(255), type VARCHAR(255), avpf VARCHAR(255), icesupport VARCHAR(255), encryption VARCHAR(255), rtcp_mux VARCHAR(255), transport VARCHAR(255), nat VARCHAR(255) DEFAULT 'yes', videosupport VARCHAR(10) DEFAULT 'yes', max_video_streams INT DEFAULT 1, disallow VARCHAR(255) DEFAULT 'all', allow VARCHAR(255) DEFAULT 'vp8,vp9,h264,ulaw,alaw,opus')`,
            `CREATE TABLE IF NOT EXISTS conversations (id INT AUTO_INCREMENT PRIMARY KEY, user1_id INT, user2_id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS messages (id INT AUTO_INCREMENT PRIMARY KEY, conversation_id INT, sender_id INT, content TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS groups_chat (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS group_members (id INT AUTO_INCREMENT PRIMARY KEY, group_id INT, user_id INT, joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS group_messages (id INT AUTO_INCREMENT PRIMARY KEY, group_id INT, sender_id INT, content TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
            `CREATE TABLE IF NOT EXISTS message_reads (id INT AUTO_INCREMENT PRIMARY KEY, conversation_id INT NOT NULL, user_id INT NOT NULL, last_read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, UNIQUE KEY unique_read (conversation_id, user_id))`
        ];
        for (let q of queries) await pool.query(q);
        
        // Pengecekan kolom yang mungkin belum ada di database lama
        try {
            await pool.query("SHOW COLUMNS FROM sip_buddies LIKE 'nat'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE sip_buddies ADD COLUMN nat VARCHAR(255) DEFAULT 'yes'");
            });
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
            await pool.query("SHOW COLUMNS FROM users LIKE 'fcm_token'").then(async ([rows]) => {
                if (rows.length === 0) await pool.query("ALTER TABLE users ADD COLUMN fcm_token TEXT");
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
        const sip_username = Math.floor(1000 + Math.random() * 9000).toString();
        const sip_password_raw = Math.random().toString(36).slice(-8);
        const sip_password_hashed = await bcrypt.hash(sip_password_raw, 10);

        await pool.query(
            "INSERT INTO users (username, phone_number, password, sip_username, sip_password) VALUES (?, ?, ?, ?, ?)",
            [username, phone_number, hashedPassword, sip_username, sip_password_hashed]
        );

        // sip_buddies menyimpan password plaintext untuk Asterisk (Asterisk tidak mendukung bcrypt)
        await pool.query(
            `INSERT INTO sip_buddies (name, host, secret, context, username, type, avpf, icesupport, encryption, rtcp_mux, transport, nat, videosupport, max_video_streams, disallow, allow) 
            VALUES (?, 'dynamic', ?, 'internal', ?, 'friend', 'yes', 'yes', 'yes', 'yes', 'ws,udp', 'yes', 'yes', 1, 'all', 'vp8,vp9,h264,ulaw,alaw,opus')`,
            [sip_username, sip_password_raw, sip_username]
        );

        // Kembalikan password plaintext ke client (hanya sekali saat registrasi)
        res.json({ success: true, message: "Registrasi berhasil", data: { sip_username, sip_password: sip_password_raw } });
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

        // Verifikasi password SIP — mendukung bcrypt (user baru) dan plaintext (user lama, migrasi bertahap)
        let isMatch = false;
        const isBcryptHash = user.sip_password && user.sip_password.startsWith('$2');
        if (isBcryptHash) {
            isMatch = await bcrypt.compare(password, user.sip_password);
        } else {
            // Password lama tersimpan sebagai plaintext — bandingkan langsung lalu migrasikan ke bcrypt
            isMatch = (password === user.sip_password);
            if (isMatch) {
                const hashed = await bcrypt.hash(password, 10);
                await pool.query("UPDATE users SET sip_password = ? WHERE id = ?", [hashed, user.id]);
                console.log(`[Login] ✅ Password user ${user.sip_username} dimigrasikan ke bcrypt`);
            }
        }

        if (!isMatch) {
            console.log(`[Login] Password salah untuk user: ${sip_username}`);
            return res.status(401).json({ success: false, message: 'Password SIP salah.' });
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
    const userId = parseInt(req.query.user_id);
    if (isNaN(userId) || userId <= 0) {
        return res.status(400).json({ success: false, data: [], message: 'user_id tidak valid' });
    }
    try {
        const [contacts] = await pool.query("SELECT id, username, sip_username FROM users WHERE id != ?", [userId]);
        res.json({ success: true, data: contacts.map(c => ({ id: c.id.toString(), username: c.username, sip_username: c.sip_username })) });
    } catch (error) {
        res.json({ success: false, data: [] });
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
    const userId = parseInt(req.query.user_id);
    if (isNaN(userId) || userId <= 0) {
        return res.status(400).json({ success: false, data: [], message: 'user_id tidak valid' });
    }
    try {
        const [convs] = await pool.query(`
            SELECT 
                c.id as conversation_id, 
                u.id as contact_id, 
                u.username as contact_username, 
                u.sip_username as contact_sip_username,
                c.created_at,
                (SELECT content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_time,
                (
                    SELECT COUNT(*) FROM messages m2
                    WHERE m2.conversation_id = c.id
                    AND m2.sender_id != ?
                    AND m2.created_at > COALESCE(
                        (SELECT mr.last_read_at FROM message_reads mr WHERE mr.conversation_id = c.id AND mr.user_id = ?),
                        '1970-01-01 00:00:00'
                    )
                ) as unread_count
            FROM conversations c 
            JOIN users u ON (c.user1_id = u.id OR c.user2_id = u.id) 
            WHERE (c.user1_id = ? OR c.user2_id = ?) AND u.id != ?
            ORDER BY COALESCE(last_message_time, c.created_at) DESC
        `, [userId, userId, userId, userId, userId]);
        
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

// ==========================================
// 3.5. GROUP CHAT
// ==========================================
app.post('/api/groups', async (req, res) => {
    const { name, member_ids } = req.body;
    if (!name || !member_ids || !Array.isArray(member_ids) || member_ids.length === 0) {
        return res.status(400).json({ success: false, message: 'Nama grup dan member_ids (array) wajib diisi.' });
    }
    
    try {
        const [result] = await pool.query("INSERT INTO groups_chat (name) VALUES (?)", [name]);
        const groupId = result.insertId;
        
        const values = member_ids.map(id => [groupId, id]);
        await pool.query("INSERT INTO group_members (group_id, user_id) VALUES ?", [values]);
        
        res.json({ success: true, group_id: groupId.toString() });
    } catch (error) {
        console.error('[API] Error creating group:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.get('/api/groups', async (req, res) => {
    const userId = req.query.user_id;
    try {
        const [groups] = await pool.query(`
            SELECT 
                g.id as group_id, 
                g.name as group_name,
                g.created_at,
                (SELECT content FROM group_messages gm WHERE gm.group_id = g.id ORDER BY gm.created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM group_messages gm WHERE gm.group_id = g.id ORDER BY gm.created_at DESC LIMIT 1) as last_message_time,
                (SELECT GROUP_CONCAT(u.username SEPARATOR ', ') FROM group_members m JOIN users u ON m.user_id = u.id WHERE m.group_id = g.id) as members_text
            FROM groups_chat g
            JOIN group_members gm ON g.id = gm.group_id
            WHERE gm.user_id = ?
            ORDER BY COALESCE(last_message_time, g.created_at) DESC
        `, [userId]);
        
        res.json({ 
            success: true, 
            data: groups.map(g => ({ 
                id: g.group_id.toString(), 
                name: g.group_name,
                last_message: g.last_message,
                last_message_time: g.last_message_time || g.created_at,
                members_text: g.members_text,
                unread_count: 0
            })) 
        });
    } catch (error) {
        console.error('[API] Error getting groups:', error);
        res.json({ success: false, data: [] });
    }
});

app.get('/api/groups/messages', async (req, res) => {
    const groupId = req.query.group_id;
    try {
        const [messages] = await pool.query(`
            SELECT m.*, u.username as sender_name 
            FROM group_messages m
            JOIN users u ON m.sender_id = u.id
            WHERE m.group_id = ? 
            ORDER BY m.created_at ASC
        `, [groupId]);
        
        res.json({ 
            success: true, 
            data: messages.map(m => ({ 
                id: m.id.toString(), 
                sender_id: m.sender_id.toString(), 
                sender_name: m.sender_name,
                content: m.content,
                created_at: m.created_at 
            })) 
        });
    } catch (error) {
        res.json({ success: false, data: [] });
    }
});

// ==========================================
// 4. CHAT SYSTEM & PUSH NOTIFICATION
// ==========================================
async function sendPushNotification(receiver_id, title, body) {
    if (!admin) return;
    try {
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
    const convId = parseInt(req.query.conversation_id);
    if (isNaN(convId) || convId <= 0) {
        return res.status(400).json({ success: false, data: [], message: 'conversation_id tidak valid' });
    }
    try {
        const [messages] = await pool.query("SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC", [convId]);
        res.json({ 
            success: true, 
            data: messages.map(m => ({ 
                id: m.id.toString(), 
                sender_id: m.sender_id.toString(), 
                content: m.content,
                created_at: m.created_at 
            })) 
        });
    } catch (error) {
        res.json({ success: false, data: [] });
    }
});

// Tandai pesan sebagai sudah dibaca (dipanggil saat user membuka chat)
app.post('/api/chat/read', async (req, res) => {
    const { conversation_id, user_id } = req.body;
    const convId = parseInt(conversation_id);
    const userId = parseInt(user_id);
    if (isNaN(convId) || isNaN(userId) || convId <= 0 || userId <= 0) {
        return res.status(400).json({ success: false, message: 'conversation_id dan user_id tidak valid' });
    }
    try {
        await pool.query(`
            INSERT INTO message_reads (conversation_id, user_id, last_read_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE last_read_at = NOW()
        `, [convId, userId]);
        res.json({ success: true });
    } catch (error) {
        console.error('[API] Error POST /api/chat/read:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post('/api/chat', async (req, res) => {
    const { conversation_id, sender_id, receiver_id, content } = req.body;
    try {
        const [result] = await pool.query(
            "INSERT INTO messages (conversation_id, sender_id, content) VALUES (?, ?, ?)",
            [conversation_id, sender_id, content]
        );
        
        // Broadcast via WebSocket
        const msgPayload = JSON.stringify({
            type: 'new_message',
            data: {
                id: result.insertId.toString(),
                conversation_id: conversation_id.toString(),
                sender_id: sender_id.toString(),
                content: content,
                created_at: new Date().toISOString()
            }
        });
        
        if (clients.has(sender_id.toString())) {
            clients.get(sender_id.toString()).forEach(client => {
                if (client.readyState === 1) client.send(msgPayload);
            });
        }
        if (receiver_id && clients.has(receiver_id.toString())) {
            clients.get(receiver_id.toString()).forEach(client => {
                if (client.readyState === 1) client.send(msgPayload);
            });
        } else if (receiver_id) {
            // User is offline or background, send Push Notification
            const [senderRows] = await pool.query("SELECT username FROM users WHERE id = ?", [sender_id]);
            const senderName = senderRows.length > 0 ? senderRows[0].username : "Seseorang";
            sendPushNotification(receiver_id, `Pesan dari ${senderName}`, content);
        }

        res.json({ success: true, data: { id: result.insertId.toString() } });
    } catch (error) {
        console.error('[API] Error POST /api/chat:', error);
        res.status(500).json({ success: false, message: error.message });
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
async function setupARI() {
    try {
        ariClient = await ari.connect(process.env.ARI_URL, process.env.ARI_USERNAME, process.env.ARI_PASSWORD);
        console.log('✅ Connected to Asterisk ARI successfully!');
        ariClient.start(process.env.ARI_APP_NAME);
    } catch (err) {
        console.log('⚠️ ARI belum terkoneksi, tapi API Node.js tetap jalan.');
    }
}
setupARI();

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
            } 
            else if (data.type === 'send_message') {
                const { conversation_id, sender_id, receiver_id, content } = data;
                
                // Simpan ke DB
                const [result] = await pool.query(
                    "INSERT INTO messages (conversation_id, sender_id, content) VALUES (?, ?, ?)",
                    [conversation_id, sender_id, content]
                );
                
                const msgPayload = JSON.stringify({
                    type: 'new_message',
                    data: {
                        id: result.insertId.toString(),
                        conversation_id: conversation_id.toString(),
                        sender_id: sender_id.toString(),
                        content: content,
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
                    sendPushNotification(receiver_id, `Pesan dari ${senderName}`, content);
                }
            }
            else if (data.type === 'send_group_message') {
                const { group_id, sender_id, content } = data;
                
                // Simpan ke DB
                const [result] = await pool.query(
                    "INSERT INTO group_messages (group_id, sender_id, content) VALUES (?, ?, ?)",
                    [group_id, sender_id, content]
                );
                
                // Dapatkan detail sender
                const [senderRows] = await pool.query("SELECT username FROM users WHERE id = ?", [sender_id]);
                const senderName = senderRows.length > 0 ? senderRows[0].username : "Unknown";

                const msgPayload = JSON.stringify({
                    type: 'new_group_message',
                    data: {
                        id: result.insertId.toString(),
                        group_id: group_id.toString(),
                        sender_id: sender_id.toString(),
                        sender_name: senderName,
                        content: content,
                        created_at: new Date().toISOString()
                    }
                });

                // Ambil semua member grup
                const [members] = await pool.query("SELECT user_id FROM group_members WHERE group_id = ?", [group_id]);
                
                // Broadcast ke semua member (termasuk sender agar UI update)
                for (const member of members) {
                    const memberId = member.user_id.toString();
                    if (clients.has(memberId)) {
                        clients.get(memberId).forEach(client => {
                            if (client.readyState === 1) client.send(msgPayload);
                        });
                    } else if (memberId !== sender_id.toString()) {
                        // Push Notification (opsional)
                        sendPushNotification(memberId, `Grup Pesan Baru`, `${senderName}: ${content}`);
                    }
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

    ws.on('close', () => {
        if (currentUserId && clients.has(currentUserId)) {
            const userClients = clients.get(currentUserId);
            userClients.delete(ws);
            if (userClients.size === 0) {
                clients.delete(currentUserId);
                console.log(`[WS] User ${currentUserId} fully disconnected.`);
            } else {
                console.log(`[WS] User ${currentUserId} disconnected one device. Remaining: ${userClients.size}`);
            }
        }
    });
});
