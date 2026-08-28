package main

import (
	"database/sql"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

type UserResponse struct {
	ID          int    `json:"id"`
	Username    string `json:"username"`
	PhoneNumber string `json:"phone_number"`
	SipUsername string `json:"sip_username"`
}

// GetUsers lists all registered users for the admin dashboard
func GetUsers(c *gin.Context) {
	rows, err := DB.Query("SELECT id, username, phone_number, sip_username FROM users ORDER BY id DESC")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch users"})
		return
	}
	defer rows.Close()

	var users []UserResponse
	for rows.Next() {
		var id int
		var username, phone, sipUser sql.NullString
		if err := rows.Scan(&id, &username, &phone, &sipUser); err != nil {
			log.Println("Error scanning user row:", err)
			continue
		}
		users = append(users, UserResponse{
			ID:          id,
			Username:    username.String,
			PhoneNumber: phone.String,
			SipUsername: sipUser.String,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    users,
	})
}

// DeleteUser deletes a user from the database and Asterisk realtime tables
func DeleteUser(c *gin.Context) {
	userID := c.Param("id")
	
	// First get the sip_username to delete from asterisk realtime tables
	var sipUsername string
	err := DB.QueryRow("SELECT sip_username FROM users WHERE id = ?", userID).Scan(&sipUsername)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "User not found"})
		return
	}

	// Begin a transaction to ensure all related records are deleted
	tx, err := DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Transaction error"})
		return
	}

	// Delete from realtime tables
	_, err = tx.Exec("DELETE FROM ps_endpoints WHERE id = ?", sipUsername)
	if err != nil { log.Println("Error deleting ps_endpoints:", err) }
	
	_, err = tx.Exec("DELETE FROM ps_aors WHERE id = ?", sipUsername)
	if err != nil { log.Println("Error deleting ps_aors:", err) }
	
	_, err = tx.Exec("DELETE FROM ps_auths WHERE id = ?", sipUsername+"-auth")
	if err != nil { log.Println("Error deleting ps_auths:", err) }
	
	_, err = tx.Exec("DELETE FROM sip_buddies WHERE username = ?", sipUsername)
	if err != nil { log.Println("Error deleting sip_buddies:", err) }

	// Delete from main users table
	_, err = tx.Exec("DELETE FROM users WHERE id = ?", userID)
	if err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete user record"})
		return
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to commit transaction"})
		return
	}

	log.Printf("User %s and their SIP extension %s have been successfully deleted", userID, sipUsername)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "User deleted successfully",
	})
}
