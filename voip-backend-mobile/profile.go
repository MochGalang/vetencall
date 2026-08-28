package main

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
)

type UpdateProfileReq struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
}

func UpdateProfile(c *gin.Context) {
	var req UpdateProfileReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	_, err := DB.Exec("UPDATE users SET username = ? WHERE id = ?", req.Username, req.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update profile"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Profile updated successfully"})
}

func UploadProfilePhoto(c *gin.Context) {
	userID := c.PostForm("user_id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "user_id is required"})
		return
	}

	file, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "photo is required"})
		return
	}

	// Create uploads directory if not exists
	uploadDir := "./uploads"
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		os.Mkdir(uploadDir, 0755)
	}

	filename := fmt.Sprintf("%s_%d%s", userID, time.Now().Unix(), filepath.Ext(file.Filename))
	dst := filepath.Join(uploadDir, filename)

	if err := c.SaveUploadedFile(file, dst); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to save photo"})
		return
	}

	photoURL := "/uploads/" + filename

	_, err = DB.Exec("UPDATE users SET profile_pic = ? WHERE id = ?", photoURL, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update database"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Photo uploaded successfully",
		"data": gin.H{
			"profile_pic": photoURL,
		},
	})
}
