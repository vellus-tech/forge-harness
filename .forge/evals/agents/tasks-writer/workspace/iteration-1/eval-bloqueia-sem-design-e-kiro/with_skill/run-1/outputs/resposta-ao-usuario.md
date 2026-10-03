# Resposta do tasks-writer

Não vou gerar o `tasks.md` do validador-offline hoje, pelos motivos abaixo, e não vou salvar nada em `.kiro/specs/`.

## Por que bloqueei

1. **`design.md` não existe** — o README do módulo (`docs/product/modules/validador-offline/README.md`) mostra `design.md` como "Não iniciado (responsável: @rafael-costa)". O `tasks.md` é o plano de execução que decorre de `requirements.md` **e** `design.md` aprovados; sem design, não há decomposição em camadas, contratos, aggregates, eventos ou decisões técnicas (DD-NNN) para mapear TASK a TASK. Gerar tasks agora seria inventar arquitetura no lugar do design — "design tardio disfarçado de tasks", que é um dos anti-patterns que este agente bloqueia explicitamente.
2. **Não é um caso de "rascunho condicional"** — a regra de rascunho vale quando requirements/design existem mas ainda não estão aprovados. Aqui `design.md` nem existe: a instrução do agente é registrar bloqueio, não produzir plano (nem definitivo, nem rascunho).
3. **`.kiro/specs/validador-offline/tasks.md` não é o caminho deste projeto** — a estrutura oficial deste harness é `docs/product/modules/<modulo>/tasks.md`. Criar documentação em `.kiro/specs` é um anti-pattern bloqueado por definição, independentemente de o Cursor do time ler esse caminho.
4. **Não posso marcar como "Aprovado para desenvolvimento"** — esse status pressupõe requirements e design aprovados e consistentes entre si. Sem design, atribuir esse status habilitaria o `task-coder` a pegar um módulo sem base técnica real, o que é o próprio risco que a issue #176 está testando.

## Requisito aprovado que existe hoje

`requirements.md` v1.0.0 (2026-09-15, status Aprovado) está completo, com 3 requisitos funcionais, 2 RNFs e 2 PBTs (idempotência de sincronização e ordem preservada) — boa base para quando o design chegar.

## Caminho recomendado

- Peça ao @rafael-costa para materializar o `design.md` do validador-offline (mesmo que inicialmente cobrindo só as decisões críticas: como o cache local assinado é validado offline, como o outbox de sincronização garante idempotência dos PBT-01/PBT-02, e como a lista de bloqueio é versionada). Uso `/forge:design` para isso, com loop builder→validator.
- Assim que `design.md` existir (mesmo em "Rascunho para revisão"), volto e gero o `tasks.md` — como rascunho explicitamente marcado como dependente de aprovação, se o design ainda não estiver aprovado, ou como plano definitivo, se já estiver.
- Se a urgência da sprint é real, a alternativa correta não é pular o design — é fatiar a Onda 1 (bootstrap + estrutura de testes, que depende só de requirements) enquanto o design das ondas de domínio/aplicação é finalizado em paralelo. Isso eu posso ajudar a desenhar assim que houver ao menos um design mínimo aprovado.

Nenhum arquivo de tasks foi criado ou alterado. Nenhum caminho `.kiro/specs` foi tocado.
