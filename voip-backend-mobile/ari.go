package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

type OutboundReq struct {
	TargetNumber string `json:"target_number"`
	Message      string `json:"message"`
}

func OutboundTTS(c *gin.Context) {
	var req OutboundReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	log.Printf("[ARI-SIMULATION] Call Outbound TTS to %s: %s\n", req.TargetNumber, req.Message)

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Panggilan AI sedang diproses (Simulasi)"})
}
