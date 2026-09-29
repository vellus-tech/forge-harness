package main

import (
	"os"

	"github.com/axis-mobfintech/validador-embarque/internal/catraca"
	"github.com/axis-mobfintech/validador-embarque/internal/embarque"
	"github.com/rs/zerolog"
)

func main() {
	log := zerolog.New(os.Stdout)
	v := embarque.NovoValidador()
	catraca.Escutar(v, log)
}
