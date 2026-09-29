// Validade do bilhete: 2 horas a partir da primeira validação.
export function validUntil(firstTapIso) {
  const t = new Date(firstTapIso);
  return new Date(t.getTime() + 2 * 60 * 60 * 1000).toISOString();
}
