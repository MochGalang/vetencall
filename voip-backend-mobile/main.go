package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file if exists
	err := godotenv.Load()
	if err != nil {
		log.Println("No .env file found, relying on environment variables")
	}

	// Initialize database
	InitDB()

	// Initialize Firebase
	InitFirebase()

	// Initialize Gin router
	r := gin.Default()

	// Setup routes
	SetupRoutes(r)

	// Get PORT from env or default to 3001
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	log.Printf("🚀 Golang VoIP Backend running on http://0.0.0.0:%s", port)
	r.Run("0.0.0.0:" + port)
}
