package estorno

// Devolucao registra a devolução Pix solicitada ao PSP (TASK-11).
type Devolucao struct {
	TxIDOriginal string
	E2EID        string
}
