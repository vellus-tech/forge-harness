import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({});

// Link usado pelo app e enviado por e-mail ao parceiro de conciliação no fechamento diário.
export async function emitirLinkComprovante(chave: string): Promise<string> {
  const cmd = new GetObjectCommand({ Bucket: "comprovantes-prd", Key: chave });
  return getSignedUrl(s3, cmd, { expiresIn: 60 * 60 * 24 * 7 });
}
