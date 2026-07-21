package customer

// Cpf é marcado sensível e TEM entrada correspondente em data-classification.json
// neste mesmo diretório — REQ-12b deve passar.
type Customer struct {
	// forge:sensitive-field="cpf"
	Cpf string
}
