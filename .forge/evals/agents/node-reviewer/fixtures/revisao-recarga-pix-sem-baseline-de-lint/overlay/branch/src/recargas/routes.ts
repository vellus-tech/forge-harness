import { Router } from "express";
import { criarRecargaPix } from "./service.js";

export const recargasRouter = Router();

recargasRouter.post("/recargas/pix", async (req, res) => {
  const { cartaoId, valorCentavos } = req.body;
  const recarga = await criarRecargaPix(cartaoId, valorCentavos);
  res.status(201).json(recarga);
});
