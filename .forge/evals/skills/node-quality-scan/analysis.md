# Análise do benchmark — node-quality-scan

Fonte: `benchmark.json` gerado por `scripts.aggregate_benchmark` (agregação determinística, sem cálculo manual). 3 evals × 1 run por configuração (6 runs no total).

## Resultado

| Configuração | pass_rate médio | min | max |
|---|---|---|---|
| with_skill | 86,7% (0,8667) | 0,60 | 1,00 |
| without_skill | 63,3% (0,6333) | 0,40 | 1,00 |

Delta = +0,23 (com − sem) — **veredito: agrega** (limiar ≥0,15).

Tempo médio: with_skill 105,0s vs without_skill 91,7s (delta +13,3s) — a skill custa cerca de 14% mais tempo de execução (puxado por `eval-triagem-achados-cobranca`, 126s vs 96s, onde o executor com skill leu a referência `clean-code-rules.md` inteira antes de julgar cada achado), mas o ganho de 23 pontos de pass_rate compensa esse custo. `tokens`/`tool_calls` vêm zerados nos dois lados porque o harness de eval não instrumentou essas métricas nesta rodada (ausência de instrumentação, não "zero uso real" — sinalizado para não induzir leitura errada).

## Asserções não discriminantes

- As 4 asserções do eval `eval-recusa-stack-python` (escopo Node/TS, ausência de bloco de aprovação forjado, redirecionamento para ferramenta Python, ausência de ids de regra em arquivos `.py`) passam 100% nas duas configurações. O parágrafo de escopo do `description` da skill ("Não use... para stack que não seja Node/TypeScript") já é óbvio para qualquer executor competente sem carregar a skill — este eval mede bom senso geral, não valor incremental da skill. Vale como guard-rail de regressão, mas não deveria pesar na leitura de "a skill ajuda".

## Onde a skill ajudou (evidência de transcript)

- **eval-triagem-achados-cobranca**: with_skill 100% vs without_skill 50%. A diferença central é o uso de `references/clean-code-rules.md`: with_skill classificou `floating-promise` em `src/jobs/lembrete.ts:4` como falso positivo citando explicitamente a "limitação de regex sobre texto" documentada na referência; without_skill chegou à mesma leitura do código mas rotulou como "nitpick de estilo", não como falso positivo do scanner, e ainda sugeriu reescrever para `async`/`await` — falhando a asserção. without_skill também não relatou o `node-baseline.sh --check` (FAIL por ausência de `eslint.config.mjs`) porque não sabia que esse passo existia, e não citou a linha exata (`:13`) do achado real de SQL injection. As exceções legítimas documentadas na referência (bootstrap de conexão, bootstrap de TLS, porta hexagonal) são exatamente o que faltou ao lado sem skill para não tratar heurística como veredito automático.
- **eval-revisao-pacote-pedidos**, asserção "nenhum achado aponta para packages/notificacoes": ambos os lados acertaram (o fixture já limita o diff), mas without_skill só acertou por leitura cuidadosa do diff, não por protocolo — sem o escopo explícito do `scan.sh --root <path>` restrito ao pacote tocado, nada garante que uma sessão real não varra o monorepo inteiro.

## Onde o artefato atrapalhou ou foi ambíguo (evidência de transcript)

1. **Ambiguidade real no protocolo, passos 1–2**: a skill instrui "1. Escopo: defina os paths Node/TS afetados... 2. Baseline de lint: `node-baseline.sh --root <path> --check`", usando o mesmo `<path>` para as duas coisas. A existência de `eslint.config.mjs` é propriedade do **repositório/workspace**, não do pacote individual. No fixture de `eval-revisao-pacote-pedidos`, `eslint.config.mjs` existe na raiz real do monorepo (`work/eslint.config.mjs`), mas o executor with_skill rodou `--root packages/pedidos --check`, que não encontrou o config ali e reportou "falta `eslint.config.mjs` na raiz do repositório" — diagnóstico com causa errada, marcado como falha explícita pela asserção 2 do eval ("com a origem: config na raiz do monorepo"). O texto da skill não distingue "escopo da varredura de achados" (por pacote, correto) de "escopo do baseline de lint" (deveria ser sempre a raiz do repositório/workspace, independente do path do diff). Essa ambiguidade é a causa isolada do pass_rate 0,60 no eval mais fraco with_skill.
2. **Passo 5 ("uma linha por regra, incluindo as que passaram") não foi seguido à risca por nenhum executor**: with_skill escreveu um relatório com seção "Achados do scanner" listando só os 5 `FOUND`, resumindo as 6 regras `OK` numa frase agregada ("5 FOUND em 11 regras") em vez de uma linha nomeada por regra. Isso reprovou a asserção 1 do eval (que exige as 11 regras nomeadas, inclusive as limpas). A instrução está correta em prosa mas não impõe um formato mecânico — o executor precisa lembrar de expandir os `OK` manualmente, e em nenhum dos dois runs isso aconteceu.
3. **Trecho de baixo impacto observável**: as seções "O que o scanner NÃO faz" e "Sessão limpa" somam quase metade das 40 linhas do SKILL.md, mas nenhum transcript mostra "sessão limpa" mudando comportamento — no desenho destes evals (mesma sessão sempre revisa um fixture, nunca o próprio código que ela escreveu), essa orientação nunca tem como se manifestar. Não é contraditório, apenas texto que hoje não é exercido pelo benchmark; candidato a virar uma linha dentro de "Protocolo" caso o arquivo precise encolher.

## Qualidade dos casos (eval_quality)

- **eval-recusa-stack-python**: bom para regressão de escopo, mas não discriminante (ver acima); considerar substituir/complementar por um monorepo com um pacote Python e outro Node, testando se a skill escopa certo dentro do repositório em vez de recusar o repositório inteiro.
- **eval-revisao-pacote-pedidos**: caso forte — a asserção 2 (origem do FAIL de baseline) é sutil o bastante para expor a ambiguidade real do protocolo (achado 1 acima), e a asserção 3 (isolar `packages/notificacoes`, que tem os mesmos 5 tipos de achado pré-existentes em `main`, fora do diff) é uma boa isca contra varredura larga demais. Ponto fraco: a asserção 1 mistura duas exigências (11 regras nomeadas E "OK"/limpo explícito) numa frase só, dificultando isolar qual delas foi violada sem ler a evidência completa.
- **eval-triagem-achados-cobranca**: o melhor caso dos três para medir valor da skill — cada uma das 5 asserções isola exatamente uma exceção do `clean-code-rules.md`, e o contraste with/without é limpo nos transcripts (floating-promise classificado como estilo, não como falso positivo do scanner, é a falha mais informativa do lote).

## Melhorias concretas priorizadas

1. **Corrigir o protocolo (texto), passos 1–2**: separar explicitamente "escopo da varredura" (`scan.sh --root <path-do-diff>`) de "escopo do baseline" (`node-baseline.sh --check` deve rodar sempre a partir da raiz do repositório/workspace do monorepo, nunca do subpacote, porque é ali que `eslint.config.mjs` vive). Um parêntese de uma linha no passo 2 resolve a causa raiz da falha em `eval-revisao-pacote-pedidos`.
2. **Tornar o passo 5 mecânico em vez de só prosa**: embutir em `scan.sh` uma opção que já emite o esqueleto de relatório com as 11 regras pré-listadas (ou instruir explicitamente a transcrever a saída bruta linha a linha, regra por regra, incluindo `OK`), em vez de confiar que o executor vai lembrar de expandir os `OK` na prosa final.
3. **Mover ou encurtar "Sessão limpa"**: sem urgência — não muda resultado de eval nenhum hoje; considerar reduzir a uma linha dentro de "Protocolo" se o SKILL.md precisar encolher.
4. **Novo caso de eval**: monorepo com pacote Python + pacote Node, testando escopo correto por pacote (substitui parcialmente a não-discriminância de `eval-recusa-stack-python`).

## Veredito

- run_summary: with_skill mean pass_rate 0,8667; without_skill mean pass_rate 0,6333.
- delta = 0,8667 − 0,6333 = **+0,23**.
- benchmark_ok = true (aggregate_benchmark e generate_review rodaram de primeira, sem erro).
- **Veredito: agrega** (delta ≥ 0,15).
