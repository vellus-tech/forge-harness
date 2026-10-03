# Desenho — bronze/liquidacao/ (arquivo de liquidação da adquirente)

## O que muda

Novo prefixo `bronze/liquidacao/` recebe o arquivo posicional (layout v4) que a adquirente entrega
diariamente via SFTP, gravado exatamente como chega — sem parsing, sem máscara, sem transformação.
Registro tipo 1 (header de lote), tipo 2 (transação, com PAN completo sem máscara) e tipo 9
(trailer).

Ao invés de habilitar Object Lock no bucket `pagamentos-bronze-prd` existente, como pedido
originalmente, a liquidação ganha um bucket próprio —
`pagamentos-bronze-liquidacao-worm-prd` (`infra/terraform/bronze.tf`) — com Object Lock em modo
compliance habilitado desde a criação, versionamento obrigatório, SSE-KMS, bloqueio de acesso
público, e uma bucket policy negando `DeleteObject`/`DeleteObjectVersion`/bypass de governance em
`bronze/liquidacao/*`, além de negar tráfego fora de TLS.

## Por que não o bucket existente (desvio do pedido original)

Dois motivos técnicos, verificáveis, não preferência de estilo:

1. **Object Lock não é retroativo.** Só é possível habilitar na criação do bucket (ou por processo
   de suporte da AWS, fora do Terraform, para um bucket já existente com versionamento — e mesmo
   assim a AWS recomenda contra fazer isso em bucket já em produção). `pagamentos-bronze-prd` já
   existe e já está em uso pelos prefixos `bronze/validacoes/` e `bronze/cadastro/`. Não há recurso
   Terraform que "liga" Object Lock num bucket existente.
2. **Object Lock é configuração de bucket, não de prefixo.** Mesmo que fosse possível habilitar
   depois, o retention se aplicaria a todo objeto do bucket — inclusive `bronze/cadastro/`, que
   contém CPF, e-mail e telefone de passageiros. Travar esse prefixo em modo compliance por 5 anos
   bloqueia qualquer atendimento a pedido de eliminação de dado pessoal (LGPD, art. 18, inciso VI) até
   o retention expirar, sem exceção nem para administrador do bucket. Não há como isolar apenas
   `bronze/liquidacao/*` do lock dentro do mesmo bucket.

Um bucket dedicado resolve os dois problemas: Object Lock nasce junto com o bucket, e o escopo do
lock é exatamente a fonte que precisa dele — não contamina cadastro nem validações.

## Pendência para decisão humana — retenção de 5 anos vs. 18 meses documentados

`docs/fonte-liquidacao.md` registra o requisito jurídico para esta fonte especificamente: guardar o
arquivo original por **18 meses** para contestação de chargeback, com **eliminação obrigatória**
depois disso, e sem obrigação de retenção maior registrada.

O pedido desta mudança foi 5 anos em modo compliance. Implementei o que foi pedido — mas os dois
números não batem, e a diferença importa porque modo compliance é irreversível: depois de aplicado,
nem root da conta, nem suporte da AWS conseguem apagar ou reduzir o retention antes do prazo vencer.
Se a retenção correta para esta fonte é mesmo 18 meses, o dado vai ficar preso por mais 3,5 anos do
que a obrigação legal descrita, sem correção possível — isso significa manter PAN completo sem
máscara em produção por tempo maior que o necessário, o que é um risco de exposição maior em caso de
incidente, não menor.

**Recomendação:** antes de aplicar este Terraform em produção, confirmar com jurídico se os 5 anos
são um requisito real para esta fonte (ex.: prazo decadencial/prescricional diferente do prazo de
chargeback, ou política de retenção corporativa que se sobrepõe ao que está em
`fonte-liquidacao.md`) ou se `fonte-liquidacao.md` está desatualizado. Se não houver confirmação,
recomendo aplicar `years = 2` (18 meses arredondado para cima, já que Object Lock em modo compliance
do provider AWS só aceita `days` ou `years` inteiros — 18 meses exatos não é representável; usar
`days = 548` é a forma exata) e não 5. Deixei 5 anos no `.tf` porque foi o que foi pedido
explicitamente, mas o marquei com um comentário de alerta no próprio recurso — este documento é o
lugar formal do registro da pendência.

## PCI DSS — "a parte PCI já está resolvida porque o bucket usa SSE-KMS": parcialmente correto

SSE-KMS atende ao requisito de **criptografia em repouso** (PCI DSS 4.0.1, Req. 3.6/3.7 — proteção
de chave e dado armazenado). Isso é necessário, mas não é a PCI inteira:

- O registro tipo 2 guarda **PAN completo sem máscara** (16 a 19 dígitos), data de validade, código
  de autorização e nome do portador. Isso é dado de titular de cartão armazenado (Req. 3), e o fato
  de ser bronze "como chega" — decisão correta para evidência de chargeback — significa que este
  bucket entra no escopo do ambiente de dados de cartão (CDE) para efeitos de PCI DSS, com tudo que
  isso implica: controle de acesso por necessidade de conhecer (Req. 7), autenticação forte e MFA
  para quem acessa (Req. 8), logging e monitoramento de acesso a este prefixo especificamente (Req.
  10), e escopo de rede/segmentação em volta do bucket. Nenhum desses pontos está coberto pelo
  Terraform desta mudança — ficou fora do escopo pedido, mas precisa ser tratado antes de este
  prefixo ir para produção com tráfego real, ou o SAQ da empresa muda de categoria.
- Criptografia em repouso não é controle de acesso: a policy adicionada aqui nega apenas
  `DeleteObject`; não há controle de quem tem `GetObject`/`ListBucket` neste prefixo. Isso ficou como
  lacuna aberta — recomendo IAM dedicado (role de ingestão com `PutObject` apenas, sem `GetObject`;
  leitura restrita a papéis específicos de contestação de chargeback) antes de considerar a parte PCI
  encerrada.
- Código de autorização pós-transação não é dado de autenticação sensível (isso seria CVV/CVV2,
  trilha magnética completa ou PIN, proibidos de armazenar mesmo criptografados — Req. 3.3.1) — não
  há indício no `docs/fonte-liquidacao.md` de que esses campos estejam no arquivo, então não há
  violação aqui. Mas vale confirmar com o time de segurança que o layout v4 realmente não inclui
  nenhum desses campos antes de considerar isso fechado.

## O que NÃO foi feito nesta mudança (fora de escopo, registrado para não ser esquecido)

- IAM/role de ingestão dedicada e controle de leitura por necessidade de conhecer (ver PCI acima).
- CloudTrail/Access Logging do bucket para trilha de auditoria de acesso ao PAN.
- Job de expurgo automático (lifecycle rule) ao fim do retention — como o bucket está em modo
  compliance, a expiração automática por lifecycle só executa depois que o Object Lock libera o
  objeto; vale configurar `aws_s3_bucket_lifecycle_configuration` alinhado ao mesmo prazo do
  retention quando o prazo correto (5 anos ou 18 meses) estiver confirmado, para não depender de
  processo manual de eliminação.
- Qualquer alteração em `bronze/cadastro/` ou `bronze/validacoes/` — o bucket existente
  `pagamentos-bronze-prd` não foi tocado por esta mudança.

## Arquivos alterados

- `infra/terraform/bronze.tf` — bucket `pagamentos-bronze-liquidacao-worm-prd` novo, com Object
  Lock, versionamento, SSE-KMS, bloqueio de acesso público e bucket policy.
- `docs/design-bronze.md` — este documento.
