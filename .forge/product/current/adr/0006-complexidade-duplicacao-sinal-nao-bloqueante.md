# 0006. Complexidade (CRAP) e duplicação estrutural: sinal não-bloqueante, gate bloqueante, ou não adotar

- **Status:** accepted
- **Data:** 2026-11-03
- **Decisores:** milton

## Contexto e Problema

O relatório `reference/plano-ub-mode-vs-forge-harness.md` identificou que o forge-harness não mede complexidade ciclomática nem duplicação estrutural sistematicamente, enquanto a skill `unclebob/ub-mode` trata ambas como gate bloqueante com limiar fixo (CRAP < 10, duplicação ≥ 0,8, via `crapper`/`dryer`). A convenção já registrada neste repositório (`rules/conventions/code-style.md:58,99,135`) trata complexidade como gatilho de extração (não gate) e duplicação pela regra de três (não limiar fixo) — uma filosofia deliberadamente diferente, de controle qualitativo em vez de numérico.

**Nota de atualização:** o repositório `unclebob/ub-mode` ganhou licença MIT em 2026-11-02 (commit `3da62bf`), posterior ao relatório original. A razão para não copiar o `SKILL.md` literalmente deixa de ser "sem licença" (resolvida) e passa a ser "escopo e qualidade do texto não avaliados para este repositório" — a decisão de não copiar o texto permanece, a justificativa muda.

**ADRs do baseline que restringem as opções abaixo:** ADR 0001 estabelece o princípio de zero dependências de execução (decidido para o engine do grafo, mas como princípio geral do harness) — um `jscpd` como gate bloqueante que exige instalação no consumidor tensiona esse princípio, não o viola diretamente (0001 não cobre este mecanismo por escopo); ADR 0005 (camada opt-in instalada sob demanda, mesmo padrão já usado pela camada semântica do `/forge:kb`) é o precedente de como introduzir uma dependência nova sem violar 0001; ADR 0003 (Red-first) já decidiu, para outro mecanismo, que "sinal avisa, não veta" quando descartou coverage-diff como gate bloqueante — mesmo princípio em jogo aqui.

## Drivers da Decisão

- Precedente do próprio repositório (LDG-0061, `max-lines`): limiar fixo gera fatiamento cosmético perto da borda.
- Convenção qualitativa já estabelecida (`code-style.md`) não deve ser substituída por decreto numérico sem evidência real.
- Zero dependências de execução obrigatórias no harness em si (ADR 0001); qualquer dependência nova precisa do padrão opt-in de ADR 0005.
- Risco de segurança documentado nas ferramentas upstream do ub-mode (`crapper`: CWE-829, CWE-776).

## Opções Consideradas

1. **Limiar fixo, gate bloqueante** (filosofia ub-mode).
2. **Sinal não-bloqueante** no `code-evaluator`/`quality-reviewer`.
3. **Não adotar.**
4. **Depender das ferramentas upstream do ub-mode** (`crapper`/`dryer`).

## Decisão

**Opção 2 — sinal não-bloqueante**, mesmo princípio de ADR 0003 ("sinal avisa, não veta").

O spike real sobre `Payments.DevPortal` (50 arquivos, 429 funções; resultado completo em `.forge/specs/active/adopt-ub-mode-practices/spike-result.md` antes do archive, depois incorporado ao histórico do change arquivado) mediu, no limiar inicial do ub-mode (CC < 10), **50% de falso-positivo** numa amostra completa de 8 achados (n < 20, sem subamostragem) — bem acima dos 30% do critério de decisão (design §2.3 passo 3). Subindo o limiar (nunca descendo, por desenho) para 15, o falso-positivo cai para 33,3%, ainda acima de 30%; só em 20 o falso-positivo zera (0/2 achados). Mas nesse limiar o gate captura 2 de 429 funções (0,47%) — sinal raro demais para justificar um bloqueio de merge.

A Opção 1 (limiar fixo bloqueante) fica descartada não por ruído alto no limiar final escolhido, mas pela tensão oposta: um limiar baixo o suficiente para capturar algo relevante reabre exatamente o fatiamento cosmético que `LDG-0061` já documentou neste repositório, e um limiar alto o suficiente para não reabrir isso quase nunca dispara — nenhum ponto do espectro serve a um gate bloqueante.

A duplicação não teve achado algum nos limiares padrão do `jscpd` (`--min-lines 5 --min-tokens 50`) neste universo — resultado inconclusivo, nem confirma nem refuta a hipótese de ruído, sem amostra para aplicar a regra dos 30%.

A Opção 3 (não adotar) fica descartada: mesmo sem gate bloqueante, a complexidade ciclomática por função é um dado objetivo que soma à revisão humana sem o custo/risco de travar merge — descartar o instrumento desperdiçaria a medição já feita.

A Opção 4 permanece descartada pelos motivos de segurança registrados em Contexto.

## Consequências

- **Positivas:** `code-evaluator`/`quality-reviewer` ganham um dado objetivo (CC por função) para contextualizar a revisão de extração por julgamento já praticada (`code-style.md`), sem o risco de fatiamento cosmético de um gate bloqueante; a convenção qualitativa atual (regra de três, gatilho de extração) permanece intacta, reforçada em vez de substituída.
- **Negativas/débitos:**
  1. O instrumento de medição (`tools/spike-complexity-duplication.mjs`) conta `LogicalExpression` (`&&`/`||`/`??`) como ponto de decisão — 1 dos 4 falsos positivos no limiar 10 (`schemaFields`) veio especificamente desse viés (código idiomático com optional chaining/nullish coalescing, não ramificação estrutural real: removendo os pontos de `LogicalExpression`, o CC cai de 13 para 7, abaixo do limiar); um segundo caso (`operationPage`) foi considerado na 1ª rodada de verificação mas descartado na 2ª — seu CC permanece acima do limiar mesmo sem `LogicalExpression` (cai de 18 para 12), então sua classificação como falso-positivo não se apoia nesse viés, só na razão estrutural (builder aditivo) já registrada em `spike-result.md`. Qualquer uso futuro do sinal precisa corrigir o viés confirmado (ao menos 1 caso real) primeiro, ou herda um viés de instrumento, não só de domínio; se a extensão do viés para `ConditionalExpression` (`?:`) explicaria mais casos como `operationPage` é pergunta aberta, não resposta dada por este spike.
  2. A implementação concreta do sinal (P2/P3 do relatório original — integração real no `code-evaluator`/`quality-reviewer`) fica fora do escopo executável deste change — abre change futuro, condicionado à correção de instrumento do item 1.
  3. Duplicação como sinal fica sem validação real: a próxima medição (change futuro, ou reexecução deste mesmo roteiro sobre um universo maior) precisa confirmar se `jscpd` com limiares padrão produz sinal útil antes de integrá-lo a qualquer revisão.

## Links

- Change de origem: `adopt-ub-mode-practices`
- Relacionado: ADR 0001 (zero dependências de execução), ADR 0003 (sinal avisa, não veta), ADR 0005 (camada opt-in)
- LDG-0061 (precedente de fatiamento cosmético perto de limiar fixo)
