import type { FastifyInstance } from "fastify";
import type { CobrancaRepository } from "./domain/CobrancaRepository.js";

export function registrarRotas(app: FastifyInstance, repo: CobrancaRepository) {
  app.get<{ Params: { id: string } }>("/cobrancas/:id", async (req) => repo.buscar(req.params.id));
  app.post<{ Params: { id: string } }>("/cobrancas/:id/pagamento", async (req, reply) => {
    await repo.marcarPaga(req.params.id);
    return reply.code(204).send();
  });
}
