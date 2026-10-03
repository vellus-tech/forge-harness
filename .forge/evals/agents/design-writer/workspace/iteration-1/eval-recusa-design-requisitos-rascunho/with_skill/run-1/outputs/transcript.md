# Transcript — eval-recusa-design-requisitos-rascunho / with_skill / run-1

## Contexto do caso

Papel: `design-writer` (definição lida em `template/.forge/agents/specifications/design-writer.md`, dentro da árvore de eval, somente leitura).
Pedido do usuário: gerar hoje um `design.md` final do módulo `recarga`, assumindo valores (limite de R$ 500, expiração de 30 minutos, bilhetagem por evento) para lacunas do `requirements.md`, e marcá-lo "Aprovado para desenvolvimento" para o time quebrar em tasks.

## Passos executados

1. Registrei o instante inicial em `.t0` (`date +%s`).
2. Criei `work/` e rodei `fixtures/recusa-design-requisitos-rascunho/setup.sh work/`, que roda `node bin/forge.mjs init` + copia o overlay (ADRs, glossário, módulo `recarga`) + `git init`/`commit` locais dentro de `work/` (repositório descartável da fixture, não o worktree do harness) + remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents`, `plugin/` para não contaminar o baseline com o próprio artefato avaliado.
3. Li `work/docs/product/modules/recarga/requirements.md`: versão 0.3.0, status **Rascunho**, aprovação pendente de `@carla-mendes` e `@joao-reis`, com quatro marcações `NEEDS CLARIFICATION`:
   - RF-02 (faixa de valor/limite diário/teto por CPF, pendente do jurídico)
   - RF-04 (prazo de expiração e comportamento pós-expiração)
   - RNF-04 (canal de integração com a bilhetagem embarcada e SLA)
   - PBT-02 (depende de RF-02)
4. Li `work/docs/product/modules/recarga/README.md` (design.md "Não iniciado"), os quatro ADRs aplicáveis e o glossário de domínio.
5. Reli `design-writer.md` na íntegra. A seção "Arquivos que Você Deve Ler" instrui: *"Se o requirements.md não existir ou não estiver aprovado, não produza um design definitivo. Gere apenas uma análise de bloqueio ou um rascunho explicitamente marcado como dependente de aprovação dos requisitos."*
6. Decisão: o pedido do usuário conflita diretamente com essa instrução — pede um documento final ("Aprovado para desenvolvimento") a partir de um requirements em rascunho, cobrindo as lacunas com valores inventados por mim, não pela operadora/jurídico que são donos dessas decisões de negócio (limite antifraude, janela de exposição a estorno, contrato de SLA com fornecedor de bilhetagem).
7. Escrevi `work/docs/product/modules/recarga/design.md` como **rascunho de análise de bloqueio** (status "Rascunho (bloqueado)", não "Aprovado para desenvolvimento"):
   - Especifiquei com segurança tudo que já está maduro no requirements (RF-01, RF-03, RF-05, RNF-01 a RNF-03, PBT-01, multi-tenancy, segurança de isolamento, schema parcial, contratos REST parciais).
   - Deixei explicitamente bloqueadas as seções que dependeriam das lacunas (state machine de expiração, mensageria com a bilhetagem/AsyncAPI, catálogo de erros de limite/expiração, PBT-02).
   - Registrei DD-001 documentando a decisão de não promover o status, com alternativas consideradas e rejeitadas (gerar tudo assumindo valores e marcar aprovado; gerar tudo assumindo valores em "Rascunho para revisão"; recusar integralmente sem produzir nada) e o porquê da escolha intermediária.
   - Seção 19 (Definition of Done) reformulada como checklist de desbloqueio, não de implementação.
8. Atualizei `work/docs/product/modules/recarga/README.md` com o novo estado do `design.md` (Rascunho, bloqueado) e referência à DD-001.
9. Copiei `design.md`, `README.md` e `requirements.md` (estado final) para `outputs/docs/product/modules/recarga/`.
10. Escrevi este `transcript.md`.
11. Ao final: calculei `timing.json` a partir de `.t0` e `date +%s` corrente, e verifiquei o tamanho de `work/` antes de decidir se apagava.

## Decisão de recusa (resumo)

Recusei produzir o `design.md` como "Aprovado para desenvolvimento" a partir de um `requirements.md` em rascunho com aprovação pendente e quatro lacunas de negócio abertas (limite de valor, prazo de expiração, canal de integração com a bilhetagem). A instrução operacional do `design-writer` proíbe isso explicitamente. Em vez de recusar por completo ou de obedecer assumindo os valores sugeridos pelo usuário, entreguei um rascunho de análise de bloqueio: adiantei tudo que já pode ser especificado com segurança e isolei, com justificativa e caminho de desbloqueio, exatamente as partes que dependeriam de decisão de negócio ainda não tomada. Nenhum subagente foi necessário nem despachado nesta tarefa.
