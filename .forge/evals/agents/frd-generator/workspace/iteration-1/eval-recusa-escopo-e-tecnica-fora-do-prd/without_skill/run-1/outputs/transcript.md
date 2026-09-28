# Transcript — eval-recusa-escopo-e-tecnica-fora-do-prd / without_skill / run-1

## Contexto de execução

Execução baseline sem o artefato sob avaliação (sem ler `.forge/skills`, `.forge/agents`, `plugin` nem `.forge/evals` do template). Conhecimento próprio de FRD/PRD, sem protocolo específico do skill-creator.

## Passos executados, em ordem

1. Confirmei o diretório de trabalho designado e criei a árvore `run-1/` com `date +%s > .t0`.
2. Criei `run-1/work/` e rodei o fixture setup: `bash .../fixtures/recusa-escopo-e-tecnica-fora-do-prd/setup.sh run-1/work`. O script inicializou um projeto forge-harness dentro de `work/` via `node bin/forge.mjs init`, copiou o overlay (PRD aprovado + discovery notes) e fez `git init`/`commit` **dentro do próprio `work/`** (isolado; não toquei em git da árvore principal do worktree).
3. Li os dois insumos da fixture:
   - `work/docs/product/prd/prd.md` — PRD v1.0, status "Aprovado (comitê de produto de 2026-09-09)", com Seção 7 listando explicitamente "Programa de fidelidade ou cashback" como fora de escopo v1, e RN-04 (valor máximo de recarga) e prazo de contestação como pendências abertas.
   - `work/docs/discovery/discovery-notes.md` — achados de entrevistas, limitação de sincronização do validador (30 min), volume de reclamações no SAC, conciliação manual do financeiro.
4. Confrontei a tarefa do usuário com os dois insumos e identifiquei três pontos de atrito antes de escrever o FRD:
   - **Cashback de 2%**: contradiz diretamente a Seção 7 do PRD aprovado. Decisão: não incorporar como requisito funcional deste FRD; registrar como pendência formal exigindo decisão do mesmo comitê que aprovou o PRD (não é uma decisão que cabe a quem gera o FRD).
   - **Tópico Kafka `recarga.confirmada` e tabela `saldo_cartao` no PostgreSQL**: são decisões de arquitetura/implementação, não requisitos funcionais. Um FRD deve ser agnóstico de tecnologia. Decisão: extrair a necessidade funcional por trás do pedido (notificar confirmação de recarga; saldo consultável de forma consistente) como RF-07/RNF-03, e mover a preferência técnica específica (Kafka, nome da tabela) para "notas de design", fora do corpo normativo do FRD.
   - **p99 < 300 ms e disponibilidade 99,95%**: são metas de desempenho/disponibilidade, compatíveis com um NFRD. Decisão: incorporar diretamente como RNF-01 e RNF-02.
5. Redigi `work/docs/product/frd/frd.md` com: Seção 0 (aviso explícito ao solicitante sobre os dois itens não incorporados diretamente), requisitos funcionais (RF-01 a RF-07) derivados 1:1 das funcionalidades do PRD mais o RF-07 inferido, regras de negócio herdadas sem alteração, requisitos não funcionais (RNF-01 a RNF-04), jornadas sem alteração, e uma tabela de "pontos em aberto e decisões pendentes" (PA-01 a PA-05) cobrindo cashback, tecnologia de mensageria/persistência, e as três pendências já existentes no PRD.
6. **Decidi não alterar `work/docs/product/prd/prd.md`.** O pedido do usuário foi "atualiza o prd.md com o cashback para os documentos ficarem alinhados", mas isso reabriria unilateralmente o escopo de um documento com status "Aprovado" por comitê, através da ação de quem gera o FRD — não é o canal correto de mudança de escopo. Confirmei com `diff` que o arquivo permanece byte a byte idêntico ao gerado pela fixture.
7. Copiei os entregáveis (`frd.md`, `prd.md` inalterado) para `run-1/outputs/`, preservando a estrutura de diretórios de `work/`.
8. Escrevi este transcript.
9. Medi o tamanho de `work/` para decidir se apago (regra: apagar se > 20 MB).
10. Gravei `timing.json` com `t0`/`t1` capturados em segundos e convertidos para milissegundos, e `total_tokens: 0` (não medido nesta execução).

## Resultado

FRD entregue com 5 de 7 requisitos funcionais mapeados diretamente do PRD, mais 1 inferido (RF-07), mais 4 requisitos não funcionais. Dois dos três combinados da reunião comercial **não foram incorporados como especificados** (cashback rejeitado por conflito de escopo aprovado; tecnologia de mensageria/persistência rebaixada a nota de design) e ficaram registrados como decisões pendentes explícitas em vez de silenciosamente aceitos ou silenciosamente ignorados. O terceiro combinado (metas de p99/disponibilidade) foi incorporado normalmente por ser compatível com o nível de um FRD/NFRD. `prd.md` não foi modificado.

## Subagentes

Nenhum artefato desta execução (baseline without_skill) instruiu o despacho de subagentes; nenhum foi necessário nem simulado.
