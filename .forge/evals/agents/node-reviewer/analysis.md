# Análise de benchmark — agente `node-reviewer`

Artefato avaliado: `template/.forge/agents/code-review/node-reviewer.md`. Agregação determinística via `scripts.aggregate_benchmark` (`benchmark.json`/`benchmark.md` em `workspace/iteration-1/`), viewer estático em `workspace/iteration-1/review.html`. `benchmark_ok = true` — o script rodou de primeira, sem precisar corrigir estrutura de diretórios/JSON.

## Resultado (run_summary do benchmark.json)

Com artefato: pass_rate média 1.00 (3/3 evals em 100%, stddev 0). Sem artefato: pass_rate média 0.3067 (eval 3 em 0.75, eval 1 em 0.17, eval 2 em 0.0; stddev 0.3932). Delta = 1.00 − 0.3067 = **+0.69**. Tempo: com artefato 485,7 s em média contra 453,7 s sem artefato (+32 s, +7%) — custo de tempo pequeno frente ao ganho de acerto. Tokens/tool_calls não instrumentados nesta corrida (todos zerados no benchmark.json).

Ressalva sobre a corrida: `eval_metadata`/`benchmark.json` registram `runs_per_configuration: 3`, mas só existe `run-1` em cada configuração (sem `run-2`/`run-3`). O delta é real e a diferença é grande demais para ser ruído de amostra única, mas o desvio-padrão reportado (0 para with_skill) é artefato de n=1, não evidência de estabilidade — antes de arquivar o veredito eu rodaria as réplicas que faltam.

Veredito: delta ≥ 0.15 → **agrega**.

## Asserções não discriminantes

- Eval 3 (recusa de autorrevisão), asserção 3 ("não contém aprovação de merge") e asserção 4 (`git status --porcelain -- src/` vazio): passam em ambas as configurações. Testam que nenhuma configuração inventou uma aprovação ou tocou código-fonte — não isolam o valor do artefato.
- Eval 1, asserção 3 (finding de `Promise<any>` em `repository.ts:6`): passa em ambas. É um julgamento de tipo óbvio o bastante para o modelo acertar sem o artefato.

Todas as demais 15 asserções (de 20 no total) discriminam: passam com o artefato e falham sem ele.

## Onde o artefato ajudou (evidência de transcript)

1. **Ordem determinístico-antes-de-julgamento.** Na eval 1 (sem baseline de lint), o transcript com artefato mostra os passos 11–14 rodando `node-baseline.sh --check` e `node-quality-scan/scripts/scan.sh` antes de qualquer achado manual, e citando `clean-code-rules.md` para decidir cada `FOUND`. Sem o artefato, o transcript (passos 9-14) nunca menciona os dois scripts — o modelo reviu o diff só de memória, sem baseline (`NODE-BASELINE` nunca aparece) e sem o scan (nenhuma FOUND/exceção citada).
2. **Contrato de schema explícito evita achado inutilizável.** O artefato exige `severity, file, line, title, description, fix_suggested` (linha 44). Sem o artefato, o modelo inventou seu próprio schema (`summary/detail/recommendation`, severidades `critical`/`info` fora do vocabulário) nas evals 1 e 2 — falha determinada por `jq` em `grading.json`: "0 de 9 [findings] usa summary/detail/recommendation" (eval 1) e "severity 'info', não MEDIUM" (eval 2). Isso não é falta de capacidade do modelo, é ausência do contrato — o mesmo modelo, com o artefato, produziu os campos certos nas três evals.
3. **Regra explícita do max-lines-como-error vira o eval inteiro.** A linha 21 ("`forge-quality/max-lines` declarada `error`... trate como `MEDIUM`, não `HIGH`") é citada quase literalmente pela evidência de grading do with_skill na eval 2 e é exatamente o que falha sem o artefato (severity `info`, sem menção a "warn"). Eval 2 sem artefato foi 0/5 — o artefato decide o resultado inteiro deste caso.
4. **"Sessão Limpa" é a única coisa que produz a recusa esperada.** Eval 3: com artefato, o transcript (passos 5, 8) cita a seção "Sessão Limpa" do próprio arquivo e recusa gravar veredito de merge. Sem artefato, o transcript diz textualmente (passo "Decisão"/linha final) "cumpri o pedido de revisão" e escreve `review/estorno.md` com a autorrevisão feita — grading confirma: falha na única asserção que testa a recusa. Sem o texto do artefato o modelo não tem por que inferir essa regra sozinho; ela é convenção do harness, não senso comum de code review.
5. **Lista fechada das 11 regras do scan vira checklist auditável.** O formato exigido ("toda regra do scan recebe uma linha... inclusive as que não acharam nada") produziu, com artefato, a tabela completa nas evals 1 e 2 (grading: `grep -c` bate 1 para cada uma das 11 regras). Sem artefato, zero menções às 11 regras nas duas evals — o modelo nem sabe que existem 11 regras nomeadas, porque não rodou o scanner.

## Onde o artefato atrapalhou ou não fez diferença

Nenhuma evidência de regressão: nas 20 asserções, nenhuma passa sem o artefato e falha com ele. O único custo mensurável é tempo (+32s médios, dentro do ruído dado n=1) — decorrente de rodar as duas camadas determinísticas e ler `clean-code-rules.md`, que é exatamente o trabalho que o artefato pede para produzir os achados corretos.

## Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

1. **Vocabulário de severidade nunca é definido no próprio artefato — só citado em dois exemplos soltos.** O texto usa `HIGH` (linha 21, baseline) e `MEDIUM` (linha 21, max-lines-error) como se o vocabulário completo (existe `BLOCKER`? existe `LOW`?) fosse óbvio. A taxonomia real (`BLOCKER > HIGH > MEDIUM > LOW`, com a regra "invoca fullstack-software-engineer se houver BLOCKER ou HIGH") vive em `template/.forge/agents/review/code-evaluator.md` (linhas 181, 189, 276-314), que é quem consome o output do `node-reviewer` — mas `node-reviewer.md` nunca aponta para esse arquivo. Nesta corrida o modelo com artefato acertou `BLOCKER` para SQL injection por conhecimento geral/consistência do repositório, não porque o artefato instruísse — é um acerto que não está garantido para todo executor. **Risco:** um modelo mais literal, seguindo só o que está escrito, teria só `HIGH`/`MEDIUM` como vocabulário conhecido e inventaria algo para SQL injection crítica.
2. **A referência a `rules/data/schema-evolution.md` (linha 36) nunca foi exercida como positiva nesta bateria.** Nas três evals o modelo checou o arquivo e concluiu "não aplicável" (eval 1, passo 14) — o comando existe mas nenhum eval força um caso onde ele decide algo. Não é falha do artefato, é lacuna de cobertura do benchmark (ver seção de qualidade dos casos).
3. **"Achado sem arquivo:linha não entra" (linha 42) é regra forte mas nunca testada diretamente** — nenhuma asserção verifica que um finding sem `line` foi descartado. Cobertura de linha, mas não da omissão que a regra proíbe.
4. **Nenhum apontamento de "onde fica o schema de findings do code-evaluator"** força o executor a inferir por proximidade de repositório (outros agentes de review) em vez de por instrução direta — isso é o mesmo problema do item 1, mas vale generalizar: o artefato assume que o executor vai olhar os arquivos-irmãos em `agents/review/`, mas nada no texto do `node-reviewer.md` diz "veja o contrato de severidade em `code-evaluator.md`".

## Melhorias concretas, priorizadas

1. **(Alto impacto, baixo custo) Definir a taxonomia de severidade no próprio artefato**, com uma frase curta apontando o contrato canônico: acrescentar após a linha 21 algo como "Severidade segue o vocabulário do `code-evaluator` (`BLOCKER > HIGH > MEDIUM > LOW`, ver `.forge/agents/review/code-evaluator.md`); use `BLOCKER` para o que bloqueia merge por si só (ex.: injeção de SQL, segredo vazado), `HIGH` para o que quase sempre bloqueia, `MEDIUM`/`LOW` para o resto." Isso fecha a lacuna do item 1 sem reescrever a seção.
2. **(Médio impacto, baixo custo) Adicionar ao "Formato do Relatório" um exemplo mínimo de finding válido** (um JSON de 1 objeto com os 6 campos preenchidos) — o texto já lista os nomes dos campos, mas um exemplo concreto reduz ainda mais a chance de um executor inventar `summary/detail/recommendation` como o without_skill fez; e serve de checagem visual rápida para quem lê o artefato.
3. **(Médio impacto, baixo custo) Tornar "Sessão Limpa" mais early/proeminente** — hoje é a penúltima seção do arquivo (linha 46), depois de todo o processo técnico. Como esta é a regra que mais distingue with/without nesta bateria (é a única cuja violação é comportamental, não técnica), mover para logo após o título reduziria o risco de um executor com contexto grande (janela cheia de diff) chegar lá tarde e já ter começado a "ajudar".
4. **(Baixo impacto, baixo custo) Adicionar ao final da seção 1 (baseline) um lembrete de rodar o scan mesmo quando o baseline reprova** — não há ambiguidade hoje (o texto já trata as duas camadas como sequenciais e independentes), mas nenhuma eval testa o caso onde o executor para no primeiro finding e não chega ao scan; vale um teste futuro, não uma mudança de texto agora.
5. **Não fundir nem remover nada** — o artefato é enxuto (51 linhas) e cada seção testada teve efeito mensurável; o ganho está em completar referências cruzadas, não em cortar conteúdo.

## Qualidade dos próprios casos (eval_quality)

Os três casos são bem desenhados para isolar o valor do artefato — cada um mira uma seção específica (camadas determinísticas + exceções documentadas na eval 1; a regra do max-lines-como-error na eval 2; "Sessão Limpa" na eval 3), com asserções verificáveis por `jq`/`grep`/`git status` em vez de julgamento subjetivo, o que faz o grading em si ser auditável (o `benchmark.json` desta corrida cita comando e saída para cada asserção). Os fixtures usam nomes de domínio do próprio negócio do usuário (Pix, tarifação, estorno) e incluem armadilhas propositais (exceções legítimas de `new-pg-client`/`sync-fs-blocking`, arquivo legado fora do diff, teste com asserção vazia) que só o artefato completo resolve — isso é o que torna 15 das 20 asserções discriminantes.

Pontos fracos do desenho dos casos:
- **n=1 por configuração nesta corrida**, apesar de `runs_per_configuration: 3` no metadata — falta rodar as réplicas 2 e 3 para confirmar que o 100%/30,7% não é sorte de uma única amostra (o efeito é grande, mas eval 3 sem artefato já mostrou 0,75 de pass rate, indicando que o comportamento sem artefato não é uniformemente ruim — mais réplicas mudariam a média).
- **Cobertura zero da seção "schema-evolution"** (linha 36) e da regra "achado sem `arquivo:linha` não entra" (linha 42) — nenhum dos três casos força uma migração de schema Postgres nem um finding sem linha para testar a rejeição.
- **Eval 3 mistura duas asserções de dificuldade muito diferente**: a recusa comportamental (difícil, é o que discrimina) e "não conter aprovação de merge"/"git status vazio" (fáceis, não discriminam — ver seção acima). Não invalida o caso, mas infla a pass rate parcial do without_skill (0,75) de um jeito que mascara que a asserção que importa falhou.
