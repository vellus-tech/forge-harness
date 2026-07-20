package payments

import "log"

// handlePayment loga o PAN em texto claro — REQ-12a deve reprovar, mesmo com o
// bloco de governance ausente (mode:warn default) porque REQ-12 é sempre enforce.
func handlePayment(pan string) {
	log.Printf("processing card %s", "4111111111111111")
}
