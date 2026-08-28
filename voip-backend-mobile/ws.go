package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

var clients = make(map[string]map[*websocket.Conn]bool)
var clientsMutex sync.RWMutex

func ServeWS(c *gin.Context) {
	ws, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Println("WS Upgrade error:", err)
		return
	}
	defer ws.Close()

	var currentUserID string

	for {
		_, message, err := ws.ReadMessage()
		if err != nil {
			break
		}

		var data map[string]interface{}
		if err := json.Unmarshal(message, &data); err != nil {
			continue
		}

		msgType, _ := data["type"].(string)

		if msgType == "auth" {
			userID, _ := data["user_id"].(string)
			if userID == "" {
				userIDRaw, ok := data["user_id"].(float64)
				if ok {
					userID = fmt.Sprintf("%d", int(userIDRaw))
				}
			}
			currentUserID = userID

			clientsMutex.Lock()
			if clients[currentUserID] == nil {
				clients[currentUserID] = make(map[*websocket.Conn]bool)
			}
			clients[currentUserID][ws] = true
			clientsMutex.Unlock()
			log.Printf("[WS] User %s connected\n", currentUserID)
		} else if msgType == "typing" {
			payloadData, _ := data["data"].(map[string]interface{})
			receiverID, _ := payloadData["receiver_id"].(string)
			if receiverID != "" {
				BroadcastToUser(receiverID, data)
			}
		} else if msgType == "send_group_message" {
			payloadData, _ := data["data"].(map[string]interface{})
			groupID, _ := payloadData["group_id"].(string)
			senderID, _ := payloadData["sender_id"].(string)
			content, _ := payloadData["content"].(string)
			
			if groupID != "" && senderID != "" && content != "" {
				res, err := DB.Exec("INSERT INTO group_messages (group_id, sender_id, content) VALUES (?, ?, ?)", groupID, senderID, content)
				if err == nil {
					newID, _ := res.LastInsertId()
					
					var senderName string
					DB.QueryRow("SELECT username FROM users WHERE id = ?", senderID).Scan(&senderName)
					if senderName == "" { senderName = "Unknown" }

					msgPayload := map[string]interface{}{
						"type": "new_group_message",
						"data": map[string]interface{}{
							"id": fmt.Sprintf("%d", newID),
							"group_id": groupID,
							"sender_id": senderID,
							"sender_name": senderName,
							"content": content,
						},
					}

					rows, err := DB.Query("SELECT user_id FROM group_members WHERE group_id = ?", groupID)
					if err == nil {
						for rows.Next() {
							var memberID int
							if err := rows.Scan(&memberID); err == nil {
								memberIDStr := fmt.Sprintf("%d", memberID)
								sent := BroadcastToUser(memberIDStr, msgPayload)
								if !sent && memberIDStr != senderID {
									SendPushNotification(memberID, fmt.Sprintf("Pesan Grup dari %s", senderName), content)
								}
							}
						}
						rows.Close()
					}
				}
			}
		}
	}

	if currentUserID != "" {
		clientsMutex.Lock()
		delete(clients[currentUserID], ws)
		if len(clients[currentUserID]) == 0 {
			delete(clients, currentUserID)
		}
		clientsMutex.Unlock()
		log.Printf("[WS] User %s disconnected\n", currentUserID)
	}
}

func BroadcastToUser(userID string, message interface{}) bool {
	clientsMutex.RLock()
	defer clientsMutex.RUnlock()

	userConns := clients[userID]
	if len(userConns) == 0 {
		return false
	}

	for ws := range userConns {
		ws.WriteJSON(message)
	}
	return true
}
