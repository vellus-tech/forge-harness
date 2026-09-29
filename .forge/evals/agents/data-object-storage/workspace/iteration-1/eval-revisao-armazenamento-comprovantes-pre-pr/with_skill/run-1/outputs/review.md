# Revisão de armazenamento — módulo de comprovantes (pré-PR)

Escopo revisado: `infra/storage/comprovantes.tf`, `src/comprovantes/` e `deploy/k8s/`. Nenhum arquivo do repositório foi alterado — as correções abaixo são trechos prontos para você aplicar; quem escreve na árvore é o agente de engenharia ou o `task-coder`.

## Achados (por ordem de risco)

### O-01 — Bucket público (alto) — `infra/storage/comprovantes.tf:7-10`

As quatro chaves do Block Public Access estão em `false`, ou seja, desligadas — o bucket de comprovantes fica exposto a acesso público, e acesso de terceiro fora das formas admitidas pela decisão H-02 (a) é reprovado pela regra de integração.

Correção:

```hcl
resource "aws_s3_bucket_public_access_block" "comprovantes" {
  bucket                  = aws_s3_bucket.comprovantes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Isso deveria ser reforçado no nível de conta (S3 Block Public Access account-level ou org policy equivalente), não só no bucket.

### O-08 — SSE-KMS sem Bucket Key (aviso) — `infra/storage/comprovantes.tf:24`

`sse_algorithm = "aws:kms"` sem `bucket_key_enabled`: cada PUT/GET de comprovante chama o KMS individualmente, o que custa mais e pode esbarrar em cota de KMS em volume alto (fechamento diário).

Correção:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "comprovantes" {
  bucket = aws_s3_bucket.comprovantes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.comprovantes.arn
    }
    bucket_key_enabled = true
  }
}
```

### O-02 — URL pré-assinada longa e entrega a terceiro por e-mail (alto, dado o uso) — `src/comprovantes/emitir-link.ts:9`

`expiresIn: 60 * 60 * 24 * 7` = 7 dias. Uma URL pré-assinada é um bearer token: quem a tiver lê o objeto até expirar. Dois problemas distintos aqui:

1. **Expiração.** 7 dias é ordens de grandeza acima do admitido. Mesmo para o app mobile do próprio produto (cliente próprio, não terceiro), não há motivo para um link de PDF durar uma semana.
2. **Entrega ao parceiro por e-mail.** O mesmo link vai por e-mail ao parceiro de conciliação no fechamento diário — isso é entrega a terceiro, e a decisão H-02 (a) do dono (2026-09-26) só admite URL pré-assinada para terceiro com **todas** estas restrições: HTTPS, um único objeto nomeado, expiração em minutos, **emissão por endpoint REST autenticado do produto que autentica o parceiro**, log de emissão, bucket privado. Um link de 7 dias mandado por e-mail não atende nenhuma dessas condições além de "objeto único" — e-mail não é um endpoint autenticado, não gera log de emissão no produto, e a validade de dias é exatamente o que a decisão proíbe.

Correção: separar os dois usos.

```ts
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({});

// Uso do app mobile do próprio produto (cliente próprio, não terceiro).
export async function emitirLinkComprovanteApp(chave: string): Promise<string> {
  const cmd = new GetObjectCommand({ Bucket: "comprovantes-prd", Key: chave });
  return getSignedUrl(s3, cmd, { expiresIn: 900 }); // 15 min
}
```

Para o parceiro de conciliação, não mande o link por e-mail. Ele deve obter a URL do comprovante chamando um endpoint REST autenticado do produto (o parceiro se autentica nesse endpoint), que aí sim emite uma URL pré-assinada de objeto único, em minutos, com log de emissão — mantendo o e-mail apenas como aviso opcional ("comprovantes disponíveis, acesse via API") sem o link em si:

```ts
// Endpoint REST autenticado (ex.: GET /parceiros/conciliacao/comprovantes/:transacaoId)
// chamado pelo parceiro já autenticado (client credentials / mTLS / API key rotacionável).
export async function emitirLinkComprovantePorEndpointAutenticado(
  chave: string,
  parceiroId: string,
): Promise<string> {
  const cmd = new GetObjectCommand({ Bucket: "comprovantes-prd", Key: chave });
  const url = await getSignedUrl(s3, cmd, { expiresIn: 300 }); // 5 min
  logEmissaoUrlParceiro({ parceiroId, chave, ts: new Date().toISOString() }); // log de emissão exigido pela H-02 (a)
  return url;
}
```

Isso implica trocar o fluxo de "gerar link e mandar por e-mail no fechamento diário" por "notificar o parceiro (e-mail ou webhook) de que os comprovantes do dia estão disponíveis, e o parceiro busca cada um via esse endpoint autenticado".

### O-11 — MinIO comunitário arquivado (alto) — `deploy/k8s/minio.yaml:18`

`image: quay.io/minio/minio:latest`. A edição comunitária do MinIO está em modo de manutenção desde 2025 e o repositório foi arquivado em 25/04/2026 — não recebe mais correção de segurança. Isso vale independente da tag: fixar a tag no lugar de `latest` não resolve o problema de fundo, só resolveria imprevisibilidade de rollout.

Recomendação: plano de migração para uma alternativa mantida (ex.: outro object storage compatível com S3 mantido ativamente, ou usar S3 gerenciado da AWS já que o restante do módulo já é S3) ou suporte comercial do MinIO (AIStor/licença enterprise). Isso não é um patch de duas linhas — registre como ADR ou item do backlog técnico antes de abrir o PR, já que envolve decisão de infraestrutura mais ampla que este módulo.

### Ciclo de vida ausente (O-03 / O-04) — `infra/storage/comprovantes.tf`

O bucket tem versionamento ligado (`aws_s3_bucket_versioning`) mas nenhuma regra de ciclo de vida. Isso significa: (a) upload multipart incompleto nunca é abortado e continua sendo cobrado (O-03); (b) toda versão não corrente de um comprovante fica armazenada para sempre, com custo crescendo a cada sobrescrita (O-04).

Correção:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "comprovantes" {
  bucket = aws_s3_bucket.comprovantes.id

  rule {
    id     = "abort-multipart-orfao"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expira-versoes-nao-correntes"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
```

Ajuste os `90` dias conforme a política de retenção do comprovante do negócio (não é este agente que define retenção fiscal/contratual).

## Fora do escopo desta revisão

- O código de `gravar.ts` (PUT do comprovante) não apresentou antipattern do catálogo O-01–O-14/T-03; não é dado de cartão (PAN), é PDF de comprovante, então T-03 não se aplica aqui.
- Retenção legal do comprovante (quanto tempo o parceiro/regulador exige guardar) é decisão de negócio/compliance, não deste agente — só sinalizo que ela deveria estar refletida na regra de ciclo de vida acima.
- Migração efetiva do MinIO para outra solução é uma decisão de infraestrutura maior; aqui só aponto o risco e a necessidade de plano — a escolha da alternativa cabe a quem decide a arquitetura de storage do cluster.
