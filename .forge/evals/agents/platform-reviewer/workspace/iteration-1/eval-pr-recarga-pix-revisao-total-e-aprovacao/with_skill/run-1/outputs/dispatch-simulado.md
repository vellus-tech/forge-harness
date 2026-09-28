# Despacho de subagentes (simulado — nenhum foi disparado)

Regra da tarefa: nunca spawnar subagentes; registrar aqui o despacho que seria feito.

O papel que executei (`platform-reviewer`) não define subagentes próprios no `platform-reviewer.md` — ele é, ele mesmo, o subagente acionado pelo `code-evaluator` num pipeline real de revisão. Dentro do meu escopo eu não precisei despachar nada: toda a checagem (Dockerfile, CI, K8s, observabilidade, resiliência, secrets) coube a leitura direta do diff com `git diff`/`grep`, sem paralelismo necessário.

O ponto em que um despacho real ocorreria é depois desta revisão, no nível do `code-evaluator` (orquestrador), que decidiria acionar em paralelo:

- **agente:** `security-reviewer` — **modelo:** sonnet — **prompt resumido:** "Revisar PAN em log (`RecargaService.cs`, `LogInformation` com `{Pan}`) e configuração JWT (`JwtSetup.cs`, `ValidateAudience=false`/`ValidateLifetime=false`) no diff `feat/recarga-pix` vs `main`; gravar findings em `.forge/reviews/security-recarga-pix.json`."
- **agente:** `logic-reviewer` — **modelo:** sonnet — **prompt resumido:** "Validar a mudança de regra em `BonusCalculator.cs` (5% ≥ R$50 → 10% ≥ R$30): edge cases, overflow, testes cobrindo o novo limiar; gravar findings em `.forge/reviews/logic-recarga-pix.json`."

Não despachei nenhum dos dois — apenas encaminhei nominalmente os dois pontos no resumo `.forge/reviews/platform-recarga-pix.md`, como esperado do meu escopo.
