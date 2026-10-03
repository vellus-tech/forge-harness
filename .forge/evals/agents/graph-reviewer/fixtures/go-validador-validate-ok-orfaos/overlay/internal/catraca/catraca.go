package catraca

import (
	"github.com/axis-mobfintech/validador-embarque/internal/embarque"
	"github.com/rs/zerolog"
)

// Escutar lê UIDs da leitora NFC da catraca e libera o giro quando o embarque é validado.
func Escutar(v *embarque.Validador, log zerolog.Logger) {
	log.Info().Msg("catraca pronta")
}
