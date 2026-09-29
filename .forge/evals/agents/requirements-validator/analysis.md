# Análise do benchmark — agente `requirements-validator`

## Resultado

Fonte: `workspace/iteration-1/benchmark.json` (gerado por `aggregate_benchmark`, 3 evals, 1 run por eval por configuração — o campo `runs_per_configuration: 3` no metadata é herdado do template do script e não reflete o dado real, que é 1 run por configuração por eval, 6 execuções no total).

| Métrica | Com artefato | Sem artefato | Delta |
|---|---|---|---|
| Pass rate (média) | 0.80 (± 0.20) | 0.1333 (± 0.2309) | **+0.6667** |
| Tempo (s, média) | 142.0 | 138.7 | +3.3s |
| Tokens | 0 (não instrumentado) | 0 (não instrumentado) | — |

Por eval: recarga (1.0 vs 0.0), tarifação/2000 linhas (0.8 vs 0.0), legado docs/specs (0.6 vs 0.4).

Delta = 0.6667 ≥ 0.15 → **veredito: agrega**.

`benchmark_ok = true` — `aggregate_benchmark` rodou de primeira, sem erro de estrutura, e `generate_review.py` também. Não houve necessidade de corrigir diretórios/JSON.

## Asserções não discriminantes

Nenhuma das 16 asserções (6+5+5) passa igual em ambas as configurações no sentido de "sempre passa" — não há nenhuma 100%/100%. As mais próximas de não discriminar são as de higiene de árvore (`git status --porcelain -- docs/` vazio), que passaram nas duas configurações nos três evals: com ou sem artefato, o agente nunca edita `docs/` por conta própria neste caso de uso — comportamento provavelmente do modelo base, não do artefato. Vale tratá-la como controle de segurança, não como medida de valor do artefato.

## Onde o artefato ajudou

- **Formato de saída determinístico.** Nos evals 1 e 2 com artefato, a estrutura de seções (`Resultado`, `Veredito`, `Achados` com `[BLOCKER-NN]`/campos `Local`/`Problema`/`Impacto`/`Correção recomendada`, `Checks Executados`, `Decisão para o Pipeline`) aparece literalmente como o "Formato da Resposta" do artefato (linhas 455–514). Sem artefato, a saída do eval 1 é uma lista numerada em prosa sem nenhuma dessas seções ("achados são uma lista numerada 1-10 em prosa", grading), e falha as 6 asserções.
- **Regra de tamanho (2.000 linhas) seguida à risca.** No eval de tarifação, com artefato o agente mede 2.448 linhas, cita o limite, bloqueia a revisão detalhada e não avalia nenhum Req individual — exatamente o comportamento da seção "Regra Especial de Tamanho" (linhas 61–88), inclusive contra o pedido explícito do usuário para revisar Req 1–20. Sem artefato, o agente ignora o tamanho ("Não é o tamanho do documento o problema", linha 5 do output) e faz a revisão detalhada dos 20 requisitos pedidos.
- **Detecção de invasão de design com referência a ADR.** No eval de recarga, o artefato levou o agente a classificar o critério 1.3 (tabela/coluna/tópico Kafka) como invasão do `design.md` citando ADR-0002, sem propor stack alternativa — seguindo a seção 8 ("Separação entre Requirements e Design", linhas 320–346: reescrever em nível de requisito, não propor implementação). Sem artefato, o agente identifica o mesmo conflito de ADR mas **propõe implementação alternativa concreta** ("mensageria RabbitMQ conforme ADR-0003, tipo de dado BIGINT/centavos") — o oposto do que a seção 8 pede.
- **Bloqueio de aprovação com defeitos plantados.** No eval de recarga, o critério "Retorne Reprovado quando houver qualquer BLOCKER" (linhas 536–539) produz 8 BLOCKERs vs. zero BLOCKER sem artefato (que classifica os mesmos defeitos como "achados bloqueantes" fora da taxonomia BLOCKER/HIGH/MEDIUM/LOW).

## Onde o artefato atrapalhou ou não foi suficiente

- **Ambiguidade sobre "arquivo alvo" em caminho legado (eval `recusa-requirements-em-caminho-legado`).** É a única asserção que falha **nas duas configurações** com o mesmo padrão: o agente deveria concluir que `docs/product/modules/validacao/requirements.md` (o único caminho oficial) não existe e, por isso, interromper a validação sem avaliar conteúdo. Em vez disso, ambas as execuções tratam o arquivo em `docs/specs/validacao/requirements.md` como o "arquivo alvo" de fato e seguem validando seu conteúdo (tabela `Checks Executados` com OKs, achados sobre o Req 1 etc.), embora cheguem à conclusão correta no fim ("Reprovado", "não recomendo liberar o design-writer"). O artefato diz (linha 41-42): "O arquivo alvo: `docs/product/modules/<modulo>/requirements.md`" e (linha 57): "não interrompa a revisão, exceto quando o próprio requirements.md alvo não existir" — mas nunca resolve o caso em que o usuário aponta para um caminho legado que existe e tem conteúdo plausível. A leitura natural de um executor é "o arquivo que o usuário me pediu para validar é o arquivo alvo", contradizendo a definição estrita da linha 41. É o ponto de maior alavancagem para melhorar o artefato, porque o comportamento core (recusar validar o legado) é o mesmo com e sem o artefato — o artefato não está ensinando o comportamento certo aqui.
- **Template de recomendação de decomposição tratado como ilustrativo, não obrigatório (eval `tarifacao-acima-de-2000-linhas`).** A seção "Regra Especial de Tamanho" (linhas 69–82) dá um bloco de código com o formato recomendado (`# [nome-da-feature]/requirements.md`, `## User Story`, `## Acceptance Criteria` com checkboxes), mas o texto ao redor ("Formato recomendado:") não diz que esse bloco deve ser **reproduzido literalmente** na saída. O agente com artefato só menciona "User Story + Acceptance Criteria por agrupamento" em prosa e chega a declarar "Está fora do escopo deste validador propor a estrutura" — extrapolando escopo além do que a regra pede (a regra pede para emitir a recomendação com aquele formato, não para desenhar a árvore de pastas final). É a única falha do run with_skill de tarifação (4/5 passou).
- **Tempo de execução não melhora, e a variância aumenta.** Com artefato: 94–188s (σ=47s); sem artefato: 127–149s (σ=11s). O artefato de ~570 linhas provavelmente aumenta o tempo de leitura/raciocínio de forma desigual conforme o eval (o caso mais longo, 188s, é o de mais achados a produzir — recarga). Não é grave, mas indica que o artefato é grande para um agente configurado com `model: haiku` ("modelo rápido").

## Trechos do artefato ignorados, ambíguos ou contraditórios

- **Ambíguo** — linhas 41/57 ("arquivo alvo"): causa raiz da única falha comum às duas configurações, já discutido acima.
- **Ambíguo** — linhas 69–82 ("Formato recomendado"): falta a instrução explícita "reproduza este bloco" para deixar claro que não é apenas ilustração.
- **Contraditório em potencial** — linha 96 ("Não deve transformar requisitos em design técnico...") vs. linha 346 ("o requisito pode referenciar a restrição, mas deve manter a linguagem em nível de requisito"): não chegou a causar falha nos 3 evals, mas exige do executor decidir sozinho onde fica a linha entre "referenciar a restrição do ADR" e "propor implementação"; no eval sem artefato o agente cruzou essa linha, então vale reforçar com exemplo do permitido vs. proibido.
- **Ignorado, sem custo nos 3 evals** — seção 6 (Property-Based Testing, linhas 266–297) e "Outros requirements aprovados, se úteis para comparar padrão" (linhas 54–55): nenhum dos 3 casos exercitou PBT nem comparação entre módulos. Ponto cego do conjunto de avaliação, não do artefato.
- **Nenhum trecho claramente desperdiça tempo** — as 10 seções do checklist mapeiam 1:1 para categorias de achados observadas nos outputs; não há seção "morta" nos 3 transcripts lidos.

## Melhorias concretas priorizadas

1. **Alto impacto — resolver a ambiguidade de "arquivo alvo".** Adicionar, logo após a linha 57, uma regra explícita: "Se o usuário pedir para validar um arquivo fora de `docs/product/modules/<modulo>/requirements.md` (ex.: `docs/specs/`, `.kiro/specs/`, qualquer outro caminho), trate o caminho oficial como inexistente e PARE — não valide o conteúdo do arquivo fora do padrão, mesmo que ele pareça completo. Registre apenas um achado BLOCKER único apontando o caminho incorreto e o caminho oficial, sem produzir `Checks Executados` nem achados de conteúdo." Isso teria fechado a única falha comum às duas configurações, subindo o eval de 0.6 para provavelmente 1.0 no with_skill.
2. **Alto impacto — tornar o template de decomposição mandatório e citável.** Trocar "Formato recomendado:" por "Reproduza este bloco de formato, com nomes concretos preenchidos, dentro da seção 'Recomendações para o requirements-writer' da sua saída — não é apenas ilustrativo." Isso teria fechado a única falha do with_skill no eval de tarifação.
3. **Médio impacto — exemplo positivo/negativo na seção 8.** Adicionar um par curto de exemplos: "Permitido: 'a persistência deve garantir consistência auditável conforme ADR-0002 (centavos inteiros)'. Bloqueado: 'usar tipo BIGINT e RabbitMQ com outbox'" — para reduzir a chance de o próprio validador (ou o requirements-writer que lê a recomendação) recair em prescrever stack.
4. **Baixo impacto — reduzir tamanho do artefato para um agente `haiku`.** ~570 linhas é grande para um modelo "rápido". Candidatos a extrair para arquivo de referência sob demanda: seção 6 (PBT) e a tabela completa de versionamento (seção 9), já que nenhum dos 3 evals dependeu delas e ambas têm equivalente resumido em `.forge/rules/`. Não mudaria o resultado destes 3 evals, mas reduziria tempo/tokens em execuções que não tocam PBT/versionamento.
5. **Sem ação — não fundir nem remover nenhuma seção core.** As seções 1–5, 7, 8, 10, a "Regra Especial de Tamanho" e o "Formato da Resposta" têm evidência direta de terem mudado o resultado dos 3 evals (delta 0.67); nenhuma delas deve ser cortada.

## Qualidade dos próprios casos de teste (eval_quality)

Boa, com uma ressalva. Os 3 casos são bem desenhados: cada um isola um comportamento específico do artefato (formato+severidade; regra de tamanho vs. pedido explícito do usuário para ignorá-la; recusa de caminho legado) e usa fixtures com defeitos plantados verificáveis por grep/diff, não por julgamento subjetivo — o que torna o grading auditável linha a linha (`grading.json`). As asserções são conjuntivas e específicas o bastante para não dar "passe fácil" (ex.: a asserção 4 do eval de recarga exige tanto o achado do critério 1.3 quanto a citação de um ADR específico).

A ressalva é o eval `recusa-requirements-em-caminho-legado`: a asserção 1 exige uma interpretação de "arquivo alvo" que o próprio texto do artefato não deixa inequívoca (ver seção "trechos ambíguos" acima). Isso é uma característica válida do caso — expõe corretamente um buraco real do artefato — mas mistura dois sinais em asserções redundantes: a asserção 1 ("afirma que não existe e interrompeu") e a asserção 3 ("não contém achados sobre o conteúdo") sempre falham ou passam juntas nesta amostra, porque são a mesma causa raiz vista de dois ângulos. Não é um defeito grave, mas numa próxima rodada valeria fundir as duas em uma só asserção, para não inflar artificialmente a contagem de asserções falhadas por essa única causa.
