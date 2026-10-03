import { useRef, useState } from "react";
import type { FormEvent } from "react";
import { ApiError, criarRecarga } from "../api/client";

// REQ-02: faixa permitida para recarga avulsa é R$ 1,00 (100 centavos) a R$ 500,00 (50000 centavos).
const VALOR_MINIMO_CENTAVOS = 100;
const VALOR_MAXIMO_CENTAVOS = 50000;
const CENTAVOS_POR_REAL = 100;

const MENSAGEM_FAIXA_INVALIDA = "Informe um valor entre R$ 1,00 e R$ 500,00.";
const MENSAGEM_ERRO_GENERICO = "Não foi possível concluir a recarga. Tente novamente.";

type State = { kind: "idle" } | { kind: "submitting" } | { kind: "error"; message: string } | { kind: "success" };

function paraCentavos(valorEmReais: string): number | null {
  const normalizado = valorEmReais.replace(",", ".").trim();
  if (normalizado === "") return null;

  const valor = Number(normalizado);
  if (!Number.isFinite(valor)) return null;

  return Math.round(valor * CENTAVOS_POR_REAL);
}

export function NovaRecargaForm({ cartaoId }: { cartaoId: string }) {
  const [valorEmReais, setValorEmReais] = useState("");
  const [state, setState] = useState<State>({ kind: "idle" });
  // DD-002: o mesmo UUID é reaproveitado em todo reenvio da MESMA solicitação
  // (duplo clique, retry de rede) para não gerar duas recargas (REQ-03); um novo
  // UUID só nasce quando o usuário inicia uma nova tentativa.
  const idempotencyKeyRef = useRef(crypto.randomUUID());

  const isSubmitting = state.kind === "submitting";

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (isSubmitting) return;

    const valorCentavos = paraCentavos(valorEmReais);
    const dentroDaFaixa =
      valorCentavos !== null && valorCentavos >= VALOR_MINIMO_CENTAVOS && valorCentavos <= VALOR_MAXIMO_CENTAVOS;
    if (!dentroDaFaixa) {
      setState({ kind: "error", message: MENSAGEM_FAIXA_INVALIDA });
      return;
    }

    setState({ kind: "submitting" });
    try {
      await criarRecarga(cartaoId, valorCentavos, idempotencyKeyRef.current);
      setState({ kind: "success" });
      idempotencyKeyRef.current = crypto.randomUUID();
      setValorEmReais("");
    } catch (erro: unknown) {
      const mensagem = erro instanceof ApiError ? erro.message : MENSAGEM_ERRO_GENERICO;
      setState({ kind: "error", message: mensagem });
    }
  }

  return (
    <form onSubmit={(event) => void handleSubmit(event)} aria-label="Nova recarga avulsa">
      <label htmlFor="valor-recarga">Valor da recarga (R$)</label>
      <input
        id="valor-recarga"
        name="valor-recarga"
        type="text"
        inputMode="decimal"
        value={valorEmReais}
        onChange={(event) => setValorEmReais(event.target.value)}
        disabled={isSubmitting}
        aria-invalid={state.kind === "error"}
        aria-describedby={state.kind === "error" ? "valor-recarga-erro" : undefined}
      />
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Enviando…" : "Solicitar recarga"}
      </button>
      {state.kind === "error" && (
        <p id="valor-recarga-erro" role="alert">
          {state.message}
        </p>
      )}
      {state.kind === "success" && <p role="status">Recarga solicitada com sucesso.</p>}
    </form>
  );
}
