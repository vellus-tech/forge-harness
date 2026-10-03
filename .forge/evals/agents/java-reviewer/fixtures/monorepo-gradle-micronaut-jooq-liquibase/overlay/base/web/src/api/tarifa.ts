export async function buscarTarifa(linha: string, token: string) {
  const resp = await fetch(`/api/tarifas/${encodeURIComponent(linha)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return resp.json();
}
