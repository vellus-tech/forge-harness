package embarque

import (
	"time"

	"github.com/axis-mobfintech/validador-embarque/internal/cartao"
	"github.com/axis-mobfintech/validador-embarque/internal/tarifa"
	"github.com/google/uuid"
)

type Validador struct{}

func NovoValidador() *Validador { return &Validador{} }

// Validar debita a tarifa do cartão e devolve o id do embarque.
func (v *Validador) Validar(uid string, linha string) (string, error) {
	c, err := cartao.Ler(uid)
	if err != nil {
		return "", err
	}
	valor := tarifa.Calcular(linha, c.UltimoEmbarque, time.Now())
	if err := c.Debitar(valor); err != nil {
		return "", err
	}
	return uuid.NewString(), nil
}
