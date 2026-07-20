package orders

// REQ-06 FAIL: decisao de acesso imperativa fora do diretorio do PEP declarado.
func CancelOrder(user User, orderID string) error {
	if !hasRole(user, "orders:admin") {
		return errForbidden
	}
	return nil
}
