# Análise do benchmark — agente `tasks-validator`

Fonte: `.forge/evals/agents/tasks-validator/workspace/iteration-1/benchmark.json` (gerado deterministicamente por `aggregate_benchmark`, sem falha na primeira tentativa).

## 1. Resultado (taxas e delta)

| Configuração | pass_rate médio | min | max | tempo médio (s) |
|---|---|---|---|---|
| Com skill (agente carregado) | **94,33%** (0,9433) | 0,83 | 1,00 | 148,0 |
| Sem skill (baseline) | **13,33%** (0,1333) | 0,00 | 0,20 | 155,7 |

Delta = 0,9433 − 0,1333 = **+0,81**. Veredito: **agrega** (delta ≥ 0,15, com folga larga). `benchmark_ok = true` — o script rodou sem erro na primeira tentativa, gerando `benchmark.json` e `benchmark.md`.

## 2. Asserções não discriminantes

Duas asserções passaram em ambas as configurações e por isso discriminam pouco o valor do artefato nesta amostra:

- **Eval 2 (3000+ linhas), asserção 5** ("`git status --porcelain -- docs/` vazio, plano não foi decomposto de fato") — passou com e sem skill, porque nenhum dos dois agentes tentou executar a decomposição fisicamente; ambos só recomendaram por texto. Testa disciplina de "não agir", não o conteúdo do parecer.
- **Eval 3 (recusa por falta de design), asserção 5** ("resposta não propõe design técnico novo") — passou nas duas configurações. O agente sem skill também evitou fabricar `design.md` (por raciocínio próprio, citando o princípio 12 da constituição do fixture), então essa asserção não isola o efeito do artefato.

Todas as demais 13 asserções (de 16 distintas) discriminam fortemente: passam quase sempre com skill e falham quase sempre sem skill.

## 3. Onde o artefato ajudou (evidência do transcript/outputs)

- **Regra Especial de Tamanho (eval 2, 3966 linhas):** com skill, o agente aplicou a regra ao pé da letra — parou a revisão de conteúdo, emitiu só `[BLOCKER-01] tasks.md excede 3.000 linhas`, preencheu a tabela "Checks Executados" com a linha de tamanho como `Falhou` e todo o resto `Não verificado`, e recomendou a decomposição em `wave-01-bootstrap.md` … `wave-06-hardening.md` citando o padrão exato do artefato (seção "Regra Especial de Tamanho"). Sem skill, o agente ignorou o corte e fez "pente-fino" completo TASK a TASK (achados `### 4.`, `### 5.` sobre PBT-01/RNF-1, contradizendo a regra que nem conhecia) — pass_rate caiu de 1,00 para 0,20.
- **Bloqueio por ausência de `design.md` (eval 3):** com skill, o agente citou textualmente a regra "Se `requirements.md` ou `design.md` não existirem, registre bloqueio crítico" (seção "Arquivos que Você Deve Ler"), reprovou apesar da pressão do usuário por aprovação e não editou nenhum arquivo. Sem skill, o agente **editou o `tasks.md` e o `README.md`** (bump de versão 0.1.0→0.2.0, subtasks 2.5/2.6 novas) e escreveu "Status: Validado contra requirements.md; não aprovado para desenvolvimento integral" — uma aprovação parcial que a asserção conta como reprovação do critério "não emitir Aprovado nem Aprovado com ressalvas". A regra explícita do artefato ("Você não reescreve o documento... Você audita") é o que impediu a escrita em `docs/` nas execuções com skill.
- **Formato de saída fixo (eval 1):** só as execuções com skill reproduziram o template exigido (`# Validação do tasks.md`, `## Resultado` com `Status: Reprovado` e as 4 contagens, `## Veredito`, `## Achados`, `## Matriz de Rastreabilidade`, `## Checks Executados`, `## Recomendações para o tasks-writer`, `## Decisão para o Pipeline`, nesta ordem). Sem skill, cada execução inventou sua própria estrutura de títulos (`## Bloqueadores`, `## Lacunas de rastreabilidade`, `## Verificado e conforme`), sem seção "Decisão para o Pipeline" nem contagem por severidade.

## 4. Onde o artefato atrapalhou ou não bastou

- **Único caso de falha entre as 3 execuções com skill (eval 1, asserção 5):** a orientação de "push direto em `main`" na TASK-05 foi classificada como `[HIGH-01]`, mas o próprio artefato lista literalmente **"Orientação de push direto na branch principal"** como exemplo de **BLOCKER** (seção "Severidade dos Achados › BLOCKER"). O agente colocou o achado corretamente no conteúdo, mas com a severidade errada — e essa inconsistência interna aparece no próprio relatório: o "Veredito" (linha 15) conta o push entre os "cinco achados BLOCKER", mas na lista de achados ele está rotulado HIGH. Isso não é um erro de leitura isolado: a seção 10 ("Branch, Worktree e Commits") tem sua própria lista `Bloqueie:` com "Push direto para branch principal" ao lado de itens que a seção "Severidade" classifica como HIGH ("Branch fora do padrão", "Worktree divergente" — ambos vizinhos textuais na seção 10). O artefato **não repete a tag de severidade dentro de cada seção de checklist** (1 a 17); só a seção "Severidade dos Achados", isolada no fim do documento, faz essa amarração — o que facilita a analogia errada entre "push direto" e os itens HIGH vizinhos na seção 10.

## 5. Trechos ignorados, ambíguos ou contraditórios do artefato

- **Ambíguo, causou o único erro observado:** a seção 10 lista "Push direto para branch principal" em `Bloqueie:` sem dizer que é BLOCKER (todas as 17 seções de checklist usam `Bloqueie:` genérico, sem apontar para a tabela de severidade); a amarração correta só existe uma vez, na seção "Severidade dos Achados", ~500 linhas depois.
- **Redundante, mas inofensivo:** `docs/product/adr/` aparece duplicado nas "Fontes de arquitetura" (linhas 52-53 do artefato, citado duas vezes seguidas). Não gerou erro observável nos transcripts, mas é ruído a limpar.
- **Não exercido por nenhum dos 3 casos:** seções 12 (Coverage Gates), 14 (Segurança/Observabilidade), 15 (API/Eventos/Erros), 16 (Encerramento) e 17 (README) do checklist de 17 itens não têm fixture dedicado que force um defeito plantado nelas isoladamente — os 3 casos testam principalmente rastreabilidade (Req/RNF/PBT sem TASK), Status Geral, ciclo de dependência, TDD-first, branch/push e a regra de tamanho. Boa parte do artefato (por exemplo toda a seção 17, README do módulo) fica sem cobertura de asserção.

## 6. Melhorias concretas priorizadas

1. **Alta prioridade — corrigir a ambiguidade de severidade que causou a única falha.** Na seção 10 ("Branch, Worktree e Commits"), trocar a linha genérica `Bloqueie: ... Push direto para branch principal` por algo como: `Bloqueie (severidade BLOCKER, nunca HIGH): Push direto para branch principal`, e nas demais linhas dessa mesma lista (`Branch fora do padrão`, `Worktree divergente`) marcar explicitamente `(severidade HIGH)`. Isso remove a necessidade de o agente saltar para a seção "Severidade dos Achados" (500 linhas depois) para resolver a ambiguidade, e ataca diretamente a causa do único achado mal classificado nas 3 execuções com skill.
2. **Média prioridade — não mexer no que já funciona a 100%.** A "Regra Especial de Tamanho" e o bloqueio por `design.md` ausente tiveram 3/3 de acerto total nas asserções relacionadas; nenhuma mudança de texto é recomendada nessas duas seções.
3. **Média prioridade — remover a duplicação de `docs/product/adr/`** nas "Fontes de arquitetura" (linhas 52-53), fusão trivial que não muda comportamento mas reduz ruído de leitura em um artefato já com 852 linhas.
4. **Baixa prioridade — cobertura de eval.** Considerar um 4º caso de teste que force um defeito isolado nas seções 12/14/15/16/17 (por exemplo, coverage gate ausente para a camada Security, ou README do módulo desatualizado), hoje sem nenhuma asserção dedicada — não é um problema do artefato, mas uma lacuna do conjunto de casos.

## 7. Qualidade dos próprios casos (`eval_quality`)

- Os 3 casos cobrem mecanismos distintos e bem escolhidos do artefato: violações de conteúdo/rastreabilidade (eval 1), o gate de tamanho de 3.000 linhas (eval 2) e o bloqueio por ausência de fonte (`design.md`, eval 3) sob pressão explícita do usuário para aprovar mesmo assim — esse último é o teste mais valioso, porque avalia resistência a instrução conflitante do usuário, não só conhecimento do checklist.
- As asserções são conjuntivas (várias condições unidas por "E" numa única asserção), o que é coerente com a exigência de formato rígido do artefato, mas reduz granularidade diagnóstica: a única falha real (severidade do push direto) aparece dentro de uma asserção que também testa duas outras coisas que passaram, então o "1 de 6 falhou" do eval 1 mistura um erro pontual de severidade com asserções mais amplas.
- **Limitação do benchmark em si (não do artefato):** o `eval_metadata.json`/`benchmark.json` declara `runs_per_configuration: 3`, mas em disco existe apenas `run-1/` para cada combinação eval×config — ou seja, o desvio-padrão relatado (`stddev` em `run_summary`) reflete variância **entre os 3 casos diferentes**, não repetições do mesmo caso. Isso é válido para o veredito agregado (que é sobre o artefato como um todo), mas não deve ser lido como "ruído de execução"; para medir estabilidade de uma execução específica seria preciso rodar o mesmo eval mais de uma vez, o que não ocorreu aqui.
- Os campos `executor_model` e `analyzer_model` em `benchmark.json` ficaram com o placeholder literal `<model-name>` — não preenchidos pela pipeline que gerou os dados brutos, o que impede rastrear qual modelo executou os agentes nesta rodada.

## 8. Retorno numérico (para o orquestrador)

- `with_pass_rate` = 0,9433
- `without_pass_rate` = 0,1333
- `delta` = +0,81
- `benchmark_ok` = true
- `veredito` = agrega
