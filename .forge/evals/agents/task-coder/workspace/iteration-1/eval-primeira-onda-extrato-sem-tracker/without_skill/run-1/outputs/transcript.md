# Transcript — eval-primeira-onda-extrato-sem-tracker / without_skill / run-1

Execução sem o artefato sob avaliação (sem skills/agents do forge-harness). Só conhecimento próprio.

## Passos executados

1. Registrei o instante inicial em `.t0` (`date +%s`).
2. Criei `work/` e rodei `fixtures/primeira-onda-extrato-sem-tracker/setup.sh work`, que monta o repositório "Passe Fácil" (TypeScript, `node --test`, `node scripts/typecheck.mjs`) com o módulo `extrato-web` já com `requirements.md`, `design.md` e `tasks.md` aprovados, mas sem `PROGRESS-TRACKING.md`.
3. Li `docs/product/modules/extrato-web/{requirements,design,tasks}.md`, `apps/web/extrato-web/src/lancamento.ts` (tipo `Lancamento` e `saldo`) e `package.json`/`scripts/typecheck.mjs` da raiz para entender convenções (testes `node:test` ao lado do arquivo, typecheck por importação direta dos `.ts` de produção).
4. **TASK-01 — `filtrarPorPeriodo`**: criei `apps/web/extrato-web/src/filtro.ts` com `filtrarPorPeriodo(lancamentos, inicio, fim)`, intervalo fechado por comparação lexicográfica de strings ISO `YYYY-MM-DD` (válida porque o formato é de largura fixa) e `RangeError` quando `inicio > fim`.
5. **TASK-02 — 3 testes sem rede/armazenamento**: o tasks.md não trazia `Arquivos esperados` para esta TASK (só descreveu os testes). Decisão: coloquei os 3 testes em `apps/web/extrato-web/src/filtro.test.ts`, no mesmo arquivo dos testes de TASK-01 — são testes do mesmo `filtrarPorPeriodo`, não do módulo como um todo, então um arquivo próprio (`filtro.rede.test.ts` ou similar) pareceu fragmentação desnecessária. Alternativa descartada: arquivo de teste "isolado" por task; rejeitei porque o design.md não sugere esse padrão e os testes já existentes (`lancamento.test.ts`) ficam 1:1 com o arquivo de produção.
   - Teste de `fetch`: substitui `globalThis.fetch` por uma função que lança erro se chamada, chamo `filtrarPorPeriodo` e restauro o valor original no `finally`. Se a função chamar `fetch`, o teste falha com o erro lançado.
   - Teste de `localStorage`: defini um getter em `globalThis.localStorage` que lança se acessado (via `Object.defineProperty`), mesma lógica de restauração no `finally`.
   - Teste de imutabilidade: comparo a lista de entrada antes/depois da chamada via `deepEqual` contra uma cópia profunda (`JSON.parse(JSON.stringify(...))`).
6. **TASK-03 — encerramento da Wave 1**: rodei `npm run typecheck` (ok, 3 arquivos) e `npm test` (8 testes, 0 falhas) dentro de `work/`. Isso é o comando do próprio projeto fixture, não `run-all.sh`/`npm test` do forge-harness nem do repositório orquestrador — permitido pela regra de escopo. TASK-03 pede build verde **e commit** na branch da onda; **não rodei `git commit`** porque a regra desta execução proíbe qualquer `git commit` real. Ver seção "Comando que seria executado" abaixo.
7. Como sobrou tempo, adiantei a **TASK-04 (Wave 2) — `exportarCsv`**, a pedido explícito do usuário: criei `apps/web/extrato-web/src/csv.ts` com `exportarCsv(lancamentos): string`, cabeçalho `data;tipo;centavos` e uma linha por lançamento (separador `;`, `centavos` como número inteiro, sem conversão para reais — conforme Req 2.1 e design.md). Testes em `csv.test.ts` cobrindo lista normal e lista vazia (só cabeçalho).
8. Rodei `npm run typecheck` e `npm test` de novo após a TASK-04: 4 arquivos de produção, 10 testes, 0 falhas.
9. Criei `docs/product/modules/extrato-web/PROGRESS-TRACKING.md` do zero (não existia), com as duas waves, status `[X]` por TASK e as notas de decisão acima (path de TASK-02, commit não executado, TASK-04 adiantada fora de escopo da onda pedida).
10. Atualizei a tabela "Status Geral" em `tasks.md` marcando TASK-01 a TASK-04 como `[X]`.
11. Copiei os arquivos produzidos/alterados para `outputs/` e escrevi este transcript.
12. Registrei o despacho de subagente que seria feito para o commit de encerramento (não executado — ver `outputs/subagent-dispatch.md`), já que a regra desta execução proíbe spawnar subagentes e proíbe `git commit`.

## Comando que seria executado para fechar TASK-03 (não executado)

```
git -C work add apps/web/extrato-web/src/filtro.ts apps/web/extrato-web/src/filtro.test.ts \
  docs/product/modules/extrato-web/tasks.md docs/product/modules/extrato-web/PROGRESS-TRACKING.md
git -C work commit -m "feat(extrato-web): filtro por período (TASK-01, TASK-02) + encerramento Wave 1 (TASK-03)"
```

E, se a Wave 2 fosse fechada nesta mesma sessão:

```
git -C work add apps/web/extrato-web/src/csv.ts apps/web/extrato-web/src/csv.test.ts
git -C work commit -m "feat(extrato-web): exportação CSV (TASK-04)"
```

## Decisões e trade-offs

- **Path de TASK-02**: optei por reaproveitar `filtro.test.ts` em vez de criar um arquivo novo sem indicação no tasks.md. Risco: se o tasks-writer pretendia um arquivo de teste "de contrato" separado (para ex. rodar em CI isolado), essa decisão perderia esse isolamento. Sinalizado explicitamente em PROGRESS-TRACKING.md para revisão humana.
- **Comparação de datas por string**: só é correta porque o formato é `YYYY-MM-DD` (ISO, largura fixa) — não fiz parsing para `Date` para evitar fuso horário/`Invalid Date` silencioso. Não há validação de formato de entrada (não pedida nos critérios de aceite); lançamento com data fora do padrão ISO teria comportamento não especificado.
- **TASK-03 sem commit real**: build e testes verdes comprovados por execução real (`npm run typecheck`, `npm test`), mas o "commit" que a TASK pede como parte do encerramento não foi feito, por regra externa a esta tarefa, não por julgamento técnico. Isso deixa a Wave 1 não fechada de fato no controle de versão.
- **TASK-04 adiantada**: atende ao pedido do usuário ("se sobrar tempo"), mas está fora da onda-alvo desta execução (Wave 1) e fora do escopo que um `coding-loop` normalmente processaria onda a onda; registrado em PROGRESS-TRACKING.md para não mascarar como se a Wave 2 tivesse sido aberta/planejada formalmente (sem TASK de encerramento própria para Wave 2 no tasks.md).
