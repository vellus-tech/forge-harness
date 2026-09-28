import { test } from "node:test";
import assert from "node:assert";
import { PaymentService } from "../src/payments/paymentService";

test("findById retorna undefined para id inexistente", async () => {
  assert.equal(await new PaymentService().findById("x"), undefined);
});
