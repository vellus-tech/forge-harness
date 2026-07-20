package authz.orders

# deny-by-default (REQ-05): fail-closed, allow só quando a condição casa.
default allow := false

allow {
    input.method == "GET"
    input.path == ["orders", "health"]
}

allow {
    input.method == "POST"
    input.path == ["orders"]
    input.user.permissions[_] == "orders:write"
}
