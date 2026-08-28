package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

var DB *sql.DB

func InitDB() {
	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "127.0.0.1"
	}
	user := os.Getenv("DB_USER")
	if user == "" {
		user = "asterisk"
	}
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		password = "voip"
	}
	dbname := os.Getenv("DB_NAME")
	if dbname == "" {
		dbname = "asterisk"
	}

	dsn := fmt.Sprintf("%s:%s@tcp(%s:3306)/%s?parseTime=true", user, password, host, dbname)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Failed to open DB:", err)
	}

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Minute * 5)

	err = db.Ping()
	if err != nil {
		log.Println("⚠️ Failed to ping DB:", err)
	} else {
		log.Println("✅ Connected to MariaDB/MySQL successfully")
	}

	DB = db
	migrateDB()
}

func migrateDB() {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			username VARCHAR(255), 
			phone_number VARCHAR(255), 
			password VARCHAR(255), 
			sip_username VARCHAR(255), 
			sip_password VARCHAR(255), 
			fcm_token TEXT,
			profile_pic VARCHAR(255)
		)`,
		`CREATE TABLE IF NOT EXISTS sip_buddies (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			name VARCHAR(255), 
			host VARCHAR(255), 
			secret VARCHAR(255), 
			context VARCHAR(255), 
			username VARCHAR(255), 
			type VARCHAR(255), 
			avpf VARCHAR(255), 
			icesupport VARCHAR(255), 
			encryption VARCHAR(255), 
			rtcp_mux VARCHAR(255), 
			transport VARCHAR(255), 
			nat VARCHAR(255) DEFAULT 'yes'
		)`,
		`CREATE TABLE IF NOT EXISTS conversations (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			user1_id INT, 
			user2_id INT, 
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS messages (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			conversation_id INT, 
			sender_id INT, 
			content TEXT, 
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			is_read BOOLEAN DEFAULT FALSE,
			read_at TIMESTAMP NULL
		)`,
		`CREATE TABLE IF NOT EXISTS groups_chat (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			name VARCHAR(255), 
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS group_members (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			group_id INT, 
			user_id INT, 
			joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS group_messages (
			id INT AUTO_INCREMENT PRIMARY KEY, 
			group_id INT, 
			sender_id INT, 
			content TEXT, 
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)`,
	}

	for _, q := range queries {
		_, err := DB.Exec(q)
		if err != nil {
			log.Println("Error executing migration:", err)
		}
	}

	// Alter table for missing columns
	_, err := DB.Exec("ALTER TABLE users ADD COLUMN profile_pic VARCHAR(255)")
	if err != nil { log.Println("⚠️ Column profile_pic might already exist or err:", err.Error()) }
	
	_, err = DB.Exec("ALTER TABLE users ADD COLUMN fcm_token TEXT")
	if err != nil { log.Println("⚠️ Column fcm_token might already exist or err:", err.Error()) }

	_, err = DB.Exec("ALTER TABLE users ADD COLUMN sip_username VARCHAR(255)")
	if err != nil { log.Println("⚠️ Column sip_username might already exist or err:", err.Error()) }

	_, err = DB.Exec("ALTER TABLE users ADD COLUMN sip_password VARCHAR(255)")
	if err != nil { log.Println("⚠️ Column sip_password might already exist or err:", err.Error()) }

	_, err = DB.Exec("ALTER TABLE groups_chat ADD COLUMN description TEXT")
	if err != nil { log.Println("⚠️ Column description might already exist or err:", err.Error()) }

	_, err = DB.Exec("ALTER TABLE groups_chat ADD COLUMN avatar_url VARCHAR(255)")
	if err != nil { log.Println("⚠️ Column avatar_url might already exist or err:", err.Error()) }

	log.Println("✅ Database tables checked/initialized.")
}
