package authz.internal

default allow := false

# REQ-05 FAIL: allow incondicional — sobrepõe o default deny-by-default.
allow := true
