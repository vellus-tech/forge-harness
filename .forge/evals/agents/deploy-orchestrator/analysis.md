# Análise do benchmark — agent `deploy-orchestrator`

Fonte: `workspace/iteration-1/benchmark.json` (agregação determinística via `aggregate_benchmark.py`, sem estatística no olho) + `workspace/iteration-1/review.html` (viewer estático) + leitura dos 6 `grading.json`/`transcript.md` (3 evals × with/without) e do artefato `template/.forge/agents/coding/deploy-orchestrator.md`.

## 1. Resultado (taxas e delta)

| Config | pass_rate médio | stddev | min | max |
|---|---|---|---|---|
| with_skill | 0.8767 | 0.1079 | 0.80 | 1.00 |
| without_skill | 0.3233 | 0.4215 | 0.00 | 0.80 |

Delta (com − sem) = **+0.55**. Tempo médio praticamente igual (205,3s com vs 204,3s sem; delta +1,0s) — o artefato não deixa a execução mais lenta, só mais correta. Tokens não instrumentados (0/0 nos dois lados — `timing.json` não grava `total_tokens`).

Veredito: delta ≥ 0,15 → **agrega**.

Por eval: eval 1 (implanta em stg) 0,83 com vs 0,17 sem; eval 2 (sincroniza Jira onda 4 em prd) 0,80 com vs 0,00 sem; eval 3 (recusa por Trivy medium arm64) 1,00 com vs 0,80 sem. O ganho é grande e consistente nos três, mas desproporcional: nos dois evals "operacionais" (1 e 2) o artefato é a diferença entre quase acertar tudo e falhar quase tudo; no eval de recusa de segurança (3) o baseline já acerta bastante por bom senso de domínio, e o artefato só refina a margem.

## 2. Asserções não discriminantes

- **`helm-upgrade-fixa-imagem-por-digest-com-atomic`** (eval 1): passou em `with_skill` e também em `without_skill` — deploy por digest com `--atomic` é prática de mercado conhecida o bastante para não depender do artefato. Não discrimina o valor do agent.
- Nenhuma outra asserção passa 100% nas duas condições — as demais 15 (5 do eval 2, 4 do eval 3, 5 restantes do eval 1) discriminam de fato: ou falham sistematicamente sem o artefato, ou dependem de detalhes só documentados nele (label JQL exata, ordem `getTransitionsForJiraIssue` → `transitionJiraIssue`, `repo_slug` do `AGENTS.md`, severidades do Trivy, arquitetura por scan separado).
- Uma asserção falhou nas **duas** condições (eval 2, "warning no PROGRESS-TRACKING.md por indisponibilidade do MCP Atlassian") — ver §4, é sintoma de ambiguidade do próprio artefato quanto a modo dry-run, não de incapacidade do modelo.

## 3. Onde o artefato ajudou / atrapalhou (com evidência de transcript)

**Ajudou, de forma decisiva:**
- Eval 1 — sem o artefato, o Trivy rodou só `HIGH,CRITICAL` (não `MEDIUM,LOW`), um único scan contra o digest do manifest list (não por arquitetura), `cosign verify` com regex curinga `https://github.com/.*/.github/workflows/.*` (não o `repo_slug` real) e nenhum passo de SBOM; nenhuma seleção de pod arm64, smoke em `/health/ready` nem verificação Kyverno; nenhum diff a partir da tag `deploy-stg-20260918-1420-*`. Com o artefato, todos esses pontos saíram certos porque a Fase 3.1/3.2/3.3, a Fase 5-7 e a Fase 1 do agente especificam exatamente esses comandos e valores.
- Eval 2 — sem o artefato: 0/5. Faltou o gate `APPROVED_BY` que aborta se vazio (Fase 0), a base do diff usou a tag de *stg* em vez da tag de *prd* (a asserção explicitamente exclui essa base), a JQL foi busca textual solta em vez de `labels = task:TASK-4N`, faltou `getTransitionsForJiraIssue` antes da transição, e o comentário não citou `ghcr.io/recarga@<digest>`. Com o artefato, 4/5 corretos — a Fase 0 (dupla confirmação), Fase 1 (tag de referência certa), e Fase 10 (JQL por label, ordem de chamadas MCP, conteúdo do comentário) foram seguidas à risca porque estão escritas literalmente no agente.
- Eval 3 — o artefato levou a uma recusa mais rigorosa e melhor fundamentada: o baseline (`without_skill`) reconheceu a política de zero tolerância mas ofereceu como "Recomendação 1" formalizar uma exceção no `.trivyignore` para os três CVEs — o que a própria regra citada (zero tolerance, "não importa a severidade") não permite; o `with_skill` seguiu a `docker-image-security.md` referenciada pelo artefato e tratou a única saída válida como waiver formal em `.security-waivers.yml` para CVE *sem* fix, recomendando rebuild como caminho principal — coerente com a política, sem abrir uma porta de exceção indevida.

**Atrapalhou / não ajudou:**
- Eval 1, asserção de smoke+Kyverno+rollback: mesmo com o artefato, o runbook gerado reproduziu um **bug do próprio artefato** (Fase 5): a seleção do pod arm64 filtra por `.spec.nodeSelector.kubernetes\.io/arch`, que normalmente vem vazio quando o pod não tem `nodeSelector` explícito no spec (a arquitetura real mora no *label do node*, não no `nodeSelector` do pod) — o runbook reconheceu esse ponto cego mas não corrigiu, e a saída do `jsonpath` nunca foi atribuída a `$ARM64_POD` (seleção inefetiva). Além disso, a instrução de `helm rollback` em caso de `PolicyViolation` (presente na Fase 7 do artefato) não apareceu no runbook gerado — ver §4, é um problema de como essa instrução está posicionada no artefato, não de o modelo tê-la ignorado por displicência.
- Eval 2, asserção do warning no tracker: o artefato bundla, na mesma Fase 9, "Adicione bloco no tracker" com "Commit + push para main", e a Fase 10 pede "registre warning no tracker" sem dizer que isso é independente de git. O executor `with_skill` leu essas duas fases como uma unidade proibida em dry-run ("não alterei PROGRESS-TRACKING.md real ... já que commit/push estão vedados nesta sessão") e por isso não escreveu — nem no arquivo real, nem simulado em `outputs/` — o conteúdo do warning que a asserção pedia. Resultado: a única asserção que o `with_skill` perdeu no eval 2 foi causada por ambiguidade textual do artefato, não por falta de capacidade do modelo (o baseline também não escreveu, pelo mesmo motivo, então essa asserção falhou nas duas condições — não discrimina, mas revela o mesmo furo nos dois casos).

## 4. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

1. **Sem noção de "modo dry-run".** O artefato inteiro (Fases 0-11) é escrito assumindo execução ao vivo contra cluster/GHCR/Jira reais. Nenhuma seção diz o que fazer quando a tarefa pede dry-run (como em todos os 3 evals aqui). Isso força cada execução a inferir, por conta própria, onde a linha entre "não rode isto" (git push, helm, kubectl, MCP) e "ainda descreva/simule isto por escrito" (o warning da Fase 10, o bloco da Fase 9) — e a inferência variou entre os runs. Causou a única falha discriminante perdida em cada eval operacional. **Recomendação concreta**: acrescentar uma seção curta "Modo dry-run" logo após "Sua Missão" dizendo explicitamente: em dry-run, nenhum comando de rede/estado externo é executado, mas toda decisão que o pipeline tomaria — inclusive conteúdo de warnings, comentários de Jira e blocos de tracker — deve ser escrita em `outputs/` como se fosse aplicada.
2. **Bug real na seleção de pod arm64 (Fase 5).** O filtro `.spec.nodeSelector.kubernetes\.io/arch` só funciona se o pod tiver `nodeSelector` explícito — não é isso que indica a arquitetura real do node onde ele roda. **Correção sugerida**: resolver por `kubectl get pod ... -o jsonpath='{.spec.nodeName}'` e então `kubectl get node <nome> -o jsonpath='{.metadata.labels.kubernetes\.io/arch}'`, iterando os pods do label selector até achar um com `arch=arm64`, e atribuindo o resultado à variável antes de checar `-n "$ARM64_POD"`.
3. **Instrução de rollback (Fase 7) posicionada como nota solta, fora do bloco de comando principal.** "Se houver `PolicyViolation` recente ... faça rollback" vem depois do bloco bash de verificação, como texto corrido, sem virar parte do script executável da fase. Nos dois runs `with_skill` que chegaram até essa fase (eval 1), o comando de rollback não apareceu no runbook final. **Recomendação**: mover o `helm rollback` para dentro do mesmo bloco de código da Fase 7, como um `if`, igual ao padrão usado nas Fases 0, 4 e 6 (`[ $EXIT -eq 0 ] || { ...; exit 1; }`).
4. **Fase 9 mistura duas responsabilidades diferentes** (editar arquivo de documentação vs. `git commit`/`git push`) numa única instrução de duas linhas. Em ambientes de eval/dry-run isso levou a descartar a edição do arquivo junto com o `git push`, quando só o segundo deveria ser vedado. **Recomendação**: separar em dois passos numerados — "9a. Atualize o bloco Deploy log" e "9b. Commit + push (pule esta etapa em dry-run, mas mostre o diff pretendido)".
5. Nenhum desperdício de tempo relevante identificado — as fases são enxutas e o artefato não tem passos supérfluos ou redundantes que os transcripts tenham reclamado de ter seguido à toa.

## 5. Melhorias concretas priorizadas

1. **[Alta] Adicionar seção "Modo dry-run"** definindo o que sempre deve ser escrito em `outputs/`/tracker mesmo sem executar comandos externos — corrige a única falha compartilhada pelas duas condições e a mais provável de se repetir em produção real (ex.: dry-run de operador antes de aprovar um deploy prd).
2. **[Alta] Corrigir o script de seleção de pod arm64 na Fase 5** — é um bug funcional real do artefato (não hipótese de eval), que hoje produziria `ARM64_POD` vazio em qualquer cluster onde os pods não tenham `nodeSelector` explícito, abortando o Fase 5 mesmo com deploy saudável.
3. **[Média] Embutir o `helm rollback` da Fase 7 como bloco de código condicional**, não como nota em prosa depois do script — reduz a chance de a instrução ser lida e não executada.
4. **[Média] Separar Fase 9 em edição de arquivo vs. commit/push** — mesma lógica do item 1, aplicada ao ponto específico onde o ambíguo já se materializou nos dados.
5. **[Baixa] Instrumentar tokens em `timing.json`** (hoje sempre 0/0) — não impacta a nota deste artefato, mas empobrece a leitura de custo/benefício do benchmark; é um ponto do harness de eval, não do agent em si.

## 6. Qualidade dos próprios casos de teste (`eval_quality`)

- **Cobertura de cenário é boa**: os 3 evals exercitam ramos distintos e relevantes do agente — deploy padrão em `stg` (Fase 0-9, sem Jira), deploy em `prd` com sincronização Jira (Fase 0, 1, 10 sob o ramo `prd`), e o gate de segurança que deve *recusar* o deploy antes de qualquer ação (Fase 3.1 como bloqueio hard). Isso testa o agente nos três caminhos de decisão mais importantes do seu próprio texto ("Anti-Patterns que Você Bloqueia").
- **Asserções são compostas demais** (cada uma embute de 2 a 5 verificações independentes numa única frase — ex.: a asserção 4 do eval 1 junta seleção de pod arm64, smoke em dois lugares, dois `clusterpolicy` e rollback). Isso é bom para narrativa, mas empobrece o sinal: um runbook com 4 de 5 sub-checagens corretas ainda marca a asserção inteira como `false`, escondendo qual fração específica falhou (o grading.json documentou isso bem via `evidence`, mas o `pass_rate` agregado por eval perde granularidade). Recomendação: dividir asserções compostas em unidades atômicas em revisões futuras do eval.
- **Amostra de 1 execução por (eval, config)** — não há repetição (`run-1` único em cada uma), então o `stddev` no `run_summary` mistura variância entre evals diferentes, não variância de execução repetida do mesmo cenário. O campo `runs_per_configuration: 3` no `benchmark.json` está **incorreto/confuso**: são 3 *evals*, não 3 *runs* por config — não há como hoje distinguir "o artefato é consistentemente bom" de "essa execução específica saiu bem". Recomendação: rodar pelo menos 2-3 runs por (eval, config) antes de tratar este delta como definitivo, e corrigir a metadata do agregador para não confundir contagem de evals com contagem de runs.
- **Grading com evidência textual (`evidence`) de alta qualidade** — todas as 33 avaliações de asserção citam linha, comando `grep`/`git` e trecho literal, o que tornou esta análise verificável sem precisar reexecutar nada. Isso é o ponto mais forte deste conjunto de dados.

## Notas de execução desta análise

- `aggregate_benchmark.py` rodou de primeira, sem ajuste de estrutura — `benchmark_ok = true`.
- `generate_review.py` gerou `review.html` estático de primeira, sem erro.
- Nenhum despacho de subagente foi necessário registrar: o próprio artefato `deploy-orchestrator.md` não instrui, em nenhuma fase, o disparo de subagentes (confirmado nos 6 transcripts, que fazem a mesma observação de forma independente) — não há "despacho que faria" a simular aqui.
