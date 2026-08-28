package main

import (
	"github.com/gin-gonic/gin"
)

func SetupRoutes(r *gin.Engine) {
	// Middleware CORS
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})
	// Static route for Admin Dashboard
	r.Static("/dashboard", "./dashboard")

	api := r.Group("/api")
	{
		// Admin
		api.GET("/users", GetUsers)
		api.DELETE("/users/:id", DeleteUser)

		// Auth
		api.POST("/register", Register)
		api.POST("/login", Login)

		// Contacts
		api.GET("/contacts", GetContacts)
		api.POST("/contacts/sync", SyncContacts)

		// Chat
		api.POST("/conversations", CreateConversation)
		api.GET("/conversations", GetConversations)
		api.GET("/chat", GetChatMessages)
		api.POST("/chat", SendChatMessage)
		api.POST("/chat/read", MarkAsRead)

		// Groups
		api.POST("/groups", CreateGroup)
		api.GET("/groups", GetGroups)
		api.GET("/groups/:groupId", GetGroupDetails)
		api.GET("/groups/messages", GetGroupMessages)
		api.POST("/groups/messages", SendGroupMessage)
		api.POST("/groups/:groupId/leave", LeaveGroup)
		api.POST("/groups/:groupId/members", AddGroupMembers)
		api.PUT("/groups/:groupId", UpdateGroupInfo)

		// Notifications (FCM / Fake mode)
		api.POST("/fcm-token", SaveFCMToken)
		api.POST("/notify-call", NotifyCall)

		// SMS & AI (Fake mode)
		api.POST("/schedule-sms", ScheduleSMS)
		api.POST("/outbound-tts", OutboundTTS)

		// Profile
		api.POST("/profile/update", UpdateProfile)
		api.POST("/profile/upload-photo", UploadProfilePhoto)
	}

	// Static files for profile photos
	r.Static("/uploads", "./uploads")

	// WebSocket for realtime chat
	r.GET("/ws", ServeWS)
}
