export const LIMIAR_SALDO_PADRAO_CENTAVOS = 1000;

export async function enviarPushFcm(tokenDispositivo: string, titulo: string, corpo: string): Promise<void> {
  // publica em notificacoes.push; o worker entrega via FCM
  throw new Error("não implementado");
}
