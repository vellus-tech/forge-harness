package com.example.orders

// REQ-06 FAIL: decorator de role ad-hoc fora do diretorio do PEP declarado.
@RolesAllowed("ORDERS_ADMIN")
class CancelOrderHandler {
    fun handle(orderId: String) { /* ... */ }
}
