import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({});

// Link do comprovante de recarga para o app do próprio produto, emitido pelo endpoint autenticado /v1/recargas/:id/comprovante.
export async function receiptLink(userId: string, rechargeId: string) {
  const key = `comprovantes/${userId}/${rechargeId}.pdf`;
  return getSignedUrl(s3, new GetObjectCommand({ Bucket: process.env.RECEIPTS_BUCKET!, Key: key }), { expiresIn: 300 });
}
