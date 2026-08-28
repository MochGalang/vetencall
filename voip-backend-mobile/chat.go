package main

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
)

type CreateConversationReq struct {
	User1ID string `json:"user1_id"`
	User2ID string `json:"user2_id"`
}

func CreateConversation(c *gin.Context) {
	var req CreateConversationReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	var existingID int
	err := DB.QueryRow("SELECT id FROM conversations WHERE (user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)",
		req.User1ID, req.User2ID, req.User2ID, req.User1ID).Scan(&existingID)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "conversation_id": fmt.Sprintf("%d", existingID)})
		return
	}

	res, err := DB.Exec("INSERT INTO conversations (user1_id, user2_id) VALUES (?, ?)", req.User1ID, req.User2ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	newID, _ := res.LastInsertId()
	c.JSON(http.StatusOK, gin.H{"success": true, "conversation_id": fmt.Sprintf("%d", newID)})
}

func GetConversations(c *gin.Context) {
	userID := c.Query("user_id")
	if userID == "" {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}

	query := `
		SELECT 
			c.id as conversation_id, 
			u.id as contact_id, 
			u.username as contact_username, 
			u.sip_username as contact_sip_username,
			c.created_at,
			(SELECT content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
			(SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_time,
			(SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.sender_id != ? AND (m.is_read = FALSE OR m.is_read IS NULL)) as unread_count
		FROM conversations c 
		JOIN users u ON (c.user1_id = u.id OR c.user2_id = u.id) 
		WHERE (c.user1_id = ? OR c.user2_id = ?) AND u.id != ?
		ORDER BY COALESCE(last_message_time, c.created_at) DESC
	`

	rows, err := DB.Query(query, userID, userID, userID, userID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}
	defer rows.Close()

	var convs []map[string]interface{}
	for rows.Next() {
		var convID, contactID, unreadCount int
		var contactUsername, contactSipUsername string
		var createdAt, lastMessageTime string
		var lastMessage *string

		if err := rows.Scan(&convID, &contactID, &contactUsername, &contactSipUsername, &createdAt, &lastMessage, &lastMessageTime, &unreadCount); err == nil {
			msg := ""
			if lastMessage != nil {
				msg = *lastMessage
			}
			if lastMessageTime == "" {
				lastMessageTime = createdAt
			}
			convs = append(convs, map[string]interface{}{
				"id":                   fmt.Sprintf("%d", convID),
				"contact_id":           fmt.Sprintf("%d", contactID),
				"contact_name":         contactUsername,
				"contact_sip_username": contactSipUsername,
				"last_message":         msg,
				"last_message_time":    lastMessageTime,
				"unread_count":         unreadCount,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": convs})
}

func GetChatMessages(c *gin.Context) {
	convID := c.Query("conversation_id")
	rows, err := DB.Query("SELECT id, sender_id, content, created_at FROM messages WHERE conversation_id = ? ORDER BY created_at ASC", convID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "data": []interface{}{}})
		return
	}
	defer rows.Close()

	var msgs []map[string]interface{}
	for rows.Next() {
		var id, senderID int
		var content, createdAt string
		if err := rows.Scan(&id, &senderID, &content, &createdAt); err == nil {
			msgs = append(msgs, map[string]interface{}{
				"id":         fmt.Sprintf("%d", id),
				"sender_id":  fmt.Sprintf("%d", senderID),
				"content":    content,
				"created_at": createdAt,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": msgs})
}

type ChatReq struct {
	ConversationID string `json:"conversation_id"`
	SenderID       string `json:"sender_id"`
	ReceiverID     string `json:"receiver_id"`
	Content        string `json:"content"`
}

func SendChatMessage(c *gin.Context) {
	var req ChatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	res, err := DB.Exec("INSERT INTO messages (conversation_id, sender_id, content) VALUES (?, ?, ?)",
		req.ConversationID, req.SenderID, req.Content)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	newID, _ := res.LastInsertId()

	payload := map[string]interface{}{
		"type": "new_message",
		"data": map[string]interface{}{
			"id":              fmt.Sprintf("%d", newID),
			"conversation_id": req.ConversationID,
			"sender_id":       req.SenderID,
			"content":         req.Content,
		},
	}

	BroadcastToUser(req.SenderID, payload)
	if req.ReceiverID != "" {
		sent := BroadcastToUser(req.ReceiverID, payload)
		if !sent {
			var senderName string
			DB.QueryRow("SELECT username FROM users WHERE id = ?", req.SenderID).Scan(&senderName)
			if senderName == "" {
				senderName = "Seseorang"
			}
			SendPushNotification(parseID(req.ReceiverID), fmt.Sprintf("Pesan dari %s", senderName), req.Content)
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"id": fmt.Sprintf("%d", newID)}})
}

type ReadReq struct {
	ConversationID string `json:"conversation_id"`
	UserID         string `json:"user_id"`
}

func MarkAsRead(c *gin.Context) {
	var req ReadReq
	if err := c.ShouldBindJSON(&req); err != nil || req.ConversationID == "" || req.UserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "conversation_id dan user_id wajib diisi"})
		return
	}

	DB.Exec(`UPDATE messages SET is_read = TRUE, read_at = NOW() 
		WHERE conversation_id = ? AND sender_id != ? AND (is_read = FALSE OR is_read IS NULL)`,
		req.ConversationID, req.UserID)

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Messages marked as read"})
}

func parseID(s string) int {
	var i int
	fmt.Sscanf(s, "%d", &i)
	return i
}
