package main

import (
	"database/sql"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type RegisterReq struct {
	Username    string `json:"username"`
	PhoneNumber string `json:"phone_number"`
	Password    string `json:"password"`
}

func Register(c *gin.Context) {
	var req RegisterReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request data"})
		return
	}

	if req.Username == "" || req.PhoneNumber == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Data tidak lengkap."})
		return
	}

	var existingID int
	err := DB.QueryRow("SELECT id FROM users WHERE phone_number = ? OR username = ?", req.PhoneNumber, req.Username).Scan(&existingID)
	if err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Nomor HP/Username sudah terdaftar."})
		return
	} else if err != sql.ErrNoRows {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Database error: " + err.Error()})
		return
	}

	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(req.Password), 10)
	sipUsername := req.PhoneNumber
	sipPassword := req.PhoneNumber

	res, err := DB.Exec("INSERT INTO users (username, phone_number, password, sip_username, sip_password) VALUES (?, ?, ?, ?, ?)",
		req.Username, req.PhoneNumber, hashedPassword, sipUsername, sipPassword)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Server error", "error": err.Error()})
		return
	}

	userID, _ := res.LastInsertId()

	// Insert into sip_buddies
	DB.Exec(`INSERT INTO sip_buddies (name, host, secret, context, username, type, avpf, icesupport, encryption, rtcp_mux, transport, nat) 
             VALUES (?, 'dynamic', ?, 'internal', ?, 'friend', 'yes', 'yes', 'yes', 'yes', 'ws,udp', 'yes')`,
		sipUsername, sipPassword, sipUsername)

	// PJSIP Realtime inserts
	DB.Exec(`INSERT INTO ps_aors (id, max_contacts, remove_existing) VALUES (?, 5, 'yes')
		ON DUPLICATE KEY UPDATE max_contacts = VALUES(max_contacts), remove_existing = VALUES(remove_existing)`, sipUsername)

	DB.Exec(`INSERT INTO ps_auths (id, auth_type, password, username) VALUES (?, 'userpass', ?, ?)
		ON DUPLICATE KEY UPDATE password = VALUES(password), username = VALUES(username)`, sipUsername+"-auth", sipPassword, sipUsername)

	DB.Exec(`INSERT INTO ps_endpoints (
			id, transport, aors, auth, context, disallow, allow, direct_media, force_rport, rewrite_contact, rtcp_mux, rtp_symmetric, timers, webrtc, use_avpf, dtls_auto_generate_cert
		) VALUES (?, 'transport-ws', ?, ?, 'from-internal', 'all', 'opus,ulaw,alaw,vp8,h264', 'no', 'yes', 'yes', 'yes', 'yes', 'no', 'yes', 'yes', 'yes')
		ON DUPLICATE KEY UPDATE transport = VALUES(transport), aors = VALUES(aors), auth = VALUES(auth)`, sipUsername, sipUsername, sipUsername+"-auth")

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Registrasi berhasil",
		"data": gin.H{
			"id":           fmt.Sprintf("%d", userID),
			"username":     req.Username,
			"phone_number": req.PhoneNumber,
			"sip_username": sipUsername,
			"sip_password": sipPassword,
		},
	})
}

type LoginReq struct {
	SipUsername string `json:"sip_username"`
	Password    string `json:"password"`
}

func Login(c *gin.Context) {
	var req LoginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "SIP username dan password wajib diisi."})
		return
	}

	var user struct {
		ID          int
		Username    string
		PhoneNumber string
		SipUsername string
		SipPassword string
		Password    string
		ProfilePic  sql.NullString
	}

	err := DB.QueryRow("SELECT id, username, phone_number, sip_username, sip_password, password, profile_pic FROM users WHERE sip_username = ? OR phone_number = ?", req.SipUsername, req.SipUsername).
		Scan(&user.ID, &user.Username, &user.PhoneNumber, &user.SipUsername, &user.SipPassword, &user.Password, &user.ProfilePic)

	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Ekstensi SIP atau Nomor HP tidak ditemukan."})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Password salah."})
		return
	}

	profilePic := ""
	if user.ProfilePic.Valid {
		profilePic = user.ProfilePic.String
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"id":           fmt.Sprintf("%d", user.ID),
			"username":     user.Username,
			"phone_number": user.PhoneNumber,
			"sip_username": user.SipUsername,
			"sip_password": user.SipPassword,
			"profile_pic":  profilePic,
		},
	})
}
