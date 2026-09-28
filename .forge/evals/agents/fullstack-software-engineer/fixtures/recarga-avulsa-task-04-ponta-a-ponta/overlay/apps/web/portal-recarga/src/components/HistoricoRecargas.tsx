import { useEffect, useState } from "react";
import { listRecargas, type RecargaDto } from "../api/client";

type State = { kind: "loading" } | { kind: "error"; message: string } | { kind: "success"; items: RecargaDto[] };

const brl = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

export function HistoricoRecargas({ cartaoId }: { cartaoId: string }) {
  const [state, setState] = useState<State>({ kind: "loading" });

  useEffect(() => {
    listRecargas(cartaoId)
      .then((items) => setState({ kind: "success", items }))
      .catch((e: unknown) => setState({ kind: "error", message: e instanceof Error ? e.message : "Erro inesperado." }));
  }, [cartaoId]);

  if (state.kind === "loading") return <p role="status">Carregando recargas…</p>;
  if (state.kind === "error") return <p role="alert">{state.message}</p>;
  if (state.items.length === 0) return <p>Nenhuma recarga para este cartão.</p>;
  return (
    <ul aria-label="Histórico de recargas">
      {state.items.map((r) => (
        <li key={r.id}>{brl.format(r.valorCentavos / 100)} — {r.status}</li>
      ))}
    </ul>
  );
}
