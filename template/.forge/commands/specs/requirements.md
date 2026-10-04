---
description: Gera/refina os requirements do change ativo (requirements.md, bugfix.md ou refactor.md conforme o tipo) com loop builder→validator (máx. 3 iterações) e gate HITL. Transiciona para requirements-ready.
argument-hint: "[<change-id>]"
---

# /forge:requirements — requirements do change com loop builder→validator

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Artefato-alvo por tipo (manifest `type`): `feature|greenfield|brownfield` → `requirements.md` · `bugfix` → `bugfix.md` · `refactor` → `refactor.md`. Scale 0 dispensa esta fase (informe e sugira `/forge:tasks`).

## 1. Builder

Preencha/refine o artefato-alvo a partir de `proposal.md`, das clarificações já aplicadas e do contexto do repo:

- siga a estrutura do template instalado no change (não invente seções);
- todo requisito verificável e rastreável (`REQ-NN` → proposal §; bugfix: as 6 seções do `bugfix.md`; refactor: invariantes verificáveis);
- incertezas → `NEEDS CLARIFICATION` (nunca inferir);
- fora de escopo explícito.

## 2. Validator (sinal externo — §14.6)

Invoque um subagent **independente** (Agent tool, sem reaproveitar o contexto do builder) com este prompt, substituindo os paths:

> Você é um validator adversarial de requirements. Leia `<change-dir>/proposal.md` e `<change-dir>/<artefato-alvo>` (e `.forge/constitution.md` se existir). NÃO corrija nada — apenas valide e reporte. Critérios: (a) toda mudança declarada na proposal §2 coberta por requisito; (b) cada requisito verificável (critérios de aceite objetivos); (c) sem conflito entre requisitos ou com o fora-de-escopo; (d) ambiguidades reais sinalizadas; (e) estrutura do template respeitada. Responda EXATAMENTE neste formato:
>
> ```
> ## Status: PASS | FAIL
> [MISS]     <item da proposal sem requisito — um por linha>
> [CONFLICT] <inconsistência entre artefatos>
> [CLARIFY]  <ambiguidade que exige decisão humana>
> ```
>
> FAIL se houver qualquer [MISS] ou [CONFLICT]. [CLARIFY] sozinho não reprova, mas deve ser listado.

## 3. Loop (máximo 3 iterações)

- `PASS` → vá ao passo 4.
- `FAIL` → corrija **apenas** o que o relatório aponta ([MISS]/[CONFLICT]) e re-valide (nova iteração). `[CLARIFY]` → rode o protocolo do `/forge:clarify` para os itens antes de re-validar.
- Após a **3ª iteração** com FAIL: **pare** (não insista — validadores adversariais geram falsos positivos; o humano decide o que é real). Escalone via gate HITL abaixo apresentando os pontos remanescentes.

## 4. Gate HITL — `requirements_reviewed` (§12.1)

Apresente via `AskUserQuestion` (resumo de 2-3 linhas do estado + nº de iterações; **não** despeje o artefato no chat): **Approve** / **Review (loop de ajuste)** / **Reject** / **Block**. Registre a decisão:

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate requirements_reviewed --decision <decision> [--reason "<motivo>"] --iteration <n> --scope "<artefato-alvo>"
```

- **Approve** → `bash .forge/scripts/spec-transition.sh <change-id> requirements-ready` e reporte o próximo comando (`/forge:design` em scale ≥2; `/forge:tasks` em scale 1; `type: bugfix` scale ≥2 pode ir direto a `/forge:tasks` — design é opcional para esse tipo, sugira `/forge:design` só se a correção tiver decisão arquitetural).
- **Review** → use o motivo como instrução e volte ao passo 1 (conta como nova rodada de loop; registre com `--iteration <n>` e o registro fica no approvals.yaml), sujeito ao teto e à regra de convergência abaixo: no teto, a escalada ao dono é obrigatória.
- **Reject** → registre e pare; sugira `/forge:close --reason rejected` se o change não segue.
- **Block** → registre a causa e pare (`spec-transition.sh <id> blocked --reason "<causa>"`).

### Teto e convergência do Review

Vale para este gate e, por remissão, para `design_reviewed` e `tasks_reviewed`. Existe porque um revisor adversarial sempre acha o próximo caso de borda de um mecanismo que cresce a cada correção: sem teto e sem régua estável, o loop delegado já chegou a 14 rodadas num mesmo gate.

- **Teto.** O gate tem teto de 3 rodadas de Review consecutivas, delegadas ou não (humano decidindo, humano que delegou a decisão a um revisor adversarial, ou `yolo-gate`), o mesmo número do loop builder→validator do §3. Cada Review é registrado com `--iteration <n>`, sendo `n` a posição da rodada na série consecutiva de Review deste gate, e o `approval-log.sh --iteration` recusa `n` acima de 3, de modo que uma quarta rodada não tem como ser registrada como Review. Ao atingir o teto (terceiro Review ainda com pendência), a escalada ao dono é obrigatória: apresente a série (achados de cada rodada e o mecanismo que cada um tocou) e peça a decisão de causa raiz — simplificar o mecanismo, mover a fronteira ou aceitar o risco —, registrada no approvals.yaml com o motivo começando por `escalada-teto:`. O dono decide Approve, Reject, Block ou um Review que abre série nova (`--iteration 1`) com a causa raiz escolhida como instrução; revisor delegado e `yolo-gate` nunca abrem série nova por conta própria.
- **Régua de severidade estável.** A régua de severidade (o que é BLOCKER, o que é MAJOR, o que é nota) é fixada na primeira rodada e repetida literalmente no prompt de cada rodada seguinte, junto com a lista dos achados anteriores e o mecanismo de cada um; uma régua que muda entre rodadas impede até de reconhecer a série.
- **Convergência.** Uma rodada de Review só pode abrir BLOCKER novo se o achado não for consequência direta da correção da rodada anterior no mesmo mecanismo; se for, ele entra como nota no motivo e não reabre o ciclo, e quem decide sobre ele é o dono, no Approve ou na escalada.
- **Causa raiz.** Quando o mesmo mecanismo reaparece pela segunda rodada seguida, o prompt do decisor (revisor delegado ou `yolo-gate`) pede causa raiz em vez de correção pontual: por que o mecanismo gera um caso de borda novo a cada correção, e se a saída é simplificá-lo ou mover a fronteira; a resposta vai no motivo do Review.

## Regras

- Pré-condição: status `proposed` (ou `requirements-ready` para refinamento — sem nova transição).
- A transição falha se restar `NEEDS CLARIFICATION`? O validador estrutural não checa conteúdo no MVP2 — é SUA responsabilidade não aprovar com pendências abertas.
- Toda decisão que não seja Approve exige motivo (o script recusa sem `--reason`).

## Modo autônomo (--yolo)

Se `autonomy.mode: yolo` (`forge.yaml`) ou `--yolo` na invocação, este gate não para no `AskUserQuestion`: invoque o agent `yolo-gate` (model **opus**, effort **high**) sobre o artefato — ele analisa, decide (approve/review/reject/block) e registra em `approvals.yaml` com `autonomous: true` via `approval-log.sh --autonomous`. `review` autônomo alimenta o loop até 3 iterações e então escala ao humano. Falhas de execução e conflitos de fontes continuam parando (não são gates). Ver `.forge/rules/conventions/autonomy-yolo.md`.
