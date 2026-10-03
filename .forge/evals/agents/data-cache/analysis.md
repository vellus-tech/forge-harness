# Análise do benchmark — agente `data-cache`

## Resultado

- **Com skill:** pass rate 100% (média 1.0, stddev 0, 15/15 asserções em 3 evals × 1 run).
- **Sem skill:** pass rate 33,3% (média 0,333, stddev 0,116; eval 1 = 0,4, eval 2 = 0,2, eval 3 = 0,4).
- **Delta:** +0,67 (agrega, limiar ≥0,15 folgado).
- **Tempo:** praticamente neutro (127,0s com skill vs. 125,0s sem skill, +2,0s) — o artefato não paga custo relevante de latência.
- **Tokens/tool_calls:** o grader não capturou esses campos (zerados nas duas configurações); não dá para avaliar overhead de contexto por essa métrica no benchmark atual.
- `benchmark_ok = true` (agregação rodou de primeira, sem correção de estrutura).

Amostra pequena (3 evals × 1 run, sem repetição) — o stddev de 0 na condição "com skill" é resultado de rodar cada eval uma única vez, não evidência de zero variância real; é ponto a favor de rodar `--runs 3` numa próxima leva antes de tratar o número como definitivo.

## Asserções não discriminantes

Nenhuma asserção passa 100% nas duas condições — todas as 5 asserções por eval diferenciam a favor do "com skill" em pelo menos um caso. A única asserção que se aproxima de não discriminar é a de "árvore limpa" (`git status --porcelain` vazio): passa nas 6 rodadas (3 com skill, 3 sem skill). Isso é esperado e correto — mede disciplina de não escrever fora de `outputs/`, que ambas as configurações respeitam porque a instrução de "recomendação, sem Write/Edit" está no prompt do eval, não na skill. Vale como controle de sanidade do harness, não como evidência de valor da skill.

## Onde o artefato ajudou

- **Bloco `CONFLITO` (eval 3, Redis como store primário do saldo):** com skill, o agente devolve o bloco estruturado completo (decisão/posição A/posição B/precedência/opções/registro) definido no artefato; sem skill, o mesmo raciocínio aparece em prosa solta, sem os campos e sem "registro" — a asserção mais estrutural (a única das 5 que falha sem skill nesse eval) é justamente a que depende do formato do artefato, não do conteúdo do julgamento (a posição A com citação ao ADR-0003 passa nas duas condições).
- **Recusa de Redis como armazenamento primário do saldo:** sem skill, o agente entrega `appendonly yes`/`appendfsync everysec`/`save` e um `debit.lua` que faz `DECRBY` no Redis no caminho crítico — exatamente o antipattern C-07 que o artefato bloqueia por padrão ("nunca fonte de verdade"). Esse é o ponto de maior risco: sem o artefato, o agente não só deixa de recusar, produz e entrega a configuração proibida como solução.
- **Encaminhamento de domínio (fila para `data-streaming`, escolha de store para `data-relational`/`data-nosql`):** só ocorre com skill. Sem skill, a fila LPUSH/BRPOP na mesma instância de cache (antipattern C-13) é aceita sem ressalva.
- **Citação de ids do catálogo (C-01, C-02, C-08, C-09, C-10, C-11, T-04) com `arquivo:linha`:** consistente com skill, ausente sem skill nas 3 evals — mesmo quando o agente sem skill identifica o problema certo (ex.: ordem de invalidação, chave sem namespace de tenant), não o ancora a um id rastreável do catálogo de antipatterns.
- **HMAC/id substituto para a chave com CPF (T-04), vs. SHA-256 puro:** com skill, o agente recomenda HMAC com chave em KMS e explicita por que hash simples é reversível por força bruta; sem skill, recomenda exatamente o hash simples que a asserção reprova — indica que a skill carrega esse conhecimento específico (hash reversível de CPF por causa do espaço pequeno, ~10⁹) que não é senso comum do modelo base.
- **Interpretação correta de `check-data-governance.sh` com universo vazio:** com skill, o agente distingue "não verificado" (por não ler `.java`) de "aprovado"; sem skill (eval 2), o verificador nem chega a ser executado — o protocolo de 6 passos do artefato (rules → conflito → dado sensível → varredura → julgamento → resposta) é o que força essa etapa a acontecer.
- **redis.conf seguro (maxmemory explícito + allkeys-lru/lfu + protected-mode yes + bind privado):** com skill, as 4 propriedades aparecem juntas; sem skill (eval 1), aparecem parcialmente e com valores fracos (`maxmemory` sem valor explícito, `volatile-lru` aceito, bind 0.0.0.0 registrado como severidade "baixa" em vez de corrigido).

## Onde o artefato atrapalhou ou foi redundante

Não há evidência, nestas 3 evals, de o artefato prejudicar (nenhuma asserção passa sem skill e falha com skill) nem de custo de tempo/token relevante. Duas ressalvas menores, não bloqueantes:

- No eval 3 sem skill, a citação aos caminhos do ADR-0003 e das rules já aparece mesmo sem a skill formal (a asserção aceita "ou o texto que a fundamenta") — sugere que parte do conhecimento de precedência (ADR/rule > skill) já está acessível ao modelo por outras vias no ambiente (provavelmente por o agente ler `.forge/rules` e `.forge/product/current` independente da skill, conforme o Protocolo passo 1, que não é exclusivo da skill mas do próprio prompt do agente). Isso é esperado — o artefato avaliado é o **agente** `data-cache.md`, que já traz esse protocolo embutido na definição, e a skill `data-cache-practices` soma o catálogo e o formato `CONFLITO`; a linha entre "o agente" e "a skill carregada por ele" fica um pouco borrada nesta avaliação porque o benchmark trata a dupla como uma unidade (`with_skill` = agente completo com a skill anexada).
- No eval 1 sem skill (achado 3 — C-02/C-09/C-10/C-11), o agente acerta `arquivo:linha` mas erra só o id do catálogo — indica que a lacuna é especificamente o catálogo/nomenclatura da skill, não a capacidade de leitura de código, o que é o comportamento esperado e desejável (mostra que o ganho vem do conteúdo do artefato, não de compensar uma limitação genérica do modelo).

## Trechos ignorados, ambíguos ou contraditórios no artefato

- **Passo 3 do protocolo ("Dado sensível")** é o trecho com maior densidade de nuance no artefato (distinção entre `CONFLICT`, `FAIL data-governance/universo-vazio` e `FAIL (node >= 20 required)`, cada um com leitura própria) e é também o que mais separa as duas condições no eval 2 — não é ambíguo, mas é o ponto onde a ausência do artefato mais dói, o que sugere que vale reforçar esse trecho com um exemplo de saída literal do script (a asserção do eval cobrou uma leitura correta de mensagem de erro que só está descrita em prosa no artefato, sem trecho de terminal ao lado).
- **Passo 4 ("Varredura")** limita o `Bash` do agente a dois comandos exatos, aplicados via hook `PreToolUse`; nenhuma das evidências dos transcritos (não lidos linha a linha aqui) indicou violação ou tentativa de contorno, então não há sinal de atrito nessa restrição — mas também não há eval que exercite o caminho de erro do hook (ex.: agente tentando `bash .../scan.sh --json` e sendo bloqueado), o que deixa essa proteção sem cobertura própria no benchmark.
- Não foram identificadas contradições internas no artefato nem instruções que as 3 evals tenham exercitado como ambíguas — as 15 asserções (5 por eval) foram desenhadas com granularidade que evita zona cinzenta (ex.: "delete, não set" é explícito o bastante para reprovar a resposta sem skill no eval 1 de forma inequívoca).

## Melhorias concretas, priorizadas

1. **Adicionar ao passo 3 do protocolo um bloco de exemplo com a saída literal de `check-data-governance.sh` para os três casos** (`CONFLICT (...)`, `FAIL data-governance/universo-vazio`, `FAIL (node >= 20 required)`) — hoje é só prosa; um exemplo de linha real reduziria o único ponto onde o agente sem skill falhou por não saber que o verificador precisava rodar e ser interpretado, e reforçaria a leitura correta mesmo com a skill.
2. **Cobrir o caminho de erro do hook de `Bash` (passo 4) com um eval dedicado** — nenhuma das 3 evals atuais teve o agente tentar um comando fora dos dois permitidos; sem esse caso, a proteção do frontmatter (`data-agent-bash-guard.sh`) fica sem prova de que o agente reage corretamente (ex.: não trava, escala ao invés de insistir) quando o `Bash` nega.
3. **Adicionar uma asserção que teste diretamente o antipattern C-07 quando o pedido for ambíguo (não deliberadamente malicioso)** — o eval 3 já cobre bem o caso "pedido explícito de saldo em Redis"; falta um caso mais sutil (ex.: pedido de "cache com durabilidade" sem mencionar saldo) para confirmar que o bloco `CONFLITO` dispara mesmo quando a intenção do solicitante é ambígua, não só quando o antipattern é óbvio.
4. **Rodar o benchmark com `--runs 3` (múltiplas rodadas por configuração)** antes de tratar o stddev de 0% na condição "com skill" como estável — a amostra atual (1 run por eval) não permite distinguir "skill sempre robusta" de "sorte de execução única"; é item de rigor do processo de avaliação, não do artefato em si.
5. **Investigar por que `tokens`/`tool_calls` vêm zerados no `grading.json`** — sem esses campos, a análise de custo do artefato (passo 6 do protocolo pede consulta ao context7 antes de afirmar um default, o que pode ter custo de tool call não capturado) fica incompleta; é item de instrumentação do harness de eval, não do agente `data-cache`.
