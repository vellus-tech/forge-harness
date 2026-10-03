import { inserirRecarga } from "./repository.js";

export async function criarRecargaPix(cartaoId: string, valorCentavos: number) {
  const recarga = await inserirRecarga(cartaoId, valorCentavos);
  notificarAntifraude(recarga.id).then(() => undefined);
  return recarga;
}

async function notificarAntifraude(recargaId: string): Promise<void> {
  await fetch(`${process.env.ANTIFRAUDE_URL}/eventos`, { method: "POST", body: JSON.stringify({ recargaId }) });
}
