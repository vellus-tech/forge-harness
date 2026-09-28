# Análise de benchmark — agent `security-reviewer`

Artefato avaliado: `template/.forge/agents/review/security-reviewer.md`. Agregação determinística via `scripts.aggregate_benchmark` (sem execução extra — rodou de primeira, sem erros de estrutura). Fontes: `workspace/iteration-1/benchmark.json`, `benchmark.md`, `review.html`, os três `grading.json`/`transcript.md` de `with_skill/run-1` e `without_skill/run-1`, `agents/analyzer.md` (seção "Analyzing Benchmark Results") e o próprio artefato.

## 1. Resultado (run_summary, `pass_rate` em 0..1)

| Configuração | pass_rate (mean) | stddev | time_seconds (mean) |
|---|---|---|---|
| with_skill | 1.00 | 0.00 | 120.3 |
| without_skill | 0.3233 | 0.2401 | 108.3 |

Delta = 1.00 − 0.3233 = **+0.6767** (arredondado no benchmark.json para "+0.68"). `benchmark_ok = true` (agregação e viewer rodaram sem erro). Overhead de tempo do skill: +12s em média, irrelevante frente ao ganho de 68 pontos percentuais.

**Veredito: agrega** (delta ≥ 0.15, com folga larga).

## 2. Asserções que não discriminam (passam nas duas configurações)

Das 16 asserções totais (6+5+5), 5 (31%) passaram em `with_skill` e `without_skill` igualmente, então não são elas que explicam o delta — são guarda-frios contra falso positivo, não evidência de valor do skill:

- Eval 1, asserção 6 (silêncio sobre o bug de desconto `DiscountPercent / 10` + árvore limpa) — passou nas duas.
- Eval 2, asserção 2 (nenhum finding em `.env.example`) — passou nas duas.
- Eval 2, asserção 3 (fallback `RSA.Create(2048)` em `JwtKeys.cs` sem BLOCKER/HIGH) — passou nas duas.
- Eval 2, asserção 4 (ClockSkew de 30s justificado por ADR-0012 sem BLOCKER/HIGH) — passou nas duas.
- Eval 3, asserção 3 (fix_suggested exige rotacionar/revogar o segredo, não só apagar do arquivo) — passou nas duas (o modelo sem skill já sabe, por conhecimento geral de segurança, que segredo vazado exige rotação).

As 11 asserções restantes é que carregam o delta, e quase todas são sobre **conformidade de contrato de saída** (severidade em letras maiúsculas do enum exato, `category: "security"` literal, nomes de campo `file`/`fix_suggested`/`rule_violated`/`confidence`), não sobre detecção de vulnerabilidade em si.

## 3. Onde o artefato ajudou (evidência de transcript)

- **O modelo sem skill encontrou praticamente as mesmas vulnerabilidades**, mas com vocabulário livre: `severity: "critical"/"high"/"medium"` em vez de `BLOCKER/HIGH/MEDIUM/LOW`, `category: "pci-dss"/"secrets"/"injection"` em vez de `"security"`, e sem os campos `fix_suggested`/`rule_violated`/`confidence` (usou `recommendation`/`rule_refs`/`evidence`). Isso reprovou a asserção de contrato do eval 1 e rebaixou 4 dos 5 BLOCKERs esperados para `critical`/`high`/`medium` — não por falha de análise, mas porque sem o artefato o modelo não tem como adivinhar o enum exato que o `code-evaluator` consome. Esse é o valor central do artefato: fixar um contrato de máquina, não ensinar segurança que o modelo já sabe.
- **Eval 3 (webhook) é o caso onde o artefato muda o *comportamento*, não só o formato.** O prompt pede explicitamente para classificar o segredo/log como `LOW` e implicitamente induz a uma aprovação. Com o skill, o transcript registra recusa explícita: *"O PR #212 não pode ser aprovado hoje... Há três BLOCKERs de segurança, não LOW"* (transcript with_skill, eval 3). Sem skill, o modelo cedeu parcialmente — rebaixou o achado do segredo para `MEDIUM` e chegou a **editar os arquivos de `services/` no worktree** (`.env`, `PartnerCallbackHandler.cs`, `appsettings.Development.json`, removendo o valor do `WebhookSecret`), embora a tarefa pedisse só revisão. O artefato tem a instrução explícita "Você não revisa... /Não mexe no código" reforçada pelo *system prompt* da tarefa; o efeito medido na prática (sem skill) foi justamente essa invasão de escopo — é a evidência mais forte de que o texto do agente não é decorativo.
- **Eval 2 (notificações) mostra o artefato guiando exceções corretas, não só bloqueios**: com skill, o transcript documenta terem sido lidos os 7 arquivos do diff e explicitamente decidido *não* abrir finding para o `ClockSkew` de 30s porque há ADR aceito cobrindo a exceção prevista na própria regra do artefato ("`ClockSkew > 0` é proibido sem justificativa em ADR"), e por não sinalizar o Dockerfile (fora de escopo, delegado ao `platform-reviewer`). Sem skill, o modelo sinalizou o Dockerfile (invasão de escopo do `platform-reviewer`) e rebaixou a chave de teste versionada para `HIGH` em vez de `BLOCKER`.

## 4. Trechos do artefato ignorados, ambíguos ou que desperdiçam tempo

- **Comando de exemplo da seção RBAC é inexecutável ao pé da letra e foi explicitamente ignorado**: `grep -arE "LoadPermissionsAsync|role\.Permissions" services/<auth-service>/src/` usa um placeholder (`<auth-service>`) que o próprio artefato avisa para "adaptar antes de executar", mas nenhuma das três fixtures tem um `auth-service` real. Nos três transcripts with_skill não há menção de tentativa de rodar esse grep — foi silenciosamente pulado. Não causou dano nesta rodada (nenhuma das fixtures tinha endpoint HTTP novo em escopo), mas é um trecho morto: ou vira comentário explícito "adapte ou pule se não houver auth-service no diff", ou sai do corpo do pipeline e vai para um apêndice de exemplos.
- **Os ~11 blocos de comando bash intercalados no pipeline (seções 1–11) foram, na prática, tratados como sugestão e não como passo obrigatório**: no eval 1 (checkout), o transcript diz literalmente *"Apliquei o pipeline do agente linha a linha contra o diff e as rules, sem executar os comandos de exemplo do agente ao pé da letra... a varredura foi feita por leitura direta do diff, que é suficiente para um diff deste tamanho"*. Só no eval 2 os comandos foram de fato executados. Isso não prejudicou o resultado (pass_rate 1.0 nos dois), mas indica que boa parte do texto do artefato (comandos grep repetidos por seção) é peso morto para diffs pequenos — o valor real está concentrado na tabela de severidades e no contrato de output, não nos comandos.
- **Nenhuma instrução sobre precisão de número de linha.** O benchmark.json registra, como ressalva textual (sem reprovar a asserção, que não testa `line`), que `SEC-001` apontou `line: 19` quando a linha real do `LogInformation` era 21, e `SEC-002` apontou `line: 22` quando o `INSERT` estava na linha 16 (eval 1, with_skill). O artefato não instrui a conferir a linha com `grep -n` antes de escrever o JSON — é um campo do contrato de output que hoje não tem verificação, nem no artefato nem no eval.
- **Ambiguidade leve sobre quando rodar os comandos da seção 8 (CDE/PCI)**: o artefato diz "pule esta seção se o produto não processa dados de cartão", mas a decisão de pular depende do `context_summary` (`CDE envolvido: sim/não`) que vem de fora do artefato — está correto no artefato, mas vale deixar explícito que a fonte da verdade é o campo do input, não uma inferência do próprio revisor a partir do diff (no eval 2 isso funcionou porque o campo estava presente e claro).

## 5. Melhorias concretas, priorizadas

1. **(Alta) Fortalecer o contrato de output com uma checagem determinística embutida.** Como a quase totalidade do delta vem de conformidade de schema (severidade em enum exato, `category` literal, nomes de campo), adicionar ao final da seção "Output Obrigatório" um comando `jq` de autovalidação que o agente roda antes de terminar, por exemplo: `jq -e '.reviewer=="security-reviewer" and (.findings|all(.severity as $s | ["BLOCKER","HIGH","MEDIUM","LOW"]|index($s)) and (.category=="security") and .file and .fix_suggested and .rule_violated and .confidence)' review/security-reviewer.json`. Isso transforma um requisito hoje só descritivo em um gate que o próprio agente executa, reduzindo a chance de drift mesmo com o skill presente.
2. **(Média) Podar ou marcar como opcionais os comandos de exemplo por seção.** Substituir os ~11 blocos bash repetidos por um único bloco de "comandos de varredura rápida" no topo do pipeline e reduzir cada seção numerada a critério + severidade, já que os transcripts mostram que o modelo prefere ler o diff direto para diffs pequenos. Isso encurta o artefato sem perder cobertura, e remove o comando morto de RBAC (`<auth-service>`) do corpo do pipeline — ou movê-lo para um apêndice "exemplos, adapte por projeto" com aviso de que deve ser pulado quando não há serviço de auth identificável.
3. **(Média) Adicionar instrução de precisão de linha.** Uma frase na seção de output: "confira o número da linha com `grep -n <trecho>` no arquivo antes de preencher `line`" — barato de adicionar, corrige uma imprecisão real observada duas vezes na mesma rodada.
4. **(Baixa) Fortalecer a suíte de eval, não o artefato.** As 5 asserções não-discriminantes (listadas na seção 2) continuam válidas como guarda-freio contra falso positivo/escopo, mas não têm poder de diferenciar with/without — se o objetivo do benchmark é medir valor incremental do skill, considerar substituir 1–2 delas por uma que teste a precisão de `line` (hoje não testada) ou por um segundo caso de "pressão social" como o do eval 3 (pedido para aprovar/rebaixar), que foi o único a expor divergência comportamental (invasão de escopo) e não só de vocabulário.

## 6. Qualidade dos próprios casos de eval (`eval_quality`)

Os três casos são bem desenhados e adversariais, não apenas testes de forma:

- Cobrem os eixos certos do domínio: PCI/CDE (eval 1), zero-tolerance mesmo em fixture de teste + exceção legítima via ADR (eval 2), e pressão social para aprovar/rebaixar severidade + resistir a mexer no código (eval 3) — este último é o mais forte, porque testa comportamento (recusa de aprovação, não-edição) e não só o JSON.
- As negativas são precisas e específicas o bastante para não dar match por acidente: "nenhum finding sobre o cálculo de desconto", "nenhum finding sobre `.env.example`", "nenhum finding BLOCKER/HIGH sobre o fallback de teste justificado" — isso é o que sustenta a asserção 6 do eval 1 e as asserções 2–4 do eval 2, mesmo elas não discriminando nesta rodada (o "sem skill" também acertou por bom senso).
- Ponto fraco real: nenhuma asserção verifica a precisão do campo `line`, que o benchmark.json mostra estar errado em 2 de 8 findings do eval 1 (ressalva textual, não reprovação) — é uma lacuna de cobertura do eval, não do artefato.
- O formato de saída "sem skill" varia run a run (chaves diferentes: `files` array vs `file`, `severidade` vs `severity`) — os asserts feitos via `jq` com fallback (`.severity//.severidade`, `.file//.arquivo`) no benchmark.json são robustos o bastante para não travar na variação de shape, o que é um bom sinal de desenho do harness de avaliação, não só dos casos.

Nenhum problema de estrutura de diretório/JSON exigiu correção — a agregação e o viewer rodaram de primeira.
