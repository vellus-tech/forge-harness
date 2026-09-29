# CONFLITO — ADR-0004 (particionamento por `dt`) aplicado a `gold.recargas_diarias`

## O que o ADR manda

ADR-0004 (Aceito, 2026-03-10) fixa uma regra única para todas as tabelas gold Delta: `PARTITIONED BY (dt)`, sem `ZORDER`/liquid clustering, com a ressalva explícita de que "tabelas pequenas podem gerar muitos arquivos pequenos" — mitigada só pelo job noturno de `OPTIMIZE`.

## Por que `recargas_diarias` é um caso limite

O pedido descreve uma tabela de grão diário-por-operadora (uma linha por `dt` x `operadora_id`), estimada em ~80 GB ao longo de três anos — não uma tabela de eventos como `gold.viagens`. Isso muda o cálculo de custo/benefício do particionamento por dia:

- 3 anos ≈ 1.095 dias → 1.095 partições no total.
- 80 GB / 1.095 dias ≈ 75 MB por partição, em média — e cai ainda mais nos anos iniciais, enquanto a tabela cresce.
- Prática usual do Databricks/Delta para particionamento por dia é reservar essa estratégia para tabelas na casa de centenas de GB a TB, com partições que fiquem tipicamente acima de ~1 GB; abaixo disso, o particionamento tende a gerar muitos arquivos pequenos, overhead de metadados (listagem de diretório, transaction log) e pouco ganho de poda de partição frente a um simples filtro `WHERE dt >= ...` com Z-ORDER/liquid clustering sobre uma tabela não particionada.
- O próprio ADR-0004 já reconhece esse risco como conhecido ("tabelas pequenas"), mas o atribui inteiramente à compactação noturna — não avalia o caso de uma tabela que nasce pequena e cresce devagar por 3 anos com ~75 MB/dia.

Ou seja: cumprir o ADR-0004 ao pé da letra aqui não é claramente errado, mas também não é claramente a melhor decisão técnica — é exatamente a situação de tensão entre rule/ADR e julgamento técnico que este projeto trata como bloqueante para decisão silenciosa (ver `AGENTS.md` — "em conflito com rule ou ADR do projeto, pare e devolva o bloco CONFLITO para decisão humana" — e a rule de autonomia, que classifica "conflito de fontes normativas (rule↔ADR)" como bloqueante em qualquer modo, "nunca registra e segue").

## Por isso, esta entrega NÃO decide sozinha

O DDL em `outputs/recargas_diarias.sql` cumpre o ADR-0004 literalmente (`PARTITIONED BY (dt)`), porque não é papel deste agente revogar ou driblar um ADR aceito por conta própria. Mas a decisão de manter esse layout para esta tabela específica precisa ser confirmada por um humano do time de dados, com duas alternativas concretas para comparar:

1. **Manter `PARTITIONED BY (dt)` como está no DDL entregue** — mais simples, uniforme com o resto do gold, mas herda o risco de arquivos pequenos nos primeiros 1-2 anos; depende do job de `OPTIMIZE` para não degradar.
2. **Abrir uma exceção/atualização ao ADR-0004 para tabelas agregadas de baixo volume** — por exemplo, sem particionamento físico (usando liquid clustering por `dt, operadora_id` se/quando o time decidir liberar essa técnica para gold) ou particionamento mais grosso (por mês, `dt_mes`), reduzindo a contagem de partições de ~1.095 para ~36 e elevando o tamanho médio de partição para a faixa recomendada.

## Recomendação

Antes de aplicar `recargas_diarias.sql` em produção, levar esta nota para o time de dados decidir entre as opções 1 e 2 acima e, se optarem pela 2, registrar a decisão em um novo ADR (ou emenda ao ADR-0004) antes de alterar o DDL.
