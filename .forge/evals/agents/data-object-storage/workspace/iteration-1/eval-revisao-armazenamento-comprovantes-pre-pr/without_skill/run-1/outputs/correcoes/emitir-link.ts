import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({});

const EXPIRACAO_APP_SEGUNDOS = 15 * 60; // 15 minutos — download imediato no app.
const EXPIRACAO_PARCEIRO_SEGUNDOS = 4 * 60 * 60; // 4 horas — janela do fechamento diário.

/**
 * Link para o app mobile baixar o comprovante. Validade curta: o app baixa
 * na hora, não precisa (e não deve) manter um link de longa duração.
 */
export async function emitirLinkComprovanteApp(chave: string): Promise<string> {
  const cmd = new GetObjectCommand({ Bucket: "comprovantes-prd", Key: chave });
  return getSignedUrl(s3, cmd, { expiresIn: EXPIRACAO_APP_SEGUNDOS });
}

/**
 * Link para o e-mail de fechamento diário ao parceiro de conciliação.
 * Gerado no momento do envio (não reaproveita o link do app) e com validade
 * compatível com a janela operacional do fechamento, não com dias — e-mail é
 * um canal que pode ser encaminhado ou retido indefinidamente pela caixa de
 * entrada do destinatário, então a validade do link é a única barreira depois
 * do envio.
 *
 * TODO: registrar (log/auditoria) quem disparou a emissão e para qual
 * finalidade, para ter rastreabilidade de um artefato que sai da infra por
 * e-mail.
 */
export async function emitirLinkComprovanteParceiro(chave: string): Promise<string> {
  const cmd = new GetObjectCommand({ Bucket: "comprovantes-prd", Key: chave });
  return getSignedUrl(s3, cmd, { expiresIn: EXPIRACAO_PARCEIRO_SEGUNDOS });
}
