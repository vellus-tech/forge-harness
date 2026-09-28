import { useRef, useState } from "react";
import { criarRecarga } from "../api/client";

type Status = { kind: "idle" } | { kind: "submitting" } | { kind: "error"; message: string } | { kind: "success" };

const VALOR_MIN_REAIS = 1;
const VALOR_MAX_REAIS = 500;

/**
 * Converte o texto digitado pelo usuário (em reais, com vírgula ou ponto) para centavos
 * inteiros — o front recebe/exibe reais para simplificar a digitação, mas o contrato
 * (DD-001 / OpenAPI) segue sempre inteiro em centavos; a conversão vive só aqui.
 */
function parseReaisParaCentavos(texto: string): number | null {
  const normalizado = texto.trim().replace(",", ".");
  if (!/^\d+(\.\d{1,2})?$/.test(normalizado)) return null;
  return Math.round(Number(normalizado) * 100);
}

export function NovaRecargaForm({ cartaoId, onSucesso }: { cartaoId: string; onSucesso?: () => void }) {
  const [valorTexto, setValorTexto] = useState("");
  const [status, setStatus] = useState<Status>({ kind: "idle" });
  // REQ-03: a mesma tentativa de envio reusa a mesma Idempotency-Key em qualquer retry
  // automático; só um novo clique do usuário gera uma chave nova.
  const idempotencyKeyRef = useRef<string | null>(null);
  const bloqueado = status.kind === "submitting";

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (bloqueado) return;

    const valorCentavos = parseReaisParaCentavos(valorTexto);
    if (valorCentavos === null || valorCentavos < VALOR_MIN_REAIS * 100 || valorCentavos > VALOR_MAX_REAIS * 100) {
      setStatus({
        kind: "error",
        message: `Informe um valor entre R$ ${VALOR_MIN_REAIS.toFixed(2).replace(".", ",")} e R$ ${VALOR_MAX_REAIS.toFixed(2).replace(".", ",")}.`,
      });
      return;
    }

    idempotencyKeyRef.current ??= crypto.randomUUID();
    setStatus({ kind: "submitting" });
    try {
      await criarRecarga({ cartaoId, valorCentavos }, idempotencyKeyRef.current);
      idempotencyKeyRef.current = null;
      setValorTexto("");
      setStatus({ kind: "success" });
      onSucesso?.();
    } catch (e: unknown) {
      // Mantém a mesma Idempotency-Key: um novo clique do usuário reenvia a MESMA tentativa,
      // nunca cria uma recarga duplicada (REQ-03).
      setStatus({ kind: "error", message: e instanceof Error ? e.message : "Não foi possível concluir a recarga." });
    }
  }

  return (
    <form onSubmit={handleSubmit} aria-label="Nova recarga avulsa">
      <label htmlFor="valor-recarga">Valor da recarga (R$)</label>
      <input
        id="valor-recarga"
        name="valor"
        inputMode="decimal"
        value={valorTexto}
        disabled={bloqueado}
        aria-invalid={status.kind === "error"}
        aria-describedby={status.kind === "error" ? "valor-recarga-erro" : undefined}
        onChange={(e) => setValorTexto(e.target.value)}
      />
      <button type="submit" disabled={bloqueado}>
        {bloqueado ? "Enviando…" : "Fazer recarga"}
      </button>
      {status.kind === "error" && (
        <p id="valor-recarga-erro" role="alert">
          {status.message}
        </p>
      )}
      {status.kind === "success" && <p role="status">Recarga solicitada com sucesso.</p>}
    </form>
  );
}
