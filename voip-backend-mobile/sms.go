package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

type SMSReq struct {
	PhoneNumber   string `json:"phone_number"`
	Message       string `json:"message"`
	ScheduledTime string `json:"scheduled_time"`
}

func ScheduleSMS(c *gin.Context) {
	var req SMSReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	log.Printf("⏰ [SCHEDULE-SIMULATION] Dijadwalkan SMS ke %s pada %s: %s\n", req.PhoneNumber, req.ScheduledTime, req.Message)

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Pesan berhasil dijadwalkan (Simulasi)"})
}

// Simulated endpoints for FCM
type FCMReq struct {
	UserID   string `json:"user_id"`
	FCMToken string `json:"fcm_token"`
}

func SaveFCMToken(c *gin.Context) {
	var req FCMReq
	if err := c.ShouldBindJSON(&req); err == nil {
		DB.Exec("UPDATE users SET fcm_token = ? WHERE id = ?", req.FCMToken, req.UserID)
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

type NotifyReq struct {
	CallerID            string `json:"caller_id"`
	ReceiverSipUsername string `json:"receiver_sip_username"`
	CallerName          string `json:"caller_name"`
}

func NotifyCall(c *gin.Context) {
	var req NotifyReq
	if err := c.ShouldBindJSON(&req); err == nil {
		log.Printf("[FCM-SIMULATION] Notify call dari %s ke %s\n", req.CallerName, req.ReceiverSipUsername)
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}
