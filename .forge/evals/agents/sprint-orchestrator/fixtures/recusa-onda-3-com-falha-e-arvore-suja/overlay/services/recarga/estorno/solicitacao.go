package estorno

// Solicitacao é o pedido de estorno de uma recarga Pix (TASK-09).
type Solicitacao struct {
	TxID          string
	CartaoID      string
	ValorCentavos int64
}
