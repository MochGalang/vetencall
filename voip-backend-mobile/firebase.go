package main

import (
	"log"

	"firebase.google.com/go/v4"
)

var FirebaseApp *firebase.App

func InitFirebase() {
	// For simulation/skip mode, we just leave FirebaseApp as nil
	log.Println("🔥 Firebase Admin disabled for local testing (Simulation mode)")
}

func SendPushNotification(receiverID int, title, body string) {
	// Fallback simulation
	log.Printf("[FCM-SIMULATION] Push sent to user %d: %s - %s\n", receiverID, title, body)
}
