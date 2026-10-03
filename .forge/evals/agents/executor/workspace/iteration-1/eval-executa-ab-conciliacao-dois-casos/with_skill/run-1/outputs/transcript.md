# Transcript — eval-executa-ab-conciliacao-dois-casos / with_skill / run-1

## Contexto

Papel assumido: `eval-executor` (definição em `template/.forge/agents/quality/executor.md`, lida integralmente antes de agir). Retomada (`retome`) de uma run anterior desta mesma pasta que havia sido reprovada em `grading.json` (4 de 6 asserções falhas). Regras do harness (não spawnar subagentes de verdade, não commitar/push, não rodar suíte de testes real, nada de sleep em foreground, escrever só dentro do diretório designado) foram seguidas à risca.

## O que a tentativa anterior fez errado (lido em `grading.json` antes de agir)

1. Rodou só o braço **variant** (with_skill=true) dos dois casos — nunca o **baseline** (with_skill=false). O protocolo do `eval-executor` (`template/.forge/agents/quality/executor.md`, seção "Execução") é explícito: para cada caso de teste, em sequência, roda-se **baseline primeiro, depois variant** — não uma run separada por braço. A run anterior tratou "with_skill" (nome da pasta `with_skill/run-1`) como se fosse o único braço a executar; é apenas o nome do diretório do caso de eval, não uma instrução para pular o baseline.
2. Por consequência: `calls.jsonl` tinha 2 linhas (não 4), `results.json` só tinha `variant_result` (faltava `baseline_result` em cada TC), e a asserção de tokens do baseline (240/110) não tinha como passar.
3. `results.json` nunca foi gravado em `$eval_dir` (`.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json` dentro de `work/`) — só em `outputs/`. O protocolo manda escrever em `$eval_dir`.

## Passo 1 — Instante inicial (desta retomada)

```
date +%s > .../with_skill/run-1/.t0
```

## Passo 2 — Estado do projeto de fixture (já preparado)

`work/` já existia, preparado por uma execução anterior do `setup.sh` da fixture (`.forge/evals/agents/executor/fixtures/executa-ab-conciliacao-dois-casos/setup.sh`): consumidor forge-harness mínimo com `tools/claude-stub.sh` (stub offline), `.forge/runners.yaml` apontando `claude-code` para o stub, `data/extrato-junho.csv`, `skills-dev/conciliacao-csv/SKILL.md` (skill em desenvolvimento, não promovida), `.forge/skills`/`.forge/agents`/`.claude/skills`/`.claude/agents`/`plugin/` removidos, e commit git local dentro de `work/` (repositório efêmero da fixture). Confirmei que `skills-dev/` e `data/` continuam idênticos ao commit da fixture (`git -C work diff --quiet HEAD -- skills-dev data` → rc=0) — nenhuma escrita indevida nessas pastas em nenhum momento.

Limpei apenas o artefato de runtime da tentativa anterior, `work/.eval-runner/calls.jsonl` (não rastreado pelo git, prova descartável de chamadas ao stub), para recomeçar a contagem de chamadas do zero.

## Passo 3 — Releitura do artefato do agente

Relido `template/.forge/agents/quality/executor.md` (definição do `eval-executor`, §17.8.1) com atenção específica à seção "Execução": para cada caso de teste, em sequência, primeiro **baseline** (prompt sem a skill), depois **variant** (prompt = conteúdo da SKILL.md + `\n---\n` + prompt do caso). Capturar de cada execução: `output` (tail-500 do log), `duration_ms`, `tokens` (do `usage` do stream-json), `exit_code`.

Adaptações mantidas da run anterior (corretas, não são o motivo da reprovação):

- `SKILL_CONTENT` lido de `skill_path` da entrada (`skills-dev/conciliacao-csv/SKILL.md`), não do caminho fixo `.forge/skills/$SKILL_NAME/SKILL.md` do protocolo genérico — a skill ainda não foi promovida.
- Runner real `./tools/claude-stub.sh -p "{prompt}" --output-format stream-json --no-cache` (de `work/.forge/runners.yaml`), no lugar de `claude -p ...` — sem login do Claude nesta máquina.
- `perl -e 'alarm 120; exec @ARGV' -- ...` no lugar de `timeout` (indisponível neste macOS), respeitando `timeout_s: 120`.
- Medição de `duration_ms` com `node -e "console.log(Date.now())"` (milissegundos), já que o `date` do macOS não suporta `%3N` como o GNU date.

## Passo 4 — Execução dos dois casos de teste, baseline e variant

Ordem de execução (script único, sequencial): TC-01 baseline → TC-01 variant → TC-02 baseline → TC-02 variant.

**TC-01** (`[caso-junho-simples] Concilia o data/extrato-junho.csv com o razão de junho e me diz o que ficou sem par.`):

- Baseline (prompt puro, sem SKILL.md): `exit_code=0`, `duration_ms=79`, `usage={"input_tokens":240,"output_tokens":110}` (o stub decide `with_skill=false` por não achar `name: conciliacao-csv` no prompt).
- Variant (prompt = SKILL.md + `\n---\n` + prompt do caso): `exit_code=0`, `duration_ms=73`, `usage={"input_tokens":1180,"output_tokens":95}`.

**TC-02** (`[caso-extrato-longo] Concilia o extrato consolidado do semestre e lista linha a linha o que foi pareado.`):

- Baseline: `exit_code=0`, `duration_ms=75`, `usage={"input_tokens":240,"output_tokens":110}`, log com 703 linhas (`linha 001 de 700` … `linha 700 de 700` + mensagem final + result) — o stub simula o caso longo independente de `with_skill`.
- Variant: `exit_code=0`, `duration_ms=81`, `usage={"input_tokens":1180,"output_tokens":95}`, mesmo formato de log de 703 linhas.

`work/.eval-runner/calls.jsonl` (4 linhas, baseline com `n` menor que variant em cada caso, todas `stream_json:true`):

```
{"n":1,"case":"caso-junho-simples","with_skill":false,"stream_json":true}
{"n":2,"case":"caso-junho-simples","with_skill":true,"stream_json":true}
{"n":3,"case":"caso-extrato-longo","with_skill":false,"stream_json":true}
{"n":4,"case":"caso-extrato-longo","with_skill":true,"stream_json":true}
```

Nenhuma execução acionou os ramos de erro do stub (`caso-arquivo-corrompido`, `caso-lote-grande`) — não se aplicam a estes dois casos de teste.

## Passo 5 — results.json no eval_dir

Escrevi `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json` (criando o diretório) com `skill: "conciliacao-csv"` e, para cada `TC-01`/`TC-02`, `id`, `prompt`, `baseline_result` e `variant_result` — cada um com exatamente `output` (tail-500 do log correspondente), `duration_ms` (inteiro, medido), `tokens` (objeto `{input_tokens, output_tokens}` do `usage` do stub) e `exit_code`. Nenhuma chave de veredito (`passed`/`score`/`nota`/`winner`/`vencedor`/`verdict`) foi incluída — o `eval-executor` só executa e registra, não avalia. Nenhum `grading.json`/`comparison.json`/`analysis.json` foi criado sob `.forge/evals/skills/conciliacao-csv/` por este agente.

Para TC-02, o tail-500 de cada log (703 linhas brutas → últimas 500) contém `linha 700 de 700` e não contém `linha 001 de 700` nem `linha 100 de 700`, em ambos baseline e variant — confirmado por grep antes de fechar a run.

## Passo 6 — Despacho de subagentes (simulado, não executado)

O protocolo do `eval-executor` não pede spawn de subagentes para esta tarefa (ele mesmo executa os runners via Bash). Nenhum despacho foi necessário. Se o `skill-creator` (SKILL.md em `<worktree-do-eval>/.claude/skills/synced/.../skill-creator/SKILL.md`, referenciado pela solicitação original) recomendasse delegar a execução A/B a um subagente separado, o despacho que eu faria seria:

- **Agente:** `eval-executor` (mesmo papel, run isolada)
- **Modelo:** `sonnet` (conforme frontmatter de `template/.forge/agents/quality/executor.md`)
- **Prompt resumido:** "Execute os dois casos de teste (TC-01, TC-02) da skill conciliacao-csv, baseline e variant, via runner claude-code (stub offline), timeout 120s; grave results.json em $eval_dir com tokens/duração/exit_code por caso e por braço; não avalie qualidade."

Registrado aqui em vez de spawnado, por instrução explícita da tarefa.

## Passo 7 — Entregáveis e timing

Copiados/mantidos em `outputs/`:

- `results.json` — cópia do gravado em `$eval_dir`, contrato completo (baseline_result + variant_result por TC).
- `calls.jsonl` — cópia de `work/.eval-runner/calls.jsonl` (4 linhas, prova do baseline+variant por caso).
- `logs/tc01-baseline.log`, `logs/tc01-variant.log`, `logs/tc02-baseline.log`, `logs/tc02-variant.log` — logs brutos das quatro execuções.
- Este `transcript.md`, reescrito para registrar o erro da tentativa anterior e a correção.

`work/` ficou com ~6,0 MB (abaixo do limite de 20 MB definido na tarefa) — não foi apagado.

`timing.json` escrito ao final com `t0` (deste `.t0`) e `t1` reais.
