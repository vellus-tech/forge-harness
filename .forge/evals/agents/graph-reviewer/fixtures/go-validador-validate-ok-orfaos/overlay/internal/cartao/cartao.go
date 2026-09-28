package cartao

import (
	"errors"
	"time"

	"github.com/axis-mobfintech/validador-embarque/internal/tarifa"
)

type Cartao struct {
	UID            string
	Saldo          int64
	UltimoEmbarque time.Time
}

var ErrSaldo = errors.New("saldo insuficiente")

func Ler(uid string) (*Cartao, error) { return &Cartao{UID: uid, Saldo: 1000}, nil }

func (c *Cartao) Debitar(v int64) error {
	if c.Saldo < v {
		return ErrSaldo
	}
	c.Saldo -= v
	_ = tarifa.Calcular
	return nil
}
