# Revisão de armazenamento — módulo de comprovantes

Escopo revisado: `infra/storage/comprovantes.tf`, `src/comprovantes/` (`gravar.ts`, `emitir-link.ts`), `deploy/k8s/minio.yaml`.

## Achados, do mais grave ao menos grave

### 1. CRÍTICO — bucket S3 com bloqueio de acesso público desativado
`infra/storage/comprovantes.tf`, recurso `aws_s3_bucket_public_access_block.comprovantes`: os quatro controles (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) estão em `false`. Isso remove a proteção da conta contra ACL ou bucket policy pública nesse bucket — que guarda comprovantes financeiros (PDF com dados de transação, potencialmente dado pessoal sob LGPD). Qualquer ACL pública aplicada a um objeto (por engano, por uma mudança futura, por um SDK mal configurado) passa a valer, sem essa camada de proteção como rede de segurança. Não há justificativa de negócio para isso — o acesso já é feito via link assinado (`emitir-link.ts`), então o bucket deveria ser inteiramente privado. Correção em `outputs/correcoes/comprovantes.tf`: todos os quatro campos para `true`, mais uma bucket policy explícita negando acesso não-TLS e negando ACLs públicas.

### 2. ALTO — mesmo link assinado de 7 dias servindo o app mobile e o e-mail ao parceiro
`src/comprovantes/emitir-link.ts` gera um único link pré-assinado com `expiresIn: 60 * 60 * 24 * 7` (7 dias) e o comentário confirma que esse mesmo link é usado tanto para o download no app quanto para o envio por e-mail ao parceiro de conciliação. Isso mistura dois perfis de risco muito diferentes num único artefato:
- **E-mail é um canal que você não controla depois do envio** — pode ser encaminhado, fica em caixas de entrada/backup indefinidamente, pode ser interceptado por um servidor de e-mail comprometido. Um link de 7 dias nesse canal equivale a dar a qualquer pessoa que tenha acesso àquela caixa de entrada (não só o parceiro) leitura do comprovante por até uma semana, sem log de quem de fato acessou.
- **O app mobile não precisa de 7 dias de validade** — o padrão razoável para "baixar agora" é minutos a poucas horas.
- Há ainda um problema funcional possível: se `S3Client({})` estiver assumindo credenciais temporárias (role de ECS/Lambda/EKS via STS), a assinatura SigV4 pré-assinada não pode ter validade maior que a validade das credenciais temporárias subjacentes — nesse cenário, `expiresIn: 7 dias` é aceito sem erro na hora de gerar mas o link pode virar inválido antes do prazo nominal, de forma não determinística conforme o ciclo de rotação das credenciais.

Recomendação: separar os dois usos. Uma função com expiração curta (ex.: 15–60 min) para o app; para o parceiro, não reusar o link do app — gerar o link dedicado no momento do envio do fechamento diário, com expiração compatível com a janela operacional do fechamento (ex.: algumas horas, não dias), e idealmente registrar o evento de emissão (quem gerou, para qual finalidade, quando expira) para dar rastreabilidade sobre um artefato que sai da sua infraestrutura por e-mail.

### 3. ALTO — StatefulSet MinIO sem armazenamento persistente e sem hardening básico
`deploy/k8s/minio.yaml` sobe um `StatefulSet` chamado `objetos` rodando `minio server /data`, mas **não define `volumeClaimTemplates`** nem monta nenhum volume em `/data`. Sem PVC, os dados gravados vivem no filesystem efêmero do container — qualquer reinício de pod (deploy, crash, reagendamento de nó) perde tudo que foi gravado. Para um serviço que guarda comprovantes financeiros, isso é inaceitável mesmo como staging.

Outros problemas no mesmo manifesto:
- Imagem `quay.io/minio/minio:latest` — tag não fixada; builds não são reprodutíveis e um `latest` pode trazer uma versão com breaking change ou CVE sem aviso.
- Sem `resources.requests/limits` — sem isso o pod pode ser despejado (OOM) sob pressão de nó, ou monopolizar recursos.
- Sem `securityContext` — o container roda como root por padrão (MinIO tem UID/GID próprios documentados para non-root).
- Sem `livenessProbe`/`readinessProbe` — o Kubernetes não sabe detectar o serviço travado.
- Nenhum `Service` associado ao StatefulSet nesse arquivo — sem isso nada consegue endereçar o pod via DNS estável (pode existir em outro arquivo não revisado; se não existir, falta).

Correção proposta em `outputs/correcoes/minio.yaml` cobre PVC, tag fixada, resources, securityContext non-root e probes. Se este MinIO for só ambiente de dev/staging (ver achado 5), ainda assim vale corrigir — hoje ele não sobrevive nem a um restart de pod.

### 4. MÉDIO — chave de objeto previsível
`src/comprovantes/gravar.ts` monta a chave como `comprovantes/${transacaoId}.pdf`. Se `transacaoId` for sequencial ou de baixa entropia (ex.: autoincremento), a chave inteira do objeto é previsível. Com o achado 1 corrigido (bucket privado), o risco direto de enumeração cai bastante, mas como defesa em profundidade — e para não depender só de uma camada de controle — vale incluir um componente não sequencial na chave (por exemplo `comprovantes/${transacaoId}/${crypto.randomUUID()}.pdf`), para que a chave em si não vaze o volume/ordem de transações mesmo em caso de uma falha futura na política de acesso.

### 5. MÉDIO — rotação de chave KMS não habilitada
`aws_kms_key.comprovantes` não define `enable_key_rotation = true`. Para uma chave que protege dados financeiros de forma contínua, a rotação anual automática da AWS deveria estar ligada — é um `default = false` que costuma passar despercebido em review.

### 6. MÉDIO — sem exigência de TLS na política do bucket
Não há bucket policy negando `aws:SecureTransport = false`. Hoje a proteção contra tráfego em texto claro depende inteiramente do cliente (SDK) usar HTTPS por padrão — não há controle de servidor que recuse conexão não-TLS caso algum caller futuro (script, CLI mal configurado) use HTTP.

### 7. BAIXO — inconsistência entre Terraform (AWS S3) e k8s (MinIO próprio)
O Terraform provisiona um bucket S3 real (`comprovantes-prd`) e o código (`gravar.ts`, `emitir-link.ts`) usa o SDK da AWS apontando para esse bucket. Já o `deploy/k8s/minio.yaml` sobe um MinIO self-hosted chamado `objetos`. Não dá para saber, só pelos três arquivos, se o MinIO é ambiente de desenvolvimento/staging local (plausível) ou se há alguma rota de produção que na prática grava no MinIO em vez do S3. Antes do PR, vale confirmar explicitamente qual é a fonte de verdade em cada ambiente — hoje isso não está documentado em lugar nenhum dos três arquivos revisados, e um leitor novo do módulo não consegue inferir sozinho.

### 8. BAIXO — nenhuma política de retenção/lifecycle
Comprovantes financeiros costumam ter exigência de retenção mínima (contábil/fiscal) e, dependendo do dado pessoal envolvido, também um limite de retenção sob LGPD. Não há `aws_s3_bucket_lifecycle_configuration` nem qualquer menção a prazo. Isso é mais uma decisão de produto/compliance do que um bug de infraestrutura — sinalizo para constar na revisão, não incluí correção pronta porque depende de uma política que vocês precisam definir (prazo, base legal).

## Resumo para o PR

Os achados 1, 2 e 3 são bloqueantes antes de abrir o PR: bucket com bloqueio público desativado, link de 7 dias reaproveitado para e-mail externo, e armazenamento MinIO sem persistência são os três que causam exposição de dado sensível ou perda de dado. Os achados 4–6 são correções de baixo esforço que valem entrar no mesmo PR. Os achados 7–8 são para alinhar com o time antes de seguir, não bugs de código.
