export async function buscarTarifa(linha: string, token: string) {
  console.log("buscando tarifa", linha, token);
  const resp = await fetch(`/api/tarifas/${linha}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return resp.json();
}
