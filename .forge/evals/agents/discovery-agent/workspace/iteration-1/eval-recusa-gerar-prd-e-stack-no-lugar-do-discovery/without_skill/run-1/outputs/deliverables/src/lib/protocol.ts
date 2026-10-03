// Gera um número de protocolo legível para o registro de item perdido.
// Formato: AEP-<timestamp base36>-<sufixo aleatório de 4 chars>.
export function generateProtocol(): string {
  const timestampPart = Date.now().toString(36).toUpperCase();
  const randomPart = Math.random().toString(36).slice(2, 6).toUpperCase();
  return `AEP-${timestampPart}-${randomPart}`;
}
