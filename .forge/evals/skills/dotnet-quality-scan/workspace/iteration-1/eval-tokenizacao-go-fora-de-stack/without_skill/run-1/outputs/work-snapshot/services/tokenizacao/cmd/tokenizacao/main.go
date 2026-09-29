package main

import (
	"log"
	"net/http"

	"github.com/example/tokenizacao/internal/vault"
)

func main() {
	v := vault.New()
	http.HandleFunc("/tokens", v.HandleTokenizar)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
