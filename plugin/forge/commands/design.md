---
description: Gera/refina o design técnico do change ativo com loop builder→validator (máx. 3 iterações) e gate HITL. Transiciona para design-ready. Fase obrigatória em scale ≥ 2.
argument-hint: "[<change-id>]"
---

# /forge:design — design do change com loop builder→validator

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Pré-condições: status `requirements-ready` (scale ≥2). Scale 0/1 dispensam esta fase — informe e sugira `/forge:tasks` (forçar design em scale baixo é permitido sem transição extra; pular design em scale ≥2 exige `quick_plan` no manifest com justificativa). Tipo `bugfix` normalmente dispensa design (root cause vive no `bugfix.md`); crie `design.md` só se a correção exigir decisão arquitetural.

## 1. Builder

Preencha/refine `design.md` (estrutura do template do change) a partir de `proposal.md` + artefato de requirements + rules do projeto (`.forge/rules/`, `.forge/context.md`):

- decisão técnica em termos de componentes/fluxos/contratos; alternativas consideradas com trade-offs;
- contratos e integrações afetados com estratégia de compatibilidade;
- plano de migração/rollout; riscos com detecção;
- rastreabilidade: todo `REQ-NN` mapeado para a seção do design que o atende;
- decisão durável/transversal → sugerir ADR (`/forge:new-adr`) e referenciar — não duplicar.

## 2. Validator (sinal externo — §14.6)

Invoque um subagent **independente** (Agent tool) com este prompt, substituindo os paths:

> Você é um validator adversarial de design técnico. Leia `<change-dir>/proposal.md`, `<change-dir>/<artefato-de-requirements>` e `<change-dir>/design.md` (e `.forge/rules/architecture/` se existir). NÃO corrija — valide e reporte. Critérios: (a) todo REQ coberto na tabela de rastreabilidade por seção real do design; (b) decisão técnica não contradiz requirements nem rules do projeto; (c) contratos afetados têm estratégia de compatibilidade; (d) riscos têm detecção/mitigação; (e) alternativas registradas (não só a escolhida). Responda EXATAMENTE no formato:
>
> ```
> ## Status: PASS | FAIL
> [MISS]     <REQ/aspecto sem cobertura no design>
> [CONFLICT] <contradição com requirements/rules/contratos>
> [CLARIFY]  <decisão em aberto que exige humano>
> ```
>
> FAIL se houver qualquer [MISS] ou [CONFLICT].

## 3. Loop (máximo 3 iterações)

Igual ao `/forge:requirements`: corrigir só o apontado; `[CLARIFY]` → protocolo do `/forge:clarify`; FAIL na 3ª iteração → escalonar no gate HITL com os pontos remanescentes.

## 4. Gate HITL — `design_reviewed` (§12.1)

`AskUserQuestion` (resumo 2-3 linhas + iterações): **Approve** / **Review** / **Reject** / **Block**.

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate design_reviewed --decision <decision> [--reason "<motivo>"] --iteration <n> --scope "design.md"
```

- **Approve** → `bash .forge/scripts/spec-transition.sh <change-id> design-ready`; próximo: `/forge:tasks`.
- **Review** → motivo vira instrução; volte ao passo 1.
- **Reject**/**Block** → registre e pare (close/blocked conforme o caso).
