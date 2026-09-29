# Análise do benchmark — agente `data-streaming`

Fonte determinística: `benchmark.json` (gerado por `scripts.aggregate_benchmark` sobre `workspace/iteration-1`, 3 evals × 1 run por configuração). Cópia de `benchmark.json`/`benchmark.md` também nesta pasta.

## Resultado

| Configuração | pass_rate médio | min–max | tempo médio |
|---|---|---|---|
| Com skill (`with_skill`) | 88,67% | 83%–100% | 152 s |
| Sem skill (`without_skill`) | 23,33% | 17%–33% | 118 s |
| **Delta** | **+0,6533** | — | +33,7 s |

Delta ≥ 0,15 → **veredito: agrega**, e com folga: a diferença é de quase 4× na taxa de acerto, consistente nos três evals (eval 1: 83% vs 17%; eval 2: 83% vs 33%; eval 3: 100% vs 20%). Nenhum dos três intervalos se sobrepõe.

Ressalva de qualidade do benchmark: é 1 run por configuração por eval (não os 3 runs que o agregador espera para stddev robusto — o `stddev` de cada configuração aqui reflete um único ponto por eval, não repetição do mesmo eval). O sinal é forte o suficiente para não depender de mais runs, mas o benchmark não mede variância intra-eval, só inter-eval.

## Asserções não discriminantes

Duas das 17 asserções passam em ambas as configurações e não isolam o valor do artefato:

- **eval 3 / "leu-o-adr-do-baseline"** — passa com e sem skill. O modelo base já lê `.forge/product/current/adr/` e cita o ADR-0004 pelo número mesmo sem a skill; o protocolo do agente não está adicionando esse comportamento, só reforçando-o.
- **eval 2 / "pii-pseudonimizada-com-chave"** — passa com e sem skill. Tratar CPF/nome como dado LGPD e recomendar remoção é conhecimento de base do modelo; a skill não move essa agulha (embora nenhuma das duas respostas cite HMAC/KMS explicitamente, ambas satisfazem a disjunção "remover ou pseudonimizar").

## Onde o artefato ajudou

- **Bloco CONFLITO (eval 3, maior diferencial): 100% vs 20%.** Sem a skill, o agente não só deixa de emitir o bloco de seis linhas — ele **decide sozinho** qual contrato usar ("Decisão tomada nesta rodada... desenhei o consumidor... contra o tópico de CDC") e entrega o desenho ao task-coder, exatamente o que o protocolo proíbe (passo 2: "nunca 'registre e siga'"). A skill não só melhora formatação, ela impede uma decisão de arquitetura tomada sem HITL.
- **Interpretação de `universo-vazio` (eval 2): declarado explicitamente como "não verificado" em vez de omitido.** Sem skill, o transcript nem executa `check-data-governance.sh`; a resposta simplesmente não menciona o verificador — ambiguidade sobre se PAN/PII foi checado ou não.
- **Citação de id + arquivo:linha do catálogo de antipatterns (RMQ-AP-10, RMQ-AP-01, RMQ-AP-06, RMQ-AP-28, T-02, OBX-AP-01).** Sem skill, o agente às vezes acha o problema certo (ex.: eval 1 sem skill identifica corretamente que `ch.nack(msg)` reenfileira por padrão), mas erra o mecanismo mais fundo: a run sem skill do eval 1 afirma que `delivery-limit` "corta o laço de redelivery em definitivo, mesmo se o código do consumidor voltar a ter algum bug de requeue" — **factualmente errado** (basic.nack não conta para o delivery-limit da fila quorum) — e a correção proposta usa `nack(msg, false, true)` (requeue imediato) no ramo de erro transitório, ou seja, a correção sem skill **não resolve o laço que motivou o chamado**. Com a skill esse ponto (nack sem argumento reenfileira e não é contido pelo delivery-limit) é citado nas duas runs com skill.
- **Achado só de revisão manual (OBX-AP-01, dual write em `pagamentos.js`).** O `scan.sh` não detecta esse caso; só a run com skill nomeia o antipattern e recomenda outbox transacional com relay. A run sem skill nem menciona dual write.

## Onde o artefato atrapalhou ou não ajudou

- **"valor em centavos pela rule money-as-cents" falha nas DUAS runs com skill (eval 2), não só sem skill.** A run com skill lê corretamente a rule, constata que `applies_to` não lista `backend-java` e por isso **não recomenda a troca**, devolvendo a decisão a `data-relational` ("sinalizo e devolvo"). Isso é leitura correta do `applies_to` (que de fato lista `backend-dotnet, frontend-react, android-kotlin`) e coerente com o protocolo de "não escrever fora do próprio domínio" — mas a asserção do eval exige a recomendação direta de inteiro/centavos. Isso não é falha do artefato, é um caso onde a asserção do eval não previu o comportamento correto e conservador que o próprio protocolo do agente induz (citar a rule, mas devolver a decisão de schema numérico ao dono do store). Vale revisar a asserção, não o agente.
- **"nao-escreveu-na-arvore" (eval 1) falha na run com skill mas passa sem skill** — só porque `git status --porcelain` mostra `?? .forge/agents/` e `?? .forge/skills/` (a instalação do próprio artefato sob avaliação na fixture, registrada em "Instalação do artefato" no transcript), não porque `src/`, `infra/` ou a correção proposta tenham sido escritas na árvore (o transcript confirma que `consumidor.js:14` e `policy.json` continuam intactos). É ruído de harness — a asserção mede git status de forma literal demais e não distingue "arquivos do próprio agente instalados pelo setup do eval" de "arquivos do domínio alterados pelo agente".
- **Tempo: +33,7 s em média com skill (152 s vs 118 s), maior no eval 1 (199 s vs 131 s).** Custo esperado — a skill exige dois comandos (`check-data-governance.sh` e `scan.sh`) que a run sem skill simplesmente pula.
- **Tokens: dado incompleto.** Só 2 das 6 runs registraram token count (eval 2, ambas configurações: 8087 com skill vs 7122 sem skill); as outras 4 runs (evals 1 e 3) reportam 0. A média de tokens do `run_summary` (+322 "com skill") não é confiável — está dominada pelas duas únicas runs com dado real, e a comparação de custo em tokens fica inconclusiva com este benchmark.

## Trechos ignorados, ambíguos ou contraditórios

- **Eval 2, run com skill:** a resposta cita corretamente `.forge/rules/domain/money-as-cents.md` e o `applies_to`, mas o caso chama atenção para uma tensão real no protocolo do agente: o passo 6 diz "DDL, policy ou trecho de código vão na resposta" mas também diz "quem escreve é o agente de engenharia" — não há orientação explícita no artefato sobre o que fazer quando uma rule de domínio (não de streaming) é relevante mas fora do `applies_to` declarado. O agente escolheu "sinalizar e devolver", comportamento razoável mas não descrito literalmente no protocolo.
- **Eval 3, run sem skill:** a posição B do "conflito" que o agente sem skill detecta sozinho cita a rule `api-and-contracts.md`, não a skill/CDC-AP-02 — ou seja, mesmo sem a skill o modelo base percebe alguma tensão arquitetural, mas erra a fonte da segunda posição e, mais grave, não trata isso como bloqueio: decide e entrega o desenho ao task-coder mesmo assim. O artefato (protocolo passo 2 + bloco CONFLITO) é o que transforma "percebo uma tensão" em "paro e devolvo para decisão humana".
- **Eval 1, ambas as runs:** nenhuma menciona explicitamente `consumer_timeout` nem `overflow=reject-publish`, itens do checklist do artefato que não foram cobertos por nenhuma asserção do eval — não dá para saber se a skill os traria à tona num cenário que os exercitasse; é uma lacuna de cobertura do benchmark, não do artefato.

## Melhorias concretas priorizadas

1. **Revisar a asserção "valor-em-centavos-pela-rule" (eval 2) ou o texto de `expected_output`.** Ela penaliza um comportamento que o próprio protocolo do agente (ler `applies_to`, não recomendar fora do domínio próprio, devolver ao dono) induz como correto. Prioridade alta — é um falso negativo que reduz artificialmente o pass_rate com skill de 100% para 83% no eval 2.
2. **Revisar a asserção "nao-escreveu-na-arvore" para ignorar artefatos de instalação do próprio agente sob teste** (ex.: `git status --porcelain -- ':!.forge/agents' ':!.forge/skills'`, ou rodar a checagem antes da instalação do artefato). Prioridade alta — mesmo problema de falso negativo, afeta qualquer eval de agente que precise ser instalado na fixture antes de rodar.
3. **Fortalecer, no artefato, a distinção entre "achado do scanner" e "achado só de revisão manual"** (o texto já existe no passo 5 — "Cada FOUND é candidato, não veredito" — mas o caso OBX-AP-01 mostra que essa disciplina de revisão manual é o que mais diferencia o resultado; vale um exemplo explícito no protocolo, tipo "dual write não aparece no scan.sh — é achado só de leitura de código", para reduzir dependência de o modelo generalizar isso sozinho). Prioridade média.
4. **Adicionar ao checklist do artefato uma frase curta sobre o que fazer quando uma rule de domínio relevante (ex.: money-as-cents) não lista a stack do projeto em `applies_to`** — "sinalizar e devolver ao dono do store" versus "recomendar mesmo assim, citando a divergência de `applies_to`" — hoje fica implícito e gerou o único ponto de ambiguidade real observado nas runs com skill. Prioridade média.
5. **Instrumentar contagem de tokens nas quatro runs que zeraram (evals 1 e 3, ambas configurações)** antes de tirar qualquer conclusão de custo — hoje o benchmark não permite comparar custo em tokens com confiança. Prioridade baixa (não é um problema do artefato, é do harness de medição).

## Veredito

pass_rate com skill = **0,8867**; sem skill = **0,2333**; delta = **+0,6533** (agrega, delta ≥ 0,15). `benchmark_ok = true` — a agregação determinística rodou de primeira, sem precisar de correção de estrutura.
