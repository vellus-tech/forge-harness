# Análise de benchmark — agente `trd-generator`

Iteração avaliada: `workspace/iteration-1` (3 casos × 2 configurações × 1 run cada). Agregação gerada por `scripts.aggregate_benchmark` (determinística, sem edição manual) em `workspace/iteration-1/benchmark.json` / `benchmark.md`; viewer estático em `workspace/iteration-1/review.html`.

## 1. Resultado agregado

| Configuração | Pass rate (média) | Min–Max | Tempo médio |
|---|---|---|---|
| Com skill (agente) | 77,7% | 50%–100% | 344,7 s |
| Sem skill (baseline) | 30,0% | 16,7%–40,0% | 125,7 s |
| **Delta** | **+0,48** | | +219 s |

`benchmark_ok = true` — o script rodou de primeira, sem erro de estrutura, sobre os três casos (`trd-completo-tarifa-aberta`, `trd-layout-legado-sem-nfrd`, `recusa-rabbitmq-e-pipeline-fora-do-trd`).

**Veredito: agrega** (delta +0,48 ≥ 0,15). O agente não só passa mais asserções em média como cobre integralmente um dos três casos (recusa, 5/5), enquanto o baseline nunca ultrapassa 40% em nenhum caso.

Ressalva de metodologia: 1 run por configuração/caso é amostra mínima — a stddev (0,25 com skill, 0,12 sem) reflete variação entre casos, não entre runs repetidas do mesmo caso. O veredito é direcionalmente sólido (a distância entre configurações é grande e consistente nos três casos), mas não há evidência de estabilidade run-a-run.

## 2. Onde o agente ajudou (evidência de transcript/grading)

- **Nome e local canônicos do arquivo.** Nos três casos, sem a especificação o executor produziu `docs/product/trd/trd-tarifa-aberta.md` (ou variante) em vez de `docs/product/trd/trd.md`. Com a especificação, o nome e o caminho saem corretos nos três — é a asserção mais "barata" de virar 0%→100% e sozinha já derruba metade das checagens de cada caso sem skill.
- **Refusal disciplinado no caso "recusa-rabbitmq".** O baseline sem skill *também* recusou trocar Kafka por RabbitMQ e recusou gerar CI/CD/compose (raciocínio correto, registrado no transcript), mas não formatou a recusa do jeito que os avaliadores checam: sem a marcação literal "Conflito Arquitetural", sem `VAL-TRD-NN` rastreável, sem a seção "CI/CD e Qualidade Técnica" com tabela de etapas. Com skill, as 5/5 asserções passam — a especificação não ensinou a *decisão* (o baseline já acertava), ensinou a *forma* exigida pelo contrato do documento.
- **Convenção de rotas de API e estilo arquitetural.** No caso "layout-legado", com skill as rotas seguem `/api/v1/<resource>` kebab-case e o estilo (monólito modular do ADR-0001) é adotado corretamente; sem skill, rotas falham.
- **Seção "Pontos a Validar" para lacunas de insumo (NFRD ausente).** Só o agente com skill registra a ausência do NFRD como `VAL-TRD-NN` com metas tratadas como não confirmadas.

## 3. Onde o agente atrapalhou ou não fechou (evidência)

- **Convenção `TRD-<CAT>-NN` não aparece nenhuma vez no TRD do caso "tarifa-aberta".** `grep` por `TRD-(ARCH|API|EVT|DATA|...)-[0-9]{2}` retorna vazio em `trd.md`, apesar de a seção 9.1 do artefato (linhas 1206–1241) definir o padrão e dar exemplos (`TRD-ARCH-01`, `TRD-API-01`...). O agente usou `RISK-TRD-NN` e `VAL-TRD-NN` (esses sim exigidos e presentes), mas nunca os códigos de requisito técnico propriamente ditos. **Causa raiz no artefato:** a seção 9.1 chama as categorias de "sugeridas" e nenhum template de seção (4, 7, 9, 10...) tem uma coluna ou instrução explícita "todo requisito técnico desta seção deve ter um código `TRD-CAT-NN`". A convenção existe isolada em uma seção de nomenclatura e nunca é amarrada como obrigação nos templates de corpo — por isso o executor a trata como decorativa.
- **Nomeação de eventos particípio-passado violada em 1 de 7 linhas** (`settlement.mismatch.v1` — substantivo, não particípio) no mesmo caso. Indica que o exemplo do padrão (`tap.captured.v1`) está claro, mas não há checklist de auto-revisão no artefato pedindo para o próprio agente validar cada linha do Event Catalog contra o regex antes de finalizar.
- **Vocabulário de Status na Matriz de Rastreabilidade extrapolado.** O agente escreveu `"Coberto — com Ponto a Validar sobre..."` em vez de `"Parcial"` — o valor correto já existe no vocabulário fechado do artefato, mas o agente preferiu compor uma frase explicativa em vez de usar o rótulo fechado. Sintoma de que o artefato não é explícito o bastante em dizer "a coluna Status usa **apenas** um destes três valores literais, sem texto adicional".
- **Recomendação de migração de layout fora da tabela rastreável.** No caso "layout-legado", o agente recomenda a migração de `docs/prd`/`docs/frd`/`docs/adr` para `docs/product/` em prosa (seção 22) mas não como linha `VAL-TRD-NN` da tabela — mesma classe de problema: o artefato pede a recomendação mas não amarra explicitamente que ela precisa virar linha de tabela codificada.

## 4. Asserção não discriminante

- `git diff HEAD` vazio fora de `docs/product/trd/` — passa em **6/6** execuções (as duas configurações, os três casos). Não diferencia o valor da skill; é uma checagem de segurança/blast-radius, não de qualidade de conteúdo. Válida para manter (é a rede de segurança contra o agente tocar insumos), mas não deveria contar para "cobertura" do artefato em uma leitura de pass-rate por assertividade de conteúdo.

## 5. Qualidade dos próprios casos (`eval_quality`)

Boa, com uma ressalva. Pontos fortes: as três asserções por caso são checáveis por grep/diff determinístico (grading.json cita linha exata e comando usado), cobrem tanto conteúdo positivo quanto blast-radius negativo, e o terceiro caso testa especificamente um cenário de recusa/conflito — o tipo de caso que mais separa um agente disciplinado de um genérico. Ressalva: a asserção de VAL-TRD sobre "paths legados" no caso 2 é a mais próxima de nitpick — o agente cumpriu a intenção (recomendou a migração, na seção correta) e falhou só no formato de linha de tabela; é uma falha real do artefato (ele não amarra a exigência), mas o peso da asserção no pass-rate agregado (1/6 nesse caso) é proporcional a uma falha de forma, não de substância. Não achei asserção quebrada, ambígua ou logicamente inconsistente com o próprio artefato.

Uma limitação do harness, não do artefato: `tokens`/`tool_calls` vêm zerados em todos os 6 runs (`timing.json` só grava `total_tokens: 0`), o que impede avaliar custo real de contexto do agente — só o tempo de parede é confiável como métrica de custo aqui.

## 6. Melhorias concretas priorizadas no artefato (`trd-generator.md`)

1. **(Alto impacto, baixo custo) Amarrar a convenção `TRD-<CAT>-NN` como obrigação, não sugestão.** Na seção 9.1, trocar "Categorias sugeridas" por "categorias obrigatórias" e adicionar, em cada template de seção que produz requisitos técnicos (4, 7, 9, 10, 11, 12, 13, 14...), uma linha explícita: "todo requisito técnico definido nesta seção recebe um código `TRD-<CAT>-NN` correspondente". Sem isso o padrão fica isolado e o executor o ignora, como visto no caso 1.
2. **(Alto impacto, baixo custo) Fechar o vocabulário da coluna Status da Matriz de Rastreabilidade.** Adicionar ao template da seção 20: "a coluna Status contém **exatamente** um destes três valores, sem texto adicional: `Coberto`, `Parcial`, `Não Coberto`; ressalvas específicas vão em nota de rodapé da tabela ou na coluna Observações, nunca dentro do valor de Status."
3. **(Médio impacto, baixo custo) Adicionar passo de auto-revisão do Event Catalog.** Ao final do Passo 5 (linha ~444), incluir instrução para o agente conferir, linha a linha, se o nome do evento casa com o regex `^[a-z-]+\.[a-z-]+(ado|ido)\.v[0-9]+$` antes de fechar a seção — evita nomes como `mismatch` que escapam de particípio passado.
4. **(Médio impacto) Amarrar recomendações textuais de "Pontos a Validar" à tabela.** Onde o artefato instrui o agente a registrar uma lacuna/decisão pendente em prosa (ex.: migração de layout legado, decisão de broker), adicionar uma frase de fechamento: "toda recomendação ou decisão em aberto desta seção também vira uma linha `VAL-TRD-NN` na tabela de Pontos a Validar (seção 22), com o código citado no texto em prosa." Isso teria corrigido tanto a falha do caso 1 (migração de layout) quanto reforçado o padrão já correto do caso 3 (Conflito Arquitetural).
5. **(Baixo impacto, script a embutir) Script de auto-checagem opcional.** Os quatro pontos acima são todos verificáveis por grep/regex determinístico (códigos `TRD-CAT-NN` presentes, Status ∈ {Coberto,Parcial,Não Coberto}, Event Catalog casa o regex, toda seção "Pontos a Validar"/prosa tem `VAL-TRD-NN` correspondente). Vale considerar embutir um script leve de lint pós-geração (bash/grep, sem custo de token) que o próprio agente roda antes de declarar a tarefa concluída — mesmo padrão que a asserção 6 (git diff) já valida por fora; aqui entraria por dentro do processo do agente.
6. **Não mexer:** a estrutura de seções (1–22), a divisão em "Passos", os exemplos de nomenclatura e a exigência de rastreabilidade em si já funcionam bem — as três lacunas acima são de "amarração" (a regra existe mas não é cobrada no lugar certo), não de ausência de conteúdo.
