# Análise do benchmark — skill `data-analytical-practices`

Fonte: `.forge/evals/skills/data-analytical-practices/workspace/iteration-1/benchmark.json` (agregação determinística via `scripts.aggregate_benchmark`, sem edição manual dos dados). 3 evals × 1 run por configuração (`with_skill` / `without_skill`).

## 1. Resultado

| Configuração | Pass rate | Tempo médio |
|---|---|---|
| Com a skill | 63,3% (mean 0.6333, stddev 0.1528, min 0.50 / eval 3, max 0.80 / eval 1) | 169,3s |
| Sem a skill | 0,0% (0/14 asserções em todos os 3 evals) | 130,3s |
| Delta | **+0,63** | +39s |

`benchmark_ok = true` (agregação rodou de primeira, sem precisar corrigir estrutura). Veredito: **agrega** (delta ≥ 0,15).

Sem a skill, o agente falhou 100% das 14 asserções nos três cenários — não só por deixar de citar os antipatterns certos, mas por decisões de fundo opostas às esperadas: manteve PII em SCD2, manteve `invalidate_hard_deletes`, manteve particionamento estático abaixo do limiar de produto, e não distinguiu "nada examinado" de "aprovado". Isso não é sinal de assimetria de dificuldade das asserções — é o comportamento esperado de quem não tem o catálogo de antipatterns nem o protocolo de varredura em mãos.

## 2. Asserções não discriminantes

Duas, ambas do eval `certificar-analytics-sem-sql`, falharam em **ambas** as configurações (não diferenciam o valor da skill neste desenho de teste):

- **"checklist não marcado"** — tanto com quanto sem a skill, o agente marcou o item do checklist como `[x]` depois de rodar a varredura (mesmo reportando `NADA-EXAMINADO` e recomendando não certificar). A skill não instrui a deixar o item de checklist do usuário em aberto quando a evidência é "não verificado"; ela regula o conteúdo do relatório analítico, não a interação com artefatos de terceiros como um checklist de auditoria.
- **"escala ao usuário apontando warehouse/"** — com a skill, o agente decidiu sozinho ampliar o escopo para `warehouse/` e resolver a divergência sem perguntar ao usuário; sem a skill, nem chegou a essa decisão. Nenhuma das duas configurações produziu uma resposta final pedindo confirmação de escopo — porque a tarefa roda em modo não interativo (transcript, sem turno de resposta ao usuário) e a skill não tem uma instrução de "pare e pergunte" para ambiguidade de escopo.

Nenhuma asserção passou 100% nas duas configurações (não há "grátis" nos 3 evals — todas as 14 dependem de alguma leitura correta do catálogo ou do protocolo).

Uma terceira, "uma entrada por regra... inclusive as limpas" (eval `revisao-dbt-projeto-viagens`), também falhou nas duas configurações, mas por motivos distintos: sem a skill, o relatório nem existe no formato pedido; com a skill, o relatório citou os achados corretamente mas não produziu a tabela regra-a-regra com status explícito para as regras limpas — apesar do transcript afirmar textualmente ter feito isso ("tabela de detecção regra-a-regra, inclusive as que o catálogo cobriria e não bateram"). Há uma divergência entre o que o transcript relata e o que o artefato de saída (`revisao-analitico.md`) de fato contém.

## 3. Onde o artefato ajudou

- **Catálogo com IDs e evidência textual funcionou como âncora de citação.** Nos 3 evals com skill, todo achado do `scan.sh` foi citado com id (`A-06`, `A-08`, `A-10`, `A-12`, `A-14`) e `arquivo:linha` corretos — a asserção mais mecânica de todas (id + localização) passou nos 3 runs com skill e falhou nos 3 sem skill.
- **Distinção entre "particionamento oculto legítimo" e antipattern.** Nos dois evals que continham `PARTITIONED BY (days(...))` em tabela Iceberg, o agente com skill não classificou como achado (seção "Julgamento" do protocolo, reforçada pela regra explícita "julgue pelo motor" no SKILL.md); sem skill, o mesmo padrão foi tratado como sinal genérico de "incremental sem unique_key" numa leitura equivocada por analogia.
- **Migração `invalidate_hard_deletes` → `hard_deletes` com valor explícito, citando dbt 1.9.** Passou nos dois evals que tocam snapshot, só com skill — é conhecimento de versão de ferramenta que não está em `best-practices.md` de forma genérica, está encapsulado no catálogo `A-14`.
- **Limiar de particionamento por produto (1 TB Databricks vs. ~10 GB/partição BigQuery) tratado sem transferência entre produtos.** A instrução literal do SKILL.md ("Limiar de produto [...] sempre com o produto nomeado: não se transfere entre produtos") apareceu quase textual no design doc gerado — efeito direto e rastreável da leitura da skill.
- **Reconhecimento de `NADA-EXAMINADO` como "não verificado", não aprovação.** Nos dois cenários que tocam esse resultado (a checagem de governança e o scanner sobre um diretório sem SQL), a skill preveniu a "aprovação por omissão" — o relatório com skill nunca certificou como limpo um universo vazio; sem skill, o agente interpretou a ausência de SQL como "revisão concluída, aprovado".

## 4. Onde o artefato atrapalhou ou ficou aquém

- **Nenhuma correção ou piora causada pela skill em si** — não há asserção que passe sem skill e falhe com skill. O risco observado é de **omissão dentro do protocolo que a própria skill define**, não de a skill induzir a um erro novo:
  - No eval `dim-passageiro-historico-delta`, o agente com skill separou PII do SCD2 corretamente, mas não ligou a tabela de PII à fato por chave substituta ou token — ligou por `id_passageiro` "natural" (documentado como pendência explícita no design doc, não escondido). A skill lista `A-02` no catálogo mas o protocolo não força a resolução da chave substituta quando ela é consequência direta de outro achado (aqui, do A-16) — fica a critério do agente adiar.
  - No mesmo eval, a eliminação do titular ficou com DELETE/UPDATE simples, sem VACUUM nem tratamento do time travel, mesmo a fixture declarando Delta explicitamente em `docs/contexto-lakehouse.md`. A seção "O que o scanner não faz" do SKILL.md cita A-15 como "consulta de runtime ou ferramenta", o que o agente leu como licença para não aprofundar, em vez de como um lembrete de que ainda precisa ser coberto manualmente quando o cenário o exige.
  - No eval `revisao-dbt-projeto-viagens`, a "tabela regra-a-regra, inclusive as limpas" (protocolo passo 5, texto explícito no SKILL.md) não saiu completa no artefato final, apesar do transcript alegar o contrário — sinal de que a instrução do passo 5 não é suficientemente operacional (não diz *onde* nem *em que formato* registrar as regras limpas) para sobreviver à pressão de produzir um relatório extenso.
  - No eval `certificar-analytics-sem-sql`, a skill orienta bem o julgamento técnico (não certificar universo vazio) mas não orienta a postura procedimental diante de um checklist de terceiro e de uma decisão de escopo que extrapola o diretório pedido — o agente decidiu sozinho, sem pausar para confirmação, e ainda assim marcou o item como concluído.
- **Tempo:** a skill aumenta o tempo de execução em ~30% (169s vs. 130s em média) pela leitura adicional do catálogo e das rules do projeto — custo esperado e proporcional ao ganho de 63 pontos percentuais de pass rate; não é um problema, mas vale registrar para quem for comparar custo/benefício de invocação.

## 5. Trechos ignorados, ambíguos ou contraditórios no artefato

- **Ambíguo — "não é regra do scanner" (passo 3) vs. exigência de cobertura no relatório (passo 5).** O SKILL.md diz que "inventário de campo pessoal [...] é item de revisão", e separadamente que A-15 (eliminação x time travel) é "consulta de runtime ou ferramenta". As duas frases dizem "isso é revisão manual", mas nenhuma diz *quando* essa revisão manual é obrigatória versus opcional. Resultado observado: o agente tratou "fora do alcance do scanner" como "posso adiar", quando o esperado (pela fixture) era tratá-lo como "ainda preciso revisar manualmente, só não pelo scanner".
- **Ambíguo — passo 5 ("uma linha por regra, inclusive as limpas") sem formato prescrito.** Sem uma estrutura mínima (ex.: tabela com colunas Regra/Status/Evidência), a instrução foi lida como atendida com uma tabela parcial (só as regras com achado) mais texto avulso — o transcript classificou isso como "tabela regra-a-regra... inclusive as que não bateram", uma autoavaliação que a evidência do artefato de saída não sustenta.
- **Ignorado — ausência de instrução sobre interação com artefatos de terceiros (checklist).** O SKILL.md não fala em nenhum momento sobre o que fazer quando o produto da varredura alimenta um checklist ou gate de outro processo (ex.: não marcar item como concluído quando o resultado é "não verificado"). Não é contradição interna da skill, é lacuna: nos dois evals que tocam um artefato de terceiro (checklist), a skill não deu instrução e o comportamento ficou por conta da inferência do agente, que decidiu marcar como feito porque "a evidência foi entregue" — leitura literal do item do checklist, não da intenção de qualidade por trás dele.
- **Sem contradição interna encontrada** entre `SKILL.md`, `references/antipatterns.md` e `references/best-practices.md` nos trechos exercitados pelos 3 evals — os achados do `scan.sh` (A-06, A-08, A-10, A-12, A-14) bateram de forma consistente com a descrição do catálogo em todos os runs.

## 6. Melhorias concretas, priorizadas

1. **[Alta] Adicionar ao protocolo (passo 5) um formato mínimo obrigatório para "uma linha por regra, inclusive as limpas"** — por exemplo, uma tabela fixa `Regra | Status (achado/limpo/não verificado) | Evidência` cobrindo A-01 a A-16, não só as regras que o `scan.sh` aciona. Isso teria discriminado melhor a asserção 5 do eval `revisao-dbt-projeto-viagens`, que falhou mesmo com skill.
2. **[Alta] Transformar "A-15 é consulta de runtime/ferramenta" em instrução condicional, não em isenção.** Reformular a seção "O que o scanner não faz" para deixar explícito que "fora do alcance do scanner" não significa "fora do escopo da revisão" — sempre que o achado do catálogo for diretamente relevante ao pedido do usuário (aqui, eliminação de titular + Delta explícito na fixture), a skill deveria instruir a cobrir manualmente (VACUUM/retenção de time travel) em vez de apenas registrar como pendência a decidir depois.
3. **[Média] Adicionar uma regra de postura procedimental para artefatos de terceiro (checklists, gates de outro processo)**: nunca marcar um item de checklist como concluído quando a evidência produzida é "não verificado" ou parcial; e, ao decidir ampliar o escopo da varredura para além do diretório pedido pelo usuário (como aconteceu com `analytics/` → `warehouse/`), registrar a decisão como pendente de confirmação do usuário em vez de resolvê-la e fechar o item sozinho. Isso teria corrigido as duas asserções não discriminantes do item 2.
4. **[Média] Amarrar A-02 (chave substituta) a A-16 (PII fora do SCD2) no catálogo.** Quando a correção de A-16 move atributos pessoais para uma tabela separada, o protocolo deveria lembrar explicitamente de verificar se a ligação entre essa tabela e a fato/dimensão usa chave substituta ou token — hoje o catálogo trata os dois como achados independentes, e a consequência (A-16 resolvido "descobre" um A-02 novo) fica por conta da atenção do agente.
5. **[Baixa] Nenhuma mudança indicada no `scan.sh`** — os 5 detectores estáticos (A-06, A-08, A-10, A-12, A-14) tiveram 100% de precisão nos 3 fixtures, sem falso positivo nem falso negativo registrado nos transcripts.
