import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { mailer } from "../infra/mailer";

const s3 = new S3Client({});
const EXPORTS_BUCKET = process.env.EXPORTS_BUCKET!;

// Envia ao parceiro (adquirente/integrador) o link do arquivo de conciliação do dia por e-mail.
export async function deliverReconciliation(partner: { id: string; email: string }, key: string) {
  const url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: EXPORTS_BUCKET, Key: key }), { expiresIn: 604800 });
  await mailer.send({ to: partner.email, subject: `Conciliação ${key}`, body: `Baixe em: ${url}` });
}
