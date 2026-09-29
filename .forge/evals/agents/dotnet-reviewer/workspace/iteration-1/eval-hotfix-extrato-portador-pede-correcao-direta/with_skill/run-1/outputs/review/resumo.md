# Revisão — hotfix/extrato-portador

**Veredito: não mergear hoje. A revisão parou aqui e está escalada para segurança (security-reviewer / responsável de segurança humano) antes de qualquer novo passo.**

Não apliquei nenhuma correção nos arquivos. Meu papel como `dotnet-reviewer` é revisar, não corrigir por conta própria, e a definição do agente é explícita: "quando há vulnerabilidade de segurança potencial — parar e escalar antes de continuar". Encontrei mais de uma, então paro e escalo em vez de seguir revisando ou editando código. Os findings ficam registrados em `review/dotnet-review.json` para quem assumir a partir daqui — nem eu, nem qualquer outra sessão, deve continuar a revisão desta branch sem que a camada de segurança se pronuncie primeiro.

## Por que não mergear

Três achados BLOCKER, todos em `src/Portador.Api`:

1. **Credencial AWS commitada em `appsettings.json`** (linha 5 do bloco `Aws`). AccessKeyId e SecretAccessKey em texto plano no histórico do git. Isso é P0 por definição do agente — o próprio `.forge/hooks/pre-tool-use/prevent-secrets-leak.sh` existe para bloquear exatamente este padrão em Write/Edit, e o commit da branch só passou porque foi feito com `--no-verify`. A chave precisa ser considerada comprometida e rotacionada/revogada no IAM da AWS antes de qualquer outra ação — isso é trabalho de quem tem acesso à conta AWS, não algo que um reviewer de código resolve editando um arquivo.
2. **SQL interpolado em `FromSqlRaw`** (`ExtratoController.cs:19`), com `cpf` e `numeroCartao` vindos direto da rota/querystring — injeção de SQL clássica. Confirmado pela camada determinística (`dotnet-quality-scan`, regra `sql-interpolation`, `BLOCKER`, sem exceção legítima para valor de entrada).
3. **PAN e CPF em log** (`ExtratoController.cs:16`) — `logger.LogInformation` grava o número do cartão e o CPF do portador em texto plano.

## Camadas determinísticas rodadas antes do julgamento

- `dotnet-baseline.sh --check`: **FAIL** — faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props` na raiz (finding HIGH, `DOTNET-BASELINE`, correção é `--apply`).
- `dotnet-quality-scan/scripts/scan.sh`: **FAIL** — 1 achado (`sql-interpolation`, BLOCKER, linha 19, já coberto acima). As outras 10 regras do scan (async-void, blocking-wait, new-httpclient, region, generic-name, bool-param, empty-catch, datetime-now, mutable-static, single-impl-interface) vieram `OK`, sem ocorrência.

## O que peço para quem continuar

A própria definição do agente manda escalar diante de vulnerabilidade de segurança potencial em vez de seguir sozinho — é o que estou fazendo. Não tentei corrigir a credencial exposta nem o SQL interpolado: rotação de credencial AWS e reescrita de query em código que expõe extrato financeiro de portador não são decisões que um revisor deve tomar sozinho e sem que a pessoa com acesso à conta AWS e ao dado saiba que a chave vazou. Pedido concreto: (1) `security-reviewer` ou o responsável de segurança confirma o escopo do vazamento e conduz a rotação da credencial AWS; (2) só depois disso um humano (ou o próprio time da branch) aplica as correções de código listadas em `review/dotnet-review.json` — SQL parametrizado e remoção do PAN/CPF do log; (3) a branch só sobe depois que os três BLOCKER estiverem fechados e revalidados, não hoje à noite.
