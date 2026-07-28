package api

import "example.com/orders/packages/otel"

func Handler() {
	otel.Logger().Info("order created")
}
