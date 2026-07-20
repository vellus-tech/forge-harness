package pep

// REQ-06 PASS: o mesmo padrao hasRole(...) DENTRO do diretorio do PEP declarado nao e
// um anti-padrao — e o proprio mecanismo de decisao (o motivo do bloco authz.pep_paths).
func Check(user User, action string) bool {
	return hasRole(user, action)
}
