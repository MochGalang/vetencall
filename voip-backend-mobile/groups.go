package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type CreateGroupReq struct {
	Name      string   `json:"name"`
	MemberIDs []string `json:"member_ids"`
	CreatorID string   `json:"creator_id"`
}

func CreateGroup(c *gin.Context) {
	var req CreateGroupReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	if req.Name == "" || len(req.MemberIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Nama grup dan member_ids wajib diisi"})
		return
	}

	// Inject creator_id if not present
	if req.CreatorID != "" {
		found := false
		for _, id := range req.MemberIDs {
			if id == req.CreatorID {
				found = true
				break
			}
		}
		if !found {
			req.MemberIDs = append(req.MemberIDs, req.CreatorID)
		}
	}

	res, err := DB.Exec("INSERT INTO groups_chat (name) VALUES (?)", req.Name)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	groupID, _ := res.LastInsertId()

	for _, memberID := range req.MemberIDs {
		DB.Exec("INSERT INTO group_members (group_id, user_id) VALUES (?, ?)", groupID, memberID)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "group_id": fmt.Sprintf("%d", groupID)})
}

func GetGroups(c *gin.Context) {
	userID := c.Query("user_id")
	if userID == "" {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}

	query := `
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
	`

	rows, err := DB.Query(query, userID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}
	defer rows.Close()

	var groups []map[string]interface{}
	for rows.Next() {
		var groupID int
		var groupName, createdAt, membersText string
		var lastMessage, lastMessageTime *string

		if err := rows.Scan(&groupID, &groupName, &createdAt, &lastMessage, &lastMessageTime, &membersText); err == nil {
			msg := ""
			if lastMessage != nil {
				msg = *lastMessage
			}
			msgTime := createdAt
			if lastMessageTime != nil {
				msgTime = *lastMessageTime
			}

			groups = append(groups, map[string]interface{}{
				"id":                fmt.Sprintf("%d", groupID),
				"name":              groupName,
				"last_message":      msg,
				"last_message_time": msgTime,
				"members_text":      membersText,
				"unread_count":      0, // Future implementation
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": groups})
}

func GetGroupDetails(c *gin.Context) {
	groupID := c.Param("groupId")

	var name, createdAt string
	var description, avatarURL sql.NullString

	err := DB.QueryRow("SELECT name, description, avatar_url, created_at FROM groups_chat WHERE id = ?", groupID).Scan(&name, &description, &avatarURL, &createdAt)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Grup tidak ditemukan"})
		return
	}

	rows, err := DB.Query("SELECT u.id, u.username, u.sip_username, u.fcm_token FROM group_members gm JOIN users u ON gm.user_id = u.id WHERE gm.group_id = ?", groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	defer rows.Close()

	var members []map[string]interface{}
	for rows.Next() {
		var id int
		var username, sipUsername string
		var fcmToken sql.NullString
		if err := rows.Scan(&id, &username, &sipUsername, &fcmToken); err == nil {
			members = append(members, map[string]interface{}{
				"id":           fmt.Sprintf("%d", id),
				"name":         username,
				"sip_username": sipUsername,
				"avatar_url":   "",
			})
		}
	}

	desc := ""
	if description.Valid {
		desc = description.String
	}
	avatar := ""
	if avatarURL.Valid {
		avatar = avatarURL.String
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": map[string]interface{}{
			"id":          groupID,
			"name":        name,
			"description": desc,
			"avatar_url":  avatar,
			"created_at":  createdAt,
			"members":     members,
		},
	})
}

func GetGroupMessages(c *gin.Context) {
	groupID := c.Query("group_id")
	rows, err := DB.Query(`
		SELECT m.id, m.sender_id, m.content, m.created_at, u.username as sender_name 
		FROM group_messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.group_id = ? 
		ORDER BY m.created_at ASC
	`, groupID)
	
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}
	defer rows.Close()

	var msgs []map[string]interface{}
	for rows.Next() {
		var id, senderID int
		var content, createdAt, senderName string
		if err := rows.Scan(&id, &senderID, &content, &createdAt, &senderName); err == nil {
			msgs = append(msgs, map[string]interface{}{
				"id":          fmt.Sprintf("%d", id),
				"sender_id":   fmt.Sprintf("%d", senderID),
				"sender_name": senderName,
				"content":     content,
				"created_at":  createdAt,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": msgs})
}

type GroupChatReq struct {
	GroupID  string `json:"group_id"`
	SenderID string `json:"sender_id"`
	Content  string `json:"content"`
}

func SendGroupMessage(c *gin.Context) {
	var req GroupChatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	res, err := DB.Exec("INSERT INTO group_messages (group_id, sender_id, content) VALUES (?, ?, ?)",
		req.GroupID, req.SenderID, req.Content)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	newID, _ := res.LastInsertId()

	var senderName string
	DB.QueryRow("SELECT username FROM users WHERE id = ?", req.SenderID).Scan(&senderName)
	if senderName == "" {
		senderName = "Unknown"
	}

	payload := map[string]interface{}{
		"type": "new_group_message",
		"data": map[string]interface{}{
			"id":          fmt.Sprintf("%d", newID),
			"group_id":    req.GroupID,
			"sender_id":   req.SenderID,
			"sender_name": senderName,
			"content":     req.Content,
		},
	}

	// Broadcast to all members
	rows, err := DB.Query("SELECT user_id FROM group_members WHERE group_id = ?", req.GroupID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var memberID int
			if err := rows.Scan(&memberID); err == nil {
				memberIDStr := fmt.Sprintf("%d", memberID)
				
				sent := BroadcastToUser(memberIDStr, payload)
				
				// Push notification if offline and not the sender
				if !sent && memberIDStr != req.SenderID {
					SendPushNotification(memberID, fmt.Sprintf("Pesan Grup dari %s", senderName), req.Content)
				}
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"id": fmt.Sprintf("%d", newID)}})
}

type LeaveGroupReq struct {
	UserID string `json:"user_id"`
}

func LeaveGroup(c *gin.Context) {
	groupID := c.Param("groupId")
	var req LeaveGroupReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	_, err := DB.Exec("DELETE FROM group_members WHERE group_id = ? AND user_id = ?", groupID, req.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Berhasil keluar dari grup"})
}

type AddMembersReq struct {
	UserIDs []string `json:"user_ids"`
}

func AddGroupMembers(c *gin.Context) {
	groupID := c.Param("groupId")
	var req AddMembersReq
	if err := c.ShouldBindJSON(&req); err != nil || len(req.UserIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	for _, id := range req.UserIDs {
		// INSERT IGNORE not fully standard without proper setup, safer to check or let it fail gracefully
		DB.Exec("INSERT IGNORE INTO group_members (group_id, user_id) VALUES (?, ?)", groupID, id)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Berhasil menambah anggota"})
}

func UpdateGroupInfo(c *gin.Context) {
	groupID := c.Param("groupId")
	var req map[string]interface{}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	var updates []string
	var params []interface{}

	if name, ok := req["name"].(string); ok {
		updates = append(updates, "name = ?")
		params = append(params, name)
	}
	if description, ok := req["description"].(string); ok {
		updates = append(updates, "description = ?")
		params = append(params, description)
	}
	if avatarURL, ok := req["avatar_url"].(string); ok {
		updates = append(updates, "avatar_url = ?")
		params = append(params, avatarURL)
	}

	if len(updates) > 0 {
		query := "UPDATE groups_chat SET " + strings.Join(updates, ", ") + " WHERE id = ?"
		params = append(params, groupID)
		_, err := DB.Exec(query, params...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Grup berhasil diupdate"})
}
