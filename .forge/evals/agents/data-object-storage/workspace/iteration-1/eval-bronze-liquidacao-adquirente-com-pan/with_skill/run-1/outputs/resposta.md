# Resposta — `data-object-storage`: endurecimento do bronze de liquidação da adquirente

## Correção de premissa (antes de qualquer Terraform)

SSE-KMS com Bucket Key **não cobre** o `numero_cartao`. `bucket_key_enabled = true` já está
presente em `infra/lake/bronze.tf` (achado O-08 do catálogo: nenhuma ocorrência — está correto),
mas SSE-KMS é criptografia transparente no nível de armazenamento e, pelo PCI DSS 4.0.1 3.5.1.2,
**não basta sozinha em mídia não removível** para proteger PAN em repouso (T-03 do catálogo da
skill). Hoje o bucket protege o disco; o PAN dentro do arquivo continua legível para qualquer
principal com `s3:GetObject`.

`data-classification.json` confirma o campo como o gatilho: `numero_cartao` está classificado
`pan` com `tokenization_boundary: true` — ou seja, o desenho do projeto já declara que esse campo
deveria cruzar uma fronteira de tokenização antes de circular, e hoje não cruza (`jobs/ingestao_liquidacao.py`
grava "como chegou, com numero_cartao em claro").

## Achados (evidência)

- `bash .forge/scripts/check-data-governance.sh --path jobs/ingestao_liquidacao.py` → `OK` (o
  gate cobre mascaramento em log, não cobre gravação de campo PAN em arquivo; não é aprovação da
  prática de gravar PAN em claro no bronze).
- `bash .forge/scripts/check-data-governance.sh --path infra/lake/bronze.tf` → `FAIL
  data-governance/universo-vazio` (o gate só lê `.go .kt .ts .rego .py .md`; `.tf` está fora do
  universo dele — **não verificado por ele**, não é aprovação; revisão manual abaixo).
- `bash .forge/skills/data-object-storage-practices/scripts/scan.sh --root jobs --root infra/lake`
  → `FOUND O-13 [aviso] jobs/ingestao_liquidacao.py:10: df.write.mode("overwrite").parquet(...)`.
  Bronze mutável: `overwrite` na zona bronze quebra reprocessamento e auditoria.
- Leitura manual de `numero_cartao` contra `data-classification.json` + `jobs/ingestao_liquidacao.py`
  → **T-03** (bronze com dado de cartão): PAN em claro no bronze, sem tokenização de borda nem
  criptografia em nível de campo/arquivo com chave fora do lake.

## O que o pedido do usuário acerta

- Object Lock em modo COMPLIANCE e bucket policy negando `s3:DeleteObject` são o padrão correto
  de imutabilidade para bronze/raw (O-13, correção geral) — só não podem ser aplicados **de forma
  uniforme** ao prefixo que carrega CHD (cartão), pelo motivo abaixo.

## Onde o pedido, como está, cria um problema novo

1. **Object Lock COMPLIANCE de 10 anos, uniforme em todo `s3://lake-pagamentos/bronze/`, trava a
   descartabilidade do PAN.** COMPLIANCE é irreversível — nenhum principal, nem a conta root,
   consegue apagar ou encurtar a retenção antes do prazo. Travar o arquivo da adquirente (que tem
   PAN) por 10 anos, sem que 10 anos seja a política de retenção documentada para CHD, é um risco
   de conformidade novo: PCI DSS 3.2.1 exige que dado de titular de cartão não viva além do que a
   política de retenção definir, e essa política tende a ser bem mais curta que 10 anos para um
   arquivo bruto de liquidação. O catálogo (T-03) já prevê essa tensão: o prefixo com CHD fica
   **isento** do deny-`DeleteObject` geral do O-13 e usa ciclo de vida com expiração alinhada à
   política de retenção — eliminação segura (PCI DSS 3.2.1, LGPD) prevalece sobre a imutabilidade
   ali.
2. **A bucket policy negando `s3:DeleteObject` em todo `bronze/` teria o mesmo efeito colateral**
   sobre o prefixo de liquidação: bloqueia até a exclusão legítima de fim de retenção. Ela deve
   excluir explicitamente o prefixo com CHD (`bronze/liquidacao/*`), que usa outro mecanismo de
   descarte (abaixo).
3. **O prazo de retenção de 10 anos não está justificado neste ticket.** Se 10 anos é a política
   real (ex.: exigência regulatória/contratual com a adquirente), documente isso — ADR ou
   `data-classification.json` — antes de aplicar; se foi só "igual às outras fontes" sem checar se
   a fonte tem CHD, é o ponto onde a uniformização quebra: fontes sem PAN podem herdar o padrão
   das outras sem revisão; a fonte de liquidação, não.

## Recomendação

### 1. Separar o desenho por conteúdo, não por bucket

O bucket (`lake-pagamentos`) e o Object Lock a nível de bucket continuam os mesmos. O que muda é
o **prefixo com CHD**:

- `s3://lake-pagamentos/bronze/**` (fontes sem PAN/PII): Object Lock COMPLIANCE, retenção longa
  (a mesma das outras fontes), deny-`DeleteObject` geral — sem alteração ao que você já pediu.
- `s3://lake-pagamentos/bronze/liquidacao/**` (tem PAN): Object Lock ainda protege contra
  sobrescrita/exclusão *dentro* da janela de retenção (mantém o `overwrite`→append-only do
  job também protegido), mas com **retenção igual à política de retenção documentada para CHD**
  (não necessariamente 10 anos — levar para ADR se ainda não existe), e a bucket policy de
  deny-`DeleteObject` **exclui esse prefixo** (condição `NotResource` no `arn:aws:s3:::lake-pagamentos/bronze/liquidacao/*`).

### 2. PAN não pode continuar em claro — resolve a tensão retenção-vs-descarte

Como o arquivo da adquirente provavelmente precisa ser preservado como chegou (reconciliação e
disputa com a adquirente), tokenização de borda pura pode não ser viável para o arquivo inteiro —
é exatamente o caso que T-03 prevê como alternativa:

- Criptografia em **nível de campo ou de arquivo** do `numero_cartao`, com chave gerida **fora do
  lake**, no KMS/HSM do CDE (não a mesma chave `aws_kms_key.lake` do SSE-KMS do bucket — essa
  continua cobrindo a transparência de disco, não substitui a de campo/arquivo).
- Chave **por lote ou por período** (ex.: uma CMK por mês de ingestão). No fim da política de
  retenção, a chave daquele período é destruída (crypto-shredding, KMS `ScheduleKeyDeletion`) —
  isso satisfaz o descarte seguro do PCI DSS 3.2.1 **sem precisar apagar o objeto**, o que resolve
  o conflito com Object Lock COMPLIANCE: o objeto continua fisicamente no bucket (imutável, como
  o desenho pede), mas o PAN dentro dele fica permanentemente ilegível assim que a chave é
  destruída.
- `data-classification.json` deveria então documentar essa fronteira de fato (o campo continua
  `tokenization_boundary: true`, mas com nota de que a fronteira, para este job, é criptografia de
  campo com chave do CDE, não tokenização por serviço — registrar isso é decisão do time de
  dados/segurança, não deste agente).

### 3. Job — parar de gravar `overwrite` (O-13) e parar de gravar PAN em claro (T-03)

Ver `outputs/ingestao_liquidacao.proposto.py` (rascunho, não aplicado — quem escreve na árvore é o
agente de engenharia/`task-coder`).

### 4. Terraform — Object Lock de fato configurado + policy segmentada

`bronze.tf` hoje só declara `object_lock_enabled = true` na criação do bucket — isso habilita
Object Lock e (segundo a documentação corrente do provider, consultada via context7) habilita
versionamento automaticamente, mas **não define nenhuma regra de retenção**: falta o recurso
`aws_s3_bucket_object_lock_configuration`, que é quem de fato aplica COMPLIANCE + prazo. Ver
`outputs/bronze.tf.proposto` e `outputs/bronze-liquidacao-policy.json` (rascunhos).

## Pendências para decisão humana (não é bloqueio de CONFLITO — é dado que falta, não divergência rule×skill)

- Qual é a política de retenção documentada para CHD deste fluxo (não necessariamente 10 anos)?
  Sem isso, o Terraform proposto usa um placeholder e marca `# NEEDS CLARIFICATION`.
- O arquivo da adquirente precisa mesmo ser preservado byte-a-byte (reconciliação/disputa), ou
  tokenização de borda antes da escrita no bronze é viável? Isso decide entre as duas correções de
  T-03 (tokenizar vs. criptografar campo/arquivo com chave do CDE).

## Fora do meu escopo

Nada aqui cruza para tabela/formato/partição de silver-gold (`data-analytical`) nem para estado
mutável compartilhado (banco). Se o time decidir usar um serviço de tokenização com API própria,
o desenho de chamada síncrona a esse serviço (interno vs. externo, gRPC vs. REST) segue a regra de
integração deste mesmo agente (seção "Regra de integração"), não precisa de outro especialista.
