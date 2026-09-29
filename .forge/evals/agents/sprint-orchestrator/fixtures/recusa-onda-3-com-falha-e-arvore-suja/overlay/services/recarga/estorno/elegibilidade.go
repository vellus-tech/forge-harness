package estorno

import "time"

// Elegivel aceita estorno de recarga não utilizada em até 7 dias (TASK-10).
func Elegivel(recarga, agora time.Time, utilizada bool) bool {
	return !utilizada && agora.Sub(recarga) <= 7*24*time.Hour
}
