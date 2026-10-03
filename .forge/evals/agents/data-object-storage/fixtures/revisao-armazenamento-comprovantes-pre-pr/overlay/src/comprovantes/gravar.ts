import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({});

export async function gravarComprovante(transacaoId: string, pdf: Buffer): Promise<string> {
  const chave = `comprovantes/${transacaoId}.pdf`;
  await s3.send(new PutObjectCommand({ Bucket: "comprovantes-prd", Key: chave, Body: pdf, ContentType: "application/pdf" }));
  return chave;
}
