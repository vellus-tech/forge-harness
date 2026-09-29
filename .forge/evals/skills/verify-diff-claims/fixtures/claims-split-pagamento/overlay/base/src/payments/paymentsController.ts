import { Router } from "express";
import { PaymentService } from "./paymentService";

export const paymentsRouter = Router();
const service = new PaymentService();

paymentsRouter.get("/api/v1/payments/:id", async (req, res) => {
  const payment = await service.findById(req.params.id);
  if (!payment) return res.status(404).end();
  return res.json(payment);
});
