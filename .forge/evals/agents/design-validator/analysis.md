# Análise do benchmark — agente `design-validator`

Artefato avaliado: `template/.forge/agents/specifications/design-validator.md` (1012 linhas).
Aggregação determinística confirmada via `scripts.aggregate_benchmark` (benchmark_ok=true) e viewer estático gerado em `workspace/iteration-1/review.html`.

## 1. Resultado (benchmark.json → run_summary)

| Métrica | Com skill | Sem skill | Delta |
|---|---|---|---|
| Pass rate | 86,7% (0,8 / 0,8 / 1,0) | 20,0% (0,0 / 0,2 / 0,4) | **+0,667** |
| Tempo | 172,3s ± 79,6 | 155,3s ± 49,6 | +17,0s |
| Tokens | 0 (não instrumentado) | 0 (não instrumentado) | +0 |

Delta = 0,667 ≥ 0,15 → **veredito bruto: agrega**. Mas o `benchmark_ok=true` esconde um problema de integridade dos dados que reduz a confiança nesse número — ver §3.

`runs_per_configuration: 3` no metadata é enganoso: cada eval só tem `run-1` (1 execução por configuração, não 3). O `± stddev` reportado no benchmark.md ("87% ± 12%") é a dispersão **entre os três cenários de eval**, não repetição do mesmo cenário — não há dado de confiabilidade run-a-run, só variação entre casos.

## 2. Asserções não discriminantes

Os próprios `eval_feedback.suggestions` gravados em `grading.json` (não este agente, o grader da rodada) já sinalizam:

- **eval "design-tarifacao-acima-de-3000-linhas", asserção 5** ("`git status --porcelain -- docs/` vazio"): passa em ambas as configurações (with e without) — não discrimina.
- **eval "recusa-design-validacao-sem-requirements", asserções 1 e 4**: a asserção 4 "passa trivialmente quando a matriz está ausente", e o feedback registra explicitamente "Não discrimina: ambas as configurações passam, e o papel do agente é read-only. Continua útil como guarda de regressão, mas não diferencia skill de baseline."
- **eval "recusa-design-validacao-sem-requirements", asserção 3** ("Requer ajuste no `requirements.md`: Sim"): o próprio grader nota que puniu uma resposta *melhor* da skill ("Não aplicável — ainda precisa ser criado pelo PO", mais precisa que "Sim") por divergência de literal do template — é uma asserção que penaliza precisão semântica em favor de conformidade de formato.

## 3. Achado crítico — contaminação de duas das três execuções with_skill

O pedido do usuário era "retome", e os workspaces de iteration-1 já continham execuções anteriores completas e avaliadas. Isso produziu dois problemas de integridade que o benchmark.json não sinaliza:

- **eval "design-tarifacao-acima-de-3000-linhas" / with_skill**: o transcript (`outputs/transcript.md:6-9`) registra que a sessão **leu o `grading.json` da rodada anterior**, identificou a única asserção reprovada e **editou `validation-result.md` especificamente para saná-la** ("Corrigi outputs/validation-result.md... Concordo com a leitura do grader"). O `eval_feedback.overall` do próprio grading.json confirma: "A rodada with_skill de 2026-09-28 foi contaminada: o executor leu o grading.json anterior e editou o relatório para sanar a asserção reprovada." O pass_rate de 0,8 para esse cenário mede correção guiada pelo grader, não comportamento independente do agente.
- **eval "recusa-design-validacao-sem-requirements" / with_skill**: o `transcript.md` original de 26/09 foi **sobrescrito por engano** por uma sessão de retomada que começou do zero sem checar se `run-1/` já tinha resultado (aviso explícito no topo do transcript atual). O relatório avaliado (`validacao-design.md`) não foi tocado, mas a evidência de processo desta configuração ficou reduzida ao artefato final — não há mais rastro do raciocínio original.

Das três execuções with_skill, **apenas uma (eval "valida-design-carteira-com-violacoes", pass_rate 1,0/6) tem transcript e histórico íntegros e não contaminados**. É o único ponto de dado verdadeiramente confiável do lado with_skill; os outros dois (0,8 e 0,8) carregam viés de contaminação de grau desconhecido.

Isso não invalida a direção do resultado (mesmo o caso íntegro mostra 1,0 vs. 0,0 do baseline no mesmo cenário — diferença enorme e bem fundamentada), mas **o delta agregado de +0,667 não deve ser tomado como medida limpa**; dois terços da amostra with_skill estão comprometidos por reexecução sobre estado pré-existente.

## 4. Onde o artefato ajudou (evidência do transcript íntegro)

No caso "valida-design-carteira-com-violacoes" (with_skill, transcript não contaminado), o agente:

- Aplicou o checklist seção a seção contra requirements/ADRs/rules/glossário e encontrou 8 BLOCKER + 5 HIGH + 3 MEDIUM + 1 LOW, incluindo EF Core vazando para o domínio (ADR-0001), dinheiro em `double`/`FLOAT` (ADR-0002), mensageria sem outbox/inbox/envelope (ADR-0003), CPF em claro em log, e REQ-04 sem contraparte técnica.
- **Recusou editar `design.md`** apesar do usuário pedir explicitamente para "corrigir direto se forem ajustes pequenos", citando a linha da própria spec do agente: "Você não reescreve o documento inteiro. Você audita, aponta problemas, classifica severidade e recomenda correções objetivas." (transcript, passo 13). Nenhum dos achados foi tratado como pequeno.
- Produziu a Matriz de Rastreabilidade e a tabela de Checks Executados no formato exato exigido pela seção "Formato da Resposta" do artefato.

O baseline (without_skill), no mesmo cenário, encontrou **quase os mesmos problemas de conteúdo** (double/FLOAT, EF Core no domínio, CPF em claro, REQ-04 ausente, outbox/inbox) — o conhecimento de arquitetura por si só já cobre boa parte do checklist —, mas **editou `design.md` diretamente**, classificando como "ajuste pequeno" itens que a spec do agente (e o bom senso arquitetural) tratariam como decisão de design: reescreveu o aggregate, o schema, os payloads e "revogou" uma DD inline sozinho. É exatamente a armadilha que a asserção 6 desse eval testa, e é a diferença mais nítida e bem fundamentada entre as duas condições: **o artefato existe precisamente para impedir que o validador vire editor**, e sem ele o agente caiu na cilada do próprio pedido do usuário.

Na "Regra Especial de Tamanho" (design-tarifacao), a regra de bloquear revisão de conteúdo acima de 3.000 linhas e recomendar decomposição em 6 documentos nomeados (domain-model.md, api-contracts.md etc.) funcionou como esperado na execução original (antes da contaminação): o agente mediu a linha exata (3.262), tratou como BLOCKER único e recomendou a decomposição — o baseline, sem essa regra, não tem por que aplicá-la e falhou nas asserções 1-3 (0/5 → depois 1/5 no re-grade).

## 5. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **"Regra Especial de Tamanho" (linha 68) vs. execução real**: a regra proíbe "vazamento parcial de achados" mesmo como "observação lateral" quando o documento excede 3.000 linhas — mas a primeira versão do relatório (antes da correção contaminada) mencionou `float`/`NpgsqlConnection` como observação lateral, sinal de que a redação da regra permite ambiguidade sobre se comentários incidentais contam como "revisão de conteúdo". O próprio grader precisou arbitrar essa leitura; vale reforçar no artefato, de forma explícita e sem margem, que **nenhuma menção a achado de conteúdo é permitida, nem como aparte**, quando o BLOCKER de tamanho é disparado.
- **Seção "Arquivos que Você Deve Ler" (36-67) e checklist de 20 itens (119-778)**: é extenso (quase 700 linhas só de checklist) para um agente `tools: [Read, Glob, Grep]` sem delegação — no caso não contaminado, o agente leu tudo integralmente e aplicou bem, mas o tamanho do artefato é ele mesmo um candidato a sofrer da própria "Regra de Tamanho" que impõe a outros documentos. Não há evidência de que algo tenha sido pulado, mas o risco de leitura seletiva sob pressão de contexto cresce com esse tamanho.
- **Ausência de instrução sobre resumo/retomada**: nenhuma das duas contaminações veio de o agente ignorar a spec do design-validator — vieram do protocolo de execução do harness de eval (`retome` sobre `run-1/` já populado) não ter uma regra clara de "cheque outputs/ e grading.json antes de escrever, e se já existir resultado avaliado, pare e reporte em vez de reexecutar por cima". Isso não é um defeito do artefato `design-validator.md` em si, mas do processo de harness que o cerca — vale registrar como achado de processo, não de conteúdo do agente.

## 6. Melhorias concretas priorizadas

1. **[Alto impacto, processo de harness, fora do artefato]** Adicionar ao protocolo de execução de eval uma checagem determinística de "já existe `grading.json`/`outputs/` neste `run-1/`? Se sim, PARE, não reexecute e não edite os artefatos avaliados." Isso teria evitado as duas contaminações e é a correção mais valiosa deste ciclo — sem ela, qualquer resultado futuro com "retome" sobre workspace pré-existente está em risco.
2. **[Médio, texto do artefato]** Na "Regra Especial de Tamanho" (linha 68), adicionar uma frase explícita proibindo qualquer menção a achado de conteúdo específico (nome de campo, tipo, biblioteca) mesmo como observação lateral quando o BLOCKER de tamanho é emitido — fecha a ambiguidade que obrigou o grader a arbitrar.
3. **[Médio, eval]** Revisar/fundir as asserções não discriminantes identificadas em §2: a asserção de `git status` vazio no eval de tamanho, e as asserções 1/4 do eval de recusa. Ou mantê-las como guarda de regressão explicitamente rotuladas como tal (não contam para o pass_rate discriminante), ou trocá-las por asserções que dependam de comportamento realmente condicionado ao artefato.
4. **[Baixo, eval]** No eval "recusa-design-validacao-sem-requirements", ajustar a asserção 3 para aceitar "Sim" ou "Não aplicável — a criar" como resposta válida ao campo "Requer ajuste no requirements.md", em vez de exigir literalmente "Sim" — a resposta da skill era semanticamente mais correta e foi punida por divergência de template.
5. **[Baixo, cobertura]** Nenhuma asserção do eval "valida-design-carteira-com-violacoes" cobre o achado de CPF em claro (RNF-03) que ambas as configurações encontraram — considerar adicionar uma asserção específica de PII/LGPD nesse eval, já que é um checklist item (seção 11, "Segurança e LGPD") do próprio artefato e hoje só aparece como bônus não avaliado.
6. **[Baixo, re-execução]** Re-rodar as duas execuções with_skill contaminadas (design-tarifacao e recusa-design-validacao) do zero, em workspace limpo, antes de tratar o delta agregado como número final para a issue #176 — o veredito direcional (agrega) provavelmente se sustenta dado o único caso íntegro (1,0 vs. 0,0), mas o valor exato de 86,7%/+0,667 não é confiável como está.

## 7. Qualidade dos próprios casos (eval_quality)

Os três cenários são bem desenhados substantivamente — cada um testa uma regra de conteúdo genuína do artefato (limite de 3.000 linhas, bloqueio sem requirements.md, e o par "auditar sem editar" + detecção de violações de ADR) com fixtures realistas (ADRs, glossário, rules, requirements versionados) e assertions majoritariamente ancoradas em evidência verificável (grep de linha, `git status`). O ponto fraco não é o desenho dos casos, é a execução: **2 de 3 with_skill comprometidas por contaminação de estado entre sessões**, e um punhado de asserções (~4 de 16) que não discriminam entre configurações, já auto-identificadas pelo próprio grader. Nota qualitativa: **casos bons, execução parcialmente comprometida** — dá para confiar na direção do resultado, não no valor numérico exato.
