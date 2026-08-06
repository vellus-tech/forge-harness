package authz.legacy

# REQ-05 FAIL: nenhuma regra de fail-closed declarada para este package.
allow {
    input.user.admin == true
}
