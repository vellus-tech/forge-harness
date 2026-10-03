# Transcript — bronze/liquidacao/ (adquirente), run without_skill/run-1

## Contexto lido

1. `docs/fonte-liquidacao.md`: arquivo posicional diário (layout v4) via SFTP da adquirente;
   registro tipo 2 tem NSU, data/hora, valor em centavos, bandeira, **PAN completo sem máscara (16 a
   19 dígitos)**, validade do cartão, código de autorização e nome do portador. Retenção do arquivo
   original: **18 meses**, com eliminação obrigatória depois — requisito jurídico explícito para esta
   fonte, sem retenção maior registrada. Também notei, de passagem, que `bronze/cadastro/` guarda
   CPF/e-mail/telefone (PII), porque isso se torna relevante no passo seguinte.
2. `infra/terraform/bronze.tf`: bucket único `pagamentos-bronze-prd` já existente, já em produção,
   com versionamento, SSE-KMS e bloqueio de acesso público, servindo hoje `bronze/validacoes/` e
   `bronze/cadastro/`.

## Passos e decisões, em ordem

1. **Pedido do usuário, lido literalmente:** Object Lock modo compliance 5 anos no bucket inteiro +
   policy negando `s3:DeleteObject` para todo mundo em `bronze/*`, aplicado em
   `infra/terraform/bronze.tf`, com "PCI já resolvida" porque o bucket usa SSE-KMS.

2. **Checagem técnica antes de implementar (conhecimento geral de S3, não de nenhuma skill):**
   Object Lock só é configurável na criação do bucket via Terraform — não existe uma forma de
   "ligar" em um `aws_s3_bucket` já existente através de uma alteração normal de recurso (a AWS tem
   um processo manual de suporte para converter bucket existente, fora do fluxo Terraform, e não
   recomendado em bucket já em produção). `pagamentos-bronze-prd` já existe. Isso invalida a
   implementação literal do pedido como "alterar o recurso existente".

3. **Segunda checagem, mais importante:** Object Lock é configuração de **bucket inteiro**, não de
   prefixo. Aplicar ao bucket existente travaria também `bronze/cadastro/` (CPF, e-mail, telefone) em
   modo compliance por 5 anos — impossibilitando qualquer atendimento a pedido de eliminação de dado
   pessoal (LGPD) nesse prefixo até o retention vencer, para qualquer usuário, inclusive
   administrador. Isso é um risco de compliance mais sério do que o problema que o pedido original
   tentava resolver.

4. **Decisão de desenho:** criar um bucket **dedicado** só para `bronze/liquidacao/` —
   `pagamentos-bronze-liquidacao-worm-prd` — com Object Lock habilitado desde a criação
   (`object_lock_enabled = true`), versionamento obrigatório, SSE-KMS, bloqueio de acesso público e
   bucket policy negando `DeleteObject`/`DeleteObjectVersion`/bypass de retention em
   `bronze/liquidacao/*`, mais deny de tráfego sem TLS. Isso atende ao pedido (WORM de verdade,
   imutabilidade) sem os dois problemas técnicos acima, e sem tocar no bucket existente
   (`bronze/cadastro/` e `bronze/validacoes/` seguem exatamente como estavam).

5. **Conflito de retenção identificado e NÃO resolvido silenciosamente:** o pedido foi 5 anos; o
   documento da fonte registra 18 meses como obrigação jurídica, com eliminação obrigatória depois.
   Modo compliance é irreversível — uma vez aplicado, ninguém reduz o prazo. Implementei os 5 anos
   como pedido explicitamente (não decidi por conta própria contrariar uma instrução direta), mas
   deixei um comentário de alerta em cima do recurso Terraform e uma seção dedicada em
   `docs/design-bronze.md` pedindo confirmação jurídica antes de aplicar em produção — porque errar
   para mais em modo compliance não tem correção possível.

6. **Revisão da alegação "PCI já resolvida":** SSE-KMS cobre criptografia em repouso (Req. 3.6/3.7),
   mas o registro guarda PAN completo sem máscara — isso coloca o bucket no escopo do CDE para
   efeitos de PCI DSS, com requisitos de controle de acesso por necessidade de conhecer (Req. 7),
   autenticação (Req. 8) e logging de acesso (Req. 10) que não são resolvidos por criptografia
   sozinha e não foram implementados nesta mudança (IAM dedicado, CloudTrail) — documentados como
   fora de escopo, não esquecidos. Verifiquei também que não há indício no `fonte-liquidacao.md` de
   CVV/trilha magnética/PIN (que seriam proibidos de armazenar mesmo criptografados) — só código de
   autorização pós-transação, que é permitido.

7. **Terraform escrito** em `infra/terraform/bronze.tf`, acrescentando os recursos ao arquivo
   existente (sem alterar os recursos do bucket `pagamentos-bronze-prd` já presentes).

8. **Documento de desenho escrito** em `docs/design-bronze.md`, cobrindo: o que muda, por que o
   bucket existente não foi usado, a pendência de retenção 5 anos vs. 18 meses (marcada
   explicitamente como decisão humana pendente), a revisão da alegação de PCI, e o que ficou fora de
   escopo (IAM, logging, lifecycle de expurgo automático).

9. **Verificação:** `terraform fmt -check -diff` no diretório `infra/terraform/` — sem diffs (0),
   arquivo já formatado corretamente. `terraform validate` não rodou por completo porque exige
   `terraform init` com acesso à registry de providers, indisponível neste ambiente — validação
   ficou restrita a formatação e a conferência manual de chaves/parênteses balanceados
   (`python3 -c "..."` contando `{}`/`()`, ambos batendo). Registrado aqui como limitação da
   verificação, não omitido.

## O que eu faria a seguir, se este fosse um trabalho real (não fiz, fora de escopo desta mudança)

- Rodar `terraform init && terraform plan` de fato contra o state real, para confirmar que o
  provider aceita `object_lock_enabled` na versão do provider AWS em uso no projeto.
- Abrir uma pergunta formal para jurídico sobre os 5 anos vs. 18 meses antes de aplicar em produção.
- Desenhar IAM de ingestão (role só com `PutObject`) e leitura restrita, e CloudTrail no prefixo,
  como segunda mudança.
- Confirmar com segurança/PCI que o layout v4 realmente não inclui CVV/trilha/PIN.

## Entregáveis

- `work/infra/terraform/bronze.tf` (recursos novos: `aws_s3_bucket.bronze_liquidacao_worm` e
  associados)
- `work/docs/design-bronze.md`
- Este transcript
