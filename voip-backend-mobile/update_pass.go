package main

import (
	"database/sql"
	"fmt"
	"golang.org/x/crypto/bcrypt"
	_ "github.com/go-sql-driver/mysql"
)

func main() {
	db, err := sql.Open("mysql", "asterisk:voip@tcp(127.0.0.1:3306)/asterisk")
	if err != nil {
		fmt.Println("DB error:", err)
		return
	}
	defer db.Close()

	hash, _ := bcrypt.GenerateFromPassword([]byte("123456"), 10)
	
	_, err = db.Exec("UPDATE users SET password = ? WHERE phone_number IN ('1010', '2020')", hash)
	if err != nil {
		fmt.Println("Update error:", err)
		return
	}
	fmt.Println("Password updated successfully!")
}
