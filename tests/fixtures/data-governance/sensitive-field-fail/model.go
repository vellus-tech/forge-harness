package customer

// Cpf é um campo sensível (REQ-12b) marcado via comentário, mas este diretório NÃO
// tem um data-classification.json com entrada "cpf" — deve reprovar.
type Customer struct {
	// forge:sensitive-field="cpf"
	Cpf string
}
