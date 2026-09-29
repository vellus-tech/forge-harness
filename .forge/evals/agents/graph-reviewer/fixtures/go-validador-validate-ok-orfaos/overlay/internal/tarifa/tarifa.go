package tarifa

import "time"

const integracaoJanela = 120 * time.Minute

// Calcular devolve a tarifa em centavos, zerando dentro da janela de integração.
func Calcular(linha string, ultimo time.Time, agora time.Time) int64 {
	if agora.Sub(ultimo) <= integracaoJanela {
		return 0
	}
	return 520
}
