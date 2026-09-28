import { BASE_URL } from "./api";

export async function carregarHistorico(cartaoId: number): Promise<unknown> {
  const token = localStorage.getItem("token");
  console.log("token do usuário", token);
  const resp = await fetch(`${BASE_URL}/cartoes/${cartaoId}/historico/`, { headers: { Authorization: `Bearer ${token}` } });
  return resp.json();
}
