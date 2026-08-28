package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func GetContacts(c *gin.Context) {
	userID := c.Query("user_id")

	rows, err := DB.Query("SELECT id, username, sip_username, profile_pic FROM users WHERE id != ?", userID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}
	defer rows.Close()

	var contacts []map[string]interface{}
	for rows.Next() {
		var id int
		var username, sipUsername string
		var profilePic sql.NullString
		if err := rows.Scan(&id, &username, &sipUsername, &profilePic); err == nil {
			pic := ""
			if profilePic.Valid {
				pic = profilePic.String
			}
			contacts = append(contacts, map[string]interface{}{
				"id":           fmt.Sprintf("%d", id),
				"username":     username,
				"sip_username": sipUsername,
				"profile_pic":  pic,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": contacts})
}

type SyncContactsReq struct {
	UserID       string   `json:"user_id"`
	PhoneNumbers []string `json:"phone_numbers"`
}

func SyncContacts(c *gin.Context) {
	var req SyncContactsReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "user_id dan phone_numbers wajib diisi"})
		return
	}

	if len(req.PhoneNumbers) == 0 {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []interface{}{}})
		return
	}

	placeholders := make([]string, len(req.PhoneNumbers))
	args := make([]interface{}, len(req.PhoneNumbers)+1)
	for i, phone := range req.PhoneNumbers {
		placeholders[i] = "?"
		args[i] = phone
	}
	args[len(req.PhoneNumbers)] = req.UserID

	query := fmt.Sprintf(`SELECT id, username, phone_number, sip_username, profile_pic 
                          FROM users WHERE phone_number IN (%s) AND id != ?`, strings.Join(placeholders, ","))

	rows, err := DB.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	defer rows.Close()

	var contacts []map[string]interface{}
	for rows.Next() {
		var id int
		var username, phoneNumber, sipUsername string
		var profilePic sql.NullString
		if err := rows.Scan(&id, &username, &phoneNumber, &sipUsername, &profilePic); err == nil {
			pic := ""
			if profilePic.Valid {
				pic = profilePic.String
			}
			contacts = append(contacts, map[string]interface{}{
				"id":           fmt.Sprintf("%d", id),
				"username":     username,
				"phone_number": phoneNumber,
				"sip_username": sipUsername,
				"profile_pic":  pic,
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": contacts})
}
