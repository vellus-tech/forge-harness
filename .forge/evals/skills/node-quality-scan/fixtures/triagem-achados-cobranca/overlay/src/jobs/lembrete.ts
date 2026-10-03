import type { CobrancaRepository } from "../domain/CobrancaRepository.js";

export function agendarLembrete(repo: CobrancaRepository, id: string, log: (m: string) => void) {
  repo.buscar(id).then((c) => {
      if (c?.status === "aberta") log(`lembrete enviado para ${c.id}`);
    })
    .catch((err) => log(`falha ao enviar lembrete de ${id}: ${String(err)}`));
}
