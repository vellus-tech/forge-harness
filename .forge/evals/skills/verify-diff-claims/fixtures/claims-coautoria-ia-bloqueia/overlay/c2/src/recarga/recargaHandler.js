import { RecargaService } from "./recargaService.js";

const service = new RecargaService();

export function registrarRotas(app) {
  app.post("/api/v1/recargas", (req, res) => {
    service.validarValor(req.body.valorCentavos);
    return res.status(202).json({ status: "pendente" });
  });
}
