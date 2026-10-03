import { useState, type FormEvent } from "react";
import { ApiError, criarRecarga, type RecargaDto } from "../api/client";

type State =
  | { kind: "idle" }
  | { kind: "submitting" }
  | { kind: "error"; message: string }
  | { kind: "success"; recarga: RecargaDto };

function parseValor(raw: string): number | undefined {
  // Aceita vírgula ou ponto como separador decimal.
  const normalizado = raw.trim().replace(",", ".");
  if (!/^\d+(\.\d{1,2})?$/.test(normalizado)) return undefined;
  const valor = Number(normalizado);
  return valor > 0 ? valor : undefined;
}

export function NovaRecargaForm({ cartaoId, onCriada }: { cartaoId: string; onCriada?: (r: RecargaDto) => void }) {
  const [valorInput, setValorInput] = useState("");
  const [state, setState] = useState<State>({ kind: "idle" });

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const valor = parseValor(valorInput);
    if (valor === undefined) {
      setState({ kind: "error", message: "Informe um valor positivo com no máximo duas casas decimais." });
      return;
    }
    setState({ kind: "submitting" });
    try {
      const recarga = await criarRecarga({ cartaoId, valor });
      setState({ kind: "success", recarga });
      setValorInput("");
      onCriada?.(recarga);
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "Erro inesperado ao criar a recarga.";
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
        placeholder="25,50"
        value={valorInput}
        onChange={(e) => setValorInput(e.target.value)}
        disabled={state.kind === "submitting"}
        required
      />
      <button type="submit" disabled={state.kind === "submitting"}>
        {state.kind === "submitting" ? "Enviando…" : "Recarregar"}
      </button>
      {state.kind === "error" && <p role="alert">{state.message}</p>}
      {state.kind === "success" && <p role="status">Recarga registrada como {state.recarga.status}.</p>}
    </form>
  );
}
