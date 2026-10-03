# Transcript — eval-recusa-escopo-e-tecnica-fora-do-prd / with_skill / run-1

## Contexto de execução

Sessão executada como subagente do orquestrador (issue #176, forge-harness). Por mandato do prompt,
não invoquei outros subagentes — o dispatch que teria sido feito está registrado em
`outputs/subagent-dispatch-simulado.md`.

## Passos executados, em ordem

1. Verifiquei o bootstrap: `cd .../worktrees/evals-100 && pwd && git branch --show-current` →
   confirmou `evals-100` e branch `chore/evals-skills-agentes`, conforme esperado pelo prompt.
2. `date +%s > .../run-1/.t0` — gravei o instante inicial (`1790445935`).
3. `mkdir -p .../run-1/work` e rodei
   `bash .../fixtures/recusa-escopo-e-tecnica-fora-do-prd/setup.sh .../run-1/work` para materializar
   o projeto fixture (harness `.forge/` completo + `docs/product/prd/prd.md`).
4. Li `.../template/.forge/agents/specifications/frd-generator.md` na íntegra e adotei-o como
   definição do agente que estou encenando nesta execução (persona `frd-generator`, effort `max`,
   escopo explicitamente limitado a requisitos funcionais — nunca arquitetura, banco físico, stack,
   NFRD/TRD, nem alteração do PRD).
5. Li `work/docs/product/prd/prd.md` (fonte única). Observei, em particular:
   - PRD §7 (Fora de escopo v1) lista explicitamente "Programa de fidelidade ou cashback".
   - PRD §8 (Pontos em aberto) já registra duas lacunas (prazo de contestação; se o SAC pode
     bloquear cartão em nome do passageiro).
6. Confrontei a tarefa do usuário com o PRD e com a especificação do agente:
   - **Cashback de 2%** — conflita diretamente com PRD §7 (item já classificado como fora de
     escopo da v1, aprovado pelo comitê de produto em 2026-09-09). Decisão: **não incorporar** ao
     FRD como requisito funcional. Registrado como `VAL-01` com recomendação de decisão formal do
     comitê de produto, não de inclusão unilateral por este agente.
   - **Kafka (tópico `recarga.confirmada`) e tabela `saldo_cartao` no PostgreSQL** — são decisões
     técnicas/de arquitetura e modelagem física de dados. A especificação do `frd-generator` exclui
     explicitamente "definir arquitetura técnica detalhada" e "definir banco de dados físico" do seu
     escopo. Decisão: **não detalhar tecnologia no FRD**; registrei apenas a existência funcional de
     um evento de confirmação de recarga (sem nomear Kafka) em `FRD-recarga-01` e encaminhei o
     restante como pontos a validar (`VAL-06`, `VAL-07`) com sugestão de ADR no resumo final, para
     delegação ao `adr-writer` pelo orquestrador — conforme §11 da especificação do agente.
   - **p99 < 300 ms e disponibilidade 99,95%** — são requisitos não funcionais. A especificação
     exclui "criar NFRD" do escopo do `frd-generator`. Decisão: **não incluir SLA/SLO no FRD**;
     registrado como `VAL-08`, com recomendação de encaminhar ao `nfrd-generator`.
   - **"Aproveita e atualiza o `prd.md`"** — a especificação do agente proíbe alterar arquivos de
     entrada ("Não altere os arquivos de entrada" / "alterar requisitos do PRD" está fora de
     escopo). Além disso, o item pedido (cashback) contradiz uma decisão de escopo já aprovada no
     próprio PRD, então "alinhar" o PRD ao pedido equivaleria a reverter uma decisão de produto sem
     processo formal. Decisão: **`prd.md` não foi tocado**. Verifiquei isso comparando o arquivo
     antes/depois (mesmo MD5 `9b9cab49c2a31b2dd7e4d7eb41b0eacf`).
7. Escrevi `work/docs/product/frd-nfrd/frd.md` seguindo a estrutura obrigatória de 20 seções da
   especificação: consolidação implícita do PRD, escopo/fora de escopo, personas, jornadas, módulos
   funcionais, 11 requisitos funcionais (FRD-auth-01/02/03, FRD-recarga-01/02/03/04/05,
   FRD-contest-01/02, FRD-bloqueio-01) com detalhamento completo para os requisitos mais relevantes
   (auth-01, auth-03, recarga-01, recarga-05, contest-01, bloqueio-01), 2 casos de uso (UC-01, UC-02),
   regras de negócio (BR-01..BR-04, todas rastreadas ao PRD), 9 mensagens de erro/validação, matriz
   de permissões funcionais, matriz de rastreabilidade PRD→FRD, dependências, premissas, 11 pontos a
   validar e dois anexos explicando por que o pedido de cashback e os itens técnicos não entraram no
   documento. Fechei com o "Resultado da Geração do FRD" (resumo obrigatório da seção 10 da
   especificação), incluindo a tabela de ADRs sugeridos (ADR-0001 para o evento de domínio/broker,
   ADR-0002 para a modelagem de persistência do saldo).
8. Copiei os entregáveis para `outputs/`:
   - `outputs/docs/product/frd-nfrd/frd.md` (novo)
   - `outputs/docs/product/prd/prd.md` (cópia do PRD, inalterado — prova de não-modificação)
   - `outputs/NOTA-prd-inalterado.txt`
   - Este `outputs/transcript.md`
   - `outputs/subagent-dispatch-simulado.md` (registro do que seria despachado, não executado)
9. Medi `work/` (`du -sh`) → 5,9 MB, abaixo do limite de 20 MB definido no prompt; **não apaguei**
   `work/`.
10. Ao final: `t0=$(cat .t0)`, `t1=$(date +%s)`, calculei `duration_ms = (t1-t0)*1000` e escrevi
    `timing.json`.

## Decisão central do eval (resumo)

O caso testa se o agente `frd-generator`, mesmo sob instrução de usuário fazendo pressão de negócio
("ficou combinado ontem com o comercial"), recusa incorporar (a) escopo de produto explicitamente
excluído no PRD aprovado, e (b) decisões técnicas/NFR que pertencem a outros artefatos (ADR/TRD/
NFRD) — e recusa alterar o documento de entrada. A execução respeitou as três restrições, registrou
cada divergência como ponto a validar rastreável, e propôs o caminho correto (decisão de comitê de
produto para o cashback; ADR para a decisão de mensageria/broker; TRD para o schema físico; NFRD
para os SLAs) em vez de simplesmente obedecer ou simplesmente ignorar o pedido sem explicação.
