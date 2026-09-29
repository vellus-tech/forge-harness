import { useRef, useState, type FormEvent } from "react";
import { ApiError, criarRecarga } from "../api/client";

const MIN_CENTAVOS = 100;
const MAX_CENTAVOS = 50000;

type State =
  | { kind: "idle" }
  | { kind: "submitting" }
  | { kind: "error"; message: string }
  | { kind: "success" };

function gerarIdempotencyKey(): string {
  return crypto.randomUUID();
}

function parseValorParaCentavos(valor: string): number | null {
  const normalizado = valor.trim().replace(/\./g, "").replace(",", ".");
  if (normalizado === "") return null;
  const numero = Number(normalizado);
  if (!Number.isFinite(numero)) return null;
  return Math.round(numero * 100);
}

export function NovaRecargaForm({ cartaoId }: { cartaoId: string }) {
  const [valor, setValor] = useState("");
  const [state, setState] = useState<State>({ kind: "idle" });
  const idempotencyKeyRef = useRef(gerarIdempotencyKey());

  const submitting = state.kind === "submitting";

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const valorCentavos = parseValorParaCentavos(valor);
    if (valorCentavos === null || valorCentavos < MIN_CENTAVOS || valorCentavos > MAX_CENTAVOS) {
      setState({ kind: "error", message: "Informe um valor entre R$ 1,00 e R$ 500,00." });
      return;
    }

    setState({ kind: "submitting" });
    try {
      await criarRecarga({ cartaoId, valorCentavos, idempotencyKey: idempotencyKeyRef.current });
      idempotencyKeyRef.current = gerarIdempotencyKey();
      setValor("");
      setState({ kind: "success" });
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "Não foi possível concluir a recarga. Tente novamente.";
      setState({ kind: "error", message });
    }
  }

  return (
    <form onSubmit={handleSubmit} aria-label="Nova recarga">
      <label htmlFor="valor-recarga">Valor da recarga (R$)</label>
      <input
        id="valor-recarga"
        name="valor"
        inputMode="decimal"
        placeholder="0,00"
        value={valor}
        disabled={submitting}
        onChange={(e) => setValor(e.target.value)}
      />
      <button type="submit" disabled={submitting}>
        {submitting ? "Recarregando…" : "Recarregar"}
      </button>
      {state.kind === "error" && <p role="alert">{state.message}</p>}
      {state.kind === "success" && <p role="status">Recarga efetuada com sucesso.</p>}
    </form>
  );
}
