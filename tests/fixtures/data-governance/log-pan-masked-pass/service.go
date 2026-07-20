package payments

import "log"

// handlePaymentMasked nunca coloca o PAN bruto na linha de log — ora usa uma
// representação já mascarada (sem corrida de 13-19 dígitos), ora passa por mask()
// explicitamente (cobre o path "allow" da matriz REQ-12a). Ambas devem passar.
func handlePaymentMasked(pan string) {
	log.Printf("card ending in %s", "************1111")
	log.Printf("card: %s", mask("4111111111111111"))
}

func mask(pan string) string {
	return "****" + pan[len(pan)-4:]
}
