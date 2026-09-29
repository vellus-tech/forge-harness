import { randomUUID } from "node:crypto";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({});

// Chave inclui um componente não sequencial (UUID) além do transacaoId, para
// que a chave em si não vaze volume/ordem de transações caso algum controle
// de acesso futuro falhe (defesa em profundidade — o controle principal é o
// bucket privado em infra/storage/comprovantes.tf).
export async function gravarComprovante(transacaoId: string, pdf: Buffer): Promise<string> {
  const chave = `comprovantes/${transacaoId}/${randomUUID()}.pdf`;
  await s3.send(new PutObjectCommand({ Bucket: "comprovantes-prd", Key: chave, Body: pdf, ContentType: "application/pdf" }));
  return chave;
}
