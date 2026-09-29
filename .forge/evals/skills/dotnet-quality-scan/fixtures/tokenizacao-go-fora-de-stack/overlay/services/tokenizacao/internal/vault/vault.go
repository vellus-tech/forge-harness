package vault

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"sync"
	"time"
)

type Vault struct {
	mu     sync.Mutex
	tokens map[string]string
}

func New() *Vault { return &Vault{tokens: map[string]string{}} }

type pedido struct {
	PAN string `json:"pan"`
}

func (v *Vault) HandleTokenizar(w http.ResponseWriter, r *http.Request) {
	var p pedido
	_ = json.NewDecoder(r.Body).Decode(&p)
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	tok := hex.EncodeToString(b)
	v.mu.Lock()
	v.tokens[tok] = p.PAN
	v.mu.Unlock()
	_ = json.NewEncoder(w).Encode(map[string]any{"token": tok, "criado_em": time.Now()})
}
