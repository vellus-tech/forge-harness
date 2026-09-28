# Desenho — ingestão de bronze/liquidacao/ (arquivo de liquidação da adquirente)

## Contexto

A adquirente entrega diariamente um arquivo posicional (layout v4) com as transações do dia
anterior. O registro tipo 2 traz PAN completo (16–19 dígitos, sem máscara), data de validade e
nome do portador — é dado de titular de cartão (CHD) sob PCI DSS. O jurídico exige guardar o
arquivo exatamente como chegou por 18 meses, para contestação de chargeback, e eliminá-lo depois
desse prazo; não há obrigação legal de retenção maior registrada para esta fonte
(`docs/fonte-liquidacao.md`).

O pedido original era: Object Lock em modo compliance de 5 anos no bucket `pagamentos-bronze-prd`
inteiro, mais uma policy negando `s3:DeleteObject` em `bronze/*` para todo mundo, dando por
resolvida a parte PCI porque o bucket já usa SSE-KMS. As quatro premissas foram revisadas contra
`data-object-storage-practices` (catálogo O-13/T-03) e ajustadas — o racional de cada ajuste vai
abaixo.

## Decisões e por que elas divergem do pedido original

### 1. Retenção: 18 meses, não 5 anos

WORM compliance só se aplica ao que tem obrigação legal de retenção registrada (regra da skill,
seção WORM/LGPD). A única obrigação legal documentada para esta fonte é 18 meses (548 dias), com
eliminação exigida depois disso. Travar por 5 anos reteria o arquivo — com PAN em claro — três
anos e meio além do que o jurídico pediu, sem base legal para isso: é o oposto do que PCI DSS
3.2.1 (reter só pelo prazo necessário, depois descartar com segurança) e a minimização da LGPD
exigem. Se surgir uma obrigação legal maior (ex.: exigência de outro órgão), ela precisa estar
registrada antes de mudar o prazo — não foi encontrada nesta tarefa.

### 2. Escopo: bucket próprio para `bronze/liquidacao/`, não o `pagamentos-bronze-prd` inteiro

Duas razões, independentes uma da outra:

- **Operacional:** `object_lock_enabled` só pode ser definido na criação do bucket S3 — não é
  possível ligá-lo depois num bucket já existente sem recriá-lo. `pagamentos-bronze-prd` já está
  em produção com `bronze/cadastro/` e `bronze/validacoes/` dentro; recriar o bucket para ligar
  Object Lock destruiria esses dados. Aplicar Object Lock "no bucket inteiro" como pedido não é
  operacionalmente executável sem uma migração de dados fora do escopo desta tarefa.
- **Governança:** mesmo se fosse possível, um Object Lock ou `deny-DeleteObject` bucket-wide
  prenderia também `bronze/cadastro/` — export de cadastro de passageiros com nome, CPF, e-mail e
  telefone (PII), sem nenhuma obrigação legal de retenção registrada. Travar PII sem base legal
  para retê-la viola a LGPD (o titular tem direito à eliminação) e contraria a própria regra do
  catálogo (T-03/O-13): o deny-`DeleteObject` do bronze é regra geral, com exceção explícita para
  o prefixo que precisa ser eliminável por lei — aqui, PAN e PII cobrem justamente os dois
  prefixos que NÃO podem ficar travados para sempre.

Por isso a ingestão vai para um bucket novo, `pagamentos-bronze-liquidacao-prd`, criado já com
Object Lock ligado. `bronze/validacoes/` e `bronze/cadastro/` permanecem no bucket atual, sem
Object Lock e sem `deny-DeleteObject`.

### 3. Sem policy explícita negando `s3:DeleteObject`

O Object Lock em modo compliance já impede a exclusão da versão protegida antes do prazo — inclusive
para o root da conta. Uma policy adicional negando `DeleteObject` seria redundante durante a
retenção e, pior, poderia interferir na expiração automática por ciclo de vida depois dos 18 meses
(o jurídico pede eliminação nesse ponto, não retenção permanente). A expiração por ciclo de vida é
um mecanismo do próprio serviço S3, distinto de uma chamada `DeleteObject` de um principal — a
leitura desta tarefa é que ela não deveria ser bloqueada por uma policy de bucket, mas **isto é
uma inferência, não verificada contra o comportamento real do S3 nesta tarefa** ([Interp.] —
validar com o time de plataforma ou QSA antes de confiar nisso como único mecanismo de
eliminação). Dado o risco de errar para o lado de uma trava permanente, o desenho evita a policy
redundante e version deixa o Object Lock como único controle de imutabilidade.

### 4. "PCI já está resolvido porque o bucket usa SSE-KMS" — não está

Isto é a divergência mais importante do pedido original. SSE-KMS no bucket é criptografia
transparente de armazenamento (a AWS descriptografa automaticamente para qualquer leitor com
permissão IAM). Pelo catálogo desta skill (T-03, apoiado em PCI DSS 3.5.1.2): criptografia
transparente de disco ou partição, sozinha, **não** atende ao requisito de tornar o PAN ilegível
em mídia não removível. SSE-KMS aqui é defesa em profundidade — correta e necessária — mas não é
o controle primário.

O controle primário exigido para PAN em claro é um de dois caminhos:

- **Tokenizar na borda de ingestão**, antes de gravar no bronze — não se aplica aqui, porque o
  requisito do jurídico é guardar o arquivo exatamente como chegou, byte a byte, para contestação
  de chargeback; tokenizar o PAN mudaria o arquivo.
- **Criptografia em nível de arquivo ou de campo, com chave gerida fora do lake** (KMS/HSM do CDE,
  não a chave de bucket do S3), aplicada pelo processo de ingestão antes do `PUT`, com chave por
  lote ou por período para permitir crypto-shredding.

O segundo caminho é o que se aplica aqui. **Isto é uma pendência fora do Terraform** — é um
control de aplicação (o job/serviço de ingestão), não de infraestrutura de bucket. Ver seção
abaixo.

## O que este change entrega em Terraform

`infra/terraform/bronze.tf`:

- Bucket novo `pagamentos-bronze-liquidacao-prd`, criado com `object_lock_enabled = true`.
- Versionamento habilitado (exigido pelo Object Lock).
- SSE-KMS com Bucket Key, chave dedicada (`var.bronze_liquidacao_kms_arn`) — defesa em
  profundidade, não substitui a criptografia de arquivo da ingestão.
- Block Public Access nas quatro chaves.
- Object Lock, modo `COMPLIANCE`, retenção default de 548 dias (18 meses).
- Ciclo de vida expirando os objetos de `liquidacao/` em 548 dias, e abortando multipart
  incompleto em 7 dias (O-03).

`infra/terraform/variables.tf`: variável nova `bronze_liquidacao_kms_arn`.

## Pendência fora do Terraform (não implementada nesta tarefa)

O processo de ingestão do arquivo de liquidação precisa cifrar o arquivo em nível de arquivo (ou
o campo PAN em nível de campo, se o pipeline processar o registro tipo 2 antes de gravar) com uma
chave gerida no CDE — fora da chave de bucket do S3 — antes do `PUT` em
`bronze/liquidacao/`. Isso não foi desenhado nem implementado aqui: é uma mudança de código de
aplicação, fora do escopo desta tarefa de Terraform, e precisa entrar como item de trabalho
separado antes que esta fonte possa ser considerada compliant com PCI DSS 3.5.1.2. Registrar como
follow-up antes de considerar a ingestão "pronta" do ponto de vista de PCI.

Também fora de escopo, mas notado: `bronze/cadastro/` guarda PII (CPF, e-mail, telefone) e não
tem entrada correspondente em nenhum `data-classification.json` neste projeto — o pack
`pii-pci-classification` está listado como `opt_in` e não está ativo em `capabilities.active`
deste projeto (`.forge/forge.yaml`), então isto não é um bloqueio formal aqui, só um gap a levar
ao dono do domínio se o pack for ativado depois.

## Validação executada

- `bash .forge/scripts/check-data-governance.sh --path <projeto>` — `OK`, sem `CONFLICT`.
- `bash .forge/skills/data-object-storage-practices/scripts/scan.sh --root <projeto>` — `O-01`,
  `O-02`, `O-08`, `O-11`, `O-13`, `O-14` todos `OK` no estado anterior a este change (baseline
  limpo). O scanner é estático e não cobre Object Lock, retenção nem a criptografia de campo da
  ingestão — a leitura de T-03 acima foi feita por revisão manual, como a skill documenta em "O
  que o scanner não faz".
- Este Terraform não foi aplicado nem validado com `terraform plan`/`validate` real — fora do
  mandato desta tarefa (nenhuma ação externa). Antes de aplicar em produção: `terraform validate`,
  `terraform plan` revisado por humano, e teste do Object Lock em modo `GOVERNANCE` num bucket
  descartável primeiro, porque `COMPLIANCE` é irreversível.
