# Análise de benchmark — agente `data-analytical`

Fonte determinística: `benchmark.json` (gerado por `aggregate_benchmark.py` a partir de 3 evals × 1 run por configuração, iteration-1). `benchmark_ok=true` (agregação rodou de primeira, sem correção de estrutura).

## Resultado

| Configuração | Pass rate (média) | Min–max | Tempo médio |
|---|---|---|---|
| with_skill | 86,7% (0,8667) | 60%–100% | 151,0s |
| without_skill | 24,3% (0,2433) | 0%–40% | 115,3s |

Delta (com − sem) = **+0,62** → **veredito: agrega** (limiar ≥0,15 para "agrega" folgadamente atingido). O agente com o artefato (protocolo do `data-analytical.md` + skill `data-analytical-practices`) passa de menos de 1 em 4 asserções para mais de 6 em 7, ao custo de ~36s a mais por execução (tempo aceitável frente ao ganho de acerto).

## Asserções não discriminantes

Quatro das dezesseis asserções (nos três evals) não separam as configurações — não porque sejam triviais, mas por dois motivos distintos:

- **Passam nas duas configurações** (o protocolo não é necessário para acertar): `unique_key` + lookback no incremental dbt (eval 1) e "`git status --porcelain` vazio" (evals 1 e 3). O segundo é estrutural — o agente nunca teve `Write`/`Edit` no frontmatter, com ou sem skill, então nunca poderia sujar a árvore; não mede o artefato, mede a ausência da ferramenta.
- **Falham nas duas configurações** (nem o protocolo salva): no eval 2 (borda-delta-50gb), tanto with_skill quanto without_skill falham em (a) reportar que a varredura analítica não examinou nenhum arquivo de `services/validador` (NADA-EXAMINADO) em vez de dizer "sem achado"/"nada a examinar", e (b) informar que o `check-data-governance.sh` não verificou PAN/PII em `lakehouse/gold` por universo vazio. Isso é um ponto cego real do agente com skill, coberto abaixo.

## Onde o artefato ajudou

Nos itens que dependem de conhecimento e disciplina codificados no protocolo/skill, o ganho é grande e consistente:

- Citação do catálogo de antipatterns com localização exata (A-06, A-08, A-10, A-12, A-14) — sem skill, o parecer do eval 1 nem usa os ids nem o formato `arquivo:linha`.
- Regra `money-as-cents` (eval 1): com skill, o agente classifica `numeric(12,2)` como violação bloqueante e propõe `bigint`/centavos; sem skill, trata como "ponto de atenção, não bloqueante" e mantém a coluna decimal na correção proposta.
- Limiar de particionamento do Databricks (eval 2): com skill, recusa explicitamente particionar `gold.viagens` citando "abaixo de 1 TB" e propõe `CLUSTER BY` com DDL/ALTER; sem skill, implementa exatamente o particionamento por dia/operadora pedido pelo usuário — o oposto da recomendação correta — e cita liquid clustering só como alternativa condicional, sem DDL.
- Protocolo de conflito ADR × skill (eval 3): com skill, produz o bloco `CONFLITO` completo (decisão/posição A/posição B/precedência/opções/registro) citando `.forge/product/current/adr/0004-...md` e a ordem de precedência do `FORGE.md` §2.1; sem skill, entrega um markdown livre sem os seis campos e sem a linha de precedência, embora — por sorte — também não tenha entregado DDL com liquid clustering.
- Interpretação de `check-data-governance.sh` (eval 1): com skill, o agente roda o script no path certo e relata corretamente "não verificado" (universo vazio) sem declarar aprovação; sem skill, o script nem é executado.

## Onde o artefato atrapalhou ou não bastou

Não há caso de "pior com skill que sem skill" nas asserções que discriminam — mas há um ponto cego real do próprio artefato, replicado nas duas configurações do eval 2:

- **Passo 4 do protocolo ("um `--root` por path afetado")** foi seguido literalmente — o agente chamou `scan.sh --root lakehouse/gold/viagens.sql --root services/validador` numa única invocação — mas o resultado agregado ("ARQUIVOS-VARRIDOS 1", um único `FOUND A-06`) escondeu que `services/validador` não teve nenhum arquivo examinado. O agente nunca chega a reportar "NADA-EXAMINADO" para esse domínio; em vez disso, conclui "nada a examinar além do stub", formulação equivalente a "está limpo" que o protocolo no passo 5 proíbe explicitamente ("diga isso, não reporte limpo").
- **Escopo do `check-data-governance.sh`** no eval 2: o agente chamou o script com `--path lakehouse/gold/viagens.sql` (o arquivo citado no pedido do usuário), não com o diretório do domínio (`lakehouse/gold`). O protocolo (passo 3) diz "para cada path afetado" sem definir se "path" é o arquivo mencionado no prompt ou o diretório do domínio — ambiguidade que o agente resolveu do jeito que não expõe o universo vazio corretamente.

## Trechos ignorados, ambíguos ou contraditórios

- **Ambíguo** — passo 3 ("Rode `... --path <path>` para cada path afetado"): não diz se `<path>` deve ser o arquivo específico citado pelo usuário ou o diretório do domínio afetado. Isso levou à execução com escopo estreito demais no eval 2.
- **Ambíguo em combinação com a CLI real** — passo 4 ("um `--root` por path afetado") é ambíguo entre "uma chamada de `scan.sh` por path" e "uma chamada com múltiplos `--root`". A segunda leitura (a que o agente seguiu, e que é permitida pela frase) produz um resultado agregado que esconde a atribuição por domínio — contradiz o objetivo do passo 5 de poder dizer "NADA-EXAMINADO" por path individual.
- **Não observado como ignorado**: o restante do protocolo (ordem fixa 1→6, checklist, catálogo de antipatterns bloqueados, regra de integração gRPC/REST) foi seguido nas três execuções com skill sem indício de trecho pulado; a "Regra de integração" (bloco longo sobre gRPC/REST/terceiros) não foi exercitada por nenhum dos três evals — não há evidência de que ajude ou atrapalhe neste benchmark.

## Melhorias concretas (priorizadas)

1. **[Alta]** No passo 4, trocar "um `--root` por path afetado" (numa única chamada) por instrução explícita de **uma chamada de `scan.sh` por path afetado**, cada uma reportada separadamente na resposta — preserva a atribuição por domínio e permite dizer "NADA-EXAMINADO" path a path, em vez de um resultado agregado que mascara domínios vazios. Evidência: eval 2, ambas as configurações falham nas asserções 4 e 5 pelo mesmo motivo estrutural.
2. **[Alta]** No passo 3, precisar que `<path>` passado ao `check-data-governance.sh` é o **diretório do domínio afetado** (ex.: `lakehouse/gold`), não o arquivo específico citado no pedido do usuário — remove a ambiguidade que levou ao escopo errado no eval 2.
3. **[Média]** Reforçar no passo 6 (Resposta) que, quando algum path afetado teve resultado "NADA-EXAMINADO" ou "universo vazio" no passo 3/4, a resposta final ao usuário deve declarar isso **por domínio**, não só de forma geral — hoje o protocolo menciona a regra no passo 5 (julgamento interno) mas não amarra explicitamente à obrigação de reportar na resposta final por path.
4. **[Baixa, não é problema do artefato]** As asserções "`git status --porcelain` vazio" (evals 1 e 3) não discriminam porque dependem só da ausência de `Write`/`Edit` no frontmatter, não do protocolo — candidatas a remoção ou substituição em iterações futuras do benchmark por não medirem o artefato sob avaliação. Da mesma forma, "unique_key + lookback no incremental" (eval 1) passou em ambas as configurações — é conhecimento comum de dbt, não um diferencial específico da skill; considerar trocar por uma asserção mais específica do catálogo A-08/A-14 nessa mesma pergunta.
