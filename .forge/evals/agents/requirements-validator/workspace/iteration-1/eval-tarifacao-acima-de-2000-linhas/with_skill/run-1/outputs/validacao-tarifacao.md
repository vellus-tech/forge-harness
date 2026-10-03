# Validação do requirements.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 1
- Total de achados HIGH: 0
- Total de achados MEDIUM: 0
- Total de achados LOW: 0

## Veredito

O arquivo `docs/product/modules/tarifacao/requirements.md` tem 2.448 linhas, acima do limite de 2.000 linhas definido na Regra Especial de Tamanho deste validador. Por regra do agente, a revisão detalhada de conteúdo (estrutura, critérios de aceite, PBTs, versionamento, glossário) é bloqueada quando esse limite é ultrapassado, independentemente da qualidade do conteúdo. Por isso, **não revisei os Req 1 a 20 item a item** — fazê-lo violaria a regra de tamanho, que existe justamente para não normalizar documentos deste porte como unidade de revisão. Documento grande demais é sinal estrutural de baixa coesão e risco de requisitos acoplados, e é isso que está ocorrendo aqui: 170 requisitos quase idênticos (um por linha de ônibus) foram enfileirados num único arquivo.

O argumento de que "é um módulo só, não dá para quebrar" confunde dois conceitos distintos. A regra pede decomposição do **arquivo `requirements.md`**, não do módulo de produto no pipeline SDD — Tarifação continua sendo um módulo único, com um `design.md` e um `tasks.md` também únicos. O catálogo de 170 linhas pode e deve ser quebrado em documentos menores por agrupamento funcional (ex.: por operadora — Viação Leste, TransNorte, Expresso Sul — ou por faixa de linhas), com um `requirements.md` principal do módulo contendo visão geral, escopo, personas, RNFs, PBTs, glossário e referências cruzadas, e os catálogos tarifários por operadora/linha vivendo em sub-arquivos referenciados (ex.: `docs/product/modules/tarifacao/tarifas/viacao-leste.md`) ou, alternativamente, extraídos para uma fonte de dados estruturada (tabela/CSV/JSON versionado) com o `requirements.md` descrevendo a regra de negócio uma única vez (formato + exceções) e referenciando a fonte, em vez de repetir a mesma estrutura de requisito 170 vezes. Essa segunda opção é provavelmente a mais correta aqui: os 170 requisitos analisados na amostra (Req 1, 2, 168, 169, 170) têm o mesmo padrão estrutural exato, variando apenas linha, operadora e o número — isto é forte indício de que não são 170 requisitos de negócio distintos, e sim uma regra de negócio única ("tarifa por linha, definida em tabela") multiplicada por linha, o que é dado de configuração, não requisito funcional individual.

## Achados

### [BLOCKER-01] Arquivo acima de 2.000 linhas

**Local:** `docs/product/modules/tarifacao/requirements.md` (2.448 linhas)
**Problema:** O documento excede o limite de 2.000 linhas da Regra Especial de Tamanho. Contém 170 Requisitos Funcionais quase idênticos (Req 1 a Req 170), um por linha de ônibus, cada um repetindo a mesma estrutura (user story, tabela de metadados, 2 critérios de aceite) variando apenas número da linha, operadora e valores.
**Impacto:** Revisão detalhada bloqueada por regra do agente. Documento deste tamanho é difícil de manter, revisar e versionar; qualquer reajuste de tarifa (evento operacional recorrente, citado no próprio RNF-02) forçaria reescrever/renumerar parte de um arquivo de milhares de linhas. Também eleva o risco de os agentes de `design.md`/`tasks.md` (com janela de contexto limitada) processarem o documento de forma incompleta ou inconsistente.
**Correção recomendada:** Decompor o arquivo em documentos menores por agrupamento funcional (ver Veredito). Recomendação preferencial: extrair o catálogo tarifário (linha → operadora → valor base/noturno) para uma fonte estruturada versionada (ex.: `docs/product/modules/tarifacao/tarifas.csv` ou tabela em `design.md`/dado de configuração), e reescrever os Req 1–170 como um número pequeno de requisitos de regra de negócio (ex.: "Req 1 — Tarifa por linha e faixa horária conforme tabela vigente", "Req 2 — Integração temporal de 90 minutos"), com a tabela completa referenciada, não embutida requisito a requisito. Alternativa aceitável, se a granularidade por linha for mesmo necessária como requisito individual: dividir em sub-documentos por operadora (`tarifacao/viacao-leste/requirements.md`, `tarifacao/transnorte/requirements.md`, `tarifacao/expresso-sul/requirements.md`) mantendo o módulo Tarifação único no pipeline (um `design.md`/`tasks.md` consolidando os três).

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 2.000 linhas | Falhou (2.448 linhas) |
| Estrutura obrigatória | Não verificado (bloqueado pela regra de tamanho) |
| Metadados e versionamento | Não verificado (bloqueado pela regra de tamanho) |
| Requisitos funcionais | Não verificado (bloqueado pela regra de tamanho) |
| Requisitos não-funcionais | Não verificado (bloqueado pela regra de tamanho) |
| Critérios de aceite | Não verificado (bloqueado pela regra de tamanho) |
| PBTs | Não verificado (bloqueado pela regra de tamanho) |
| Glossário e linguagem | Não verificado (bloqueado pela regra de tamanho) |
| Separação requirements/design | Não verificado (bloqueado pela regra de tamanho) |
| README sincronizado | OK (README reflete status Rascunho para revisão, versão 0.4.0, data 2026-09-21, consistente com o cabeçalho do requirements.md) |

## Recomendações para o requirements-writer

1. Extrair o catálogo de tarifas por linha (170 blocos quase idênticos) para uma fonte estruturada versionada, mantendo no `requirements.md` apenas a regra de negócio (formato de tarifa por linha/faixa horária, regra de integração de 90 minutos) descrita uma única vez.
2. Se a extração para fonte estruturada não for aceita, dividir o arquivo em sub-documentos por operadora (Viação Leste, TransNorte, Expresso Sul), cada um abaixo de 2.000 linhas, preservando um único módulo Tarifação no pipeline SDD.
3. Depois da decomposição, resubmeter para nova execução do `requirements-validator`, que então fará a revisão de conteúdo completa (estrutura, critérios de aceite, PBTs, versionamento, glossário) hoje bloqueada pelo tamanho.

## Decisão para o Pipeline

- Pode seguir para `design.md`: Não
- Pode seguir para `tasks.md`: Não
- Requer nova execução do `requirements-writer`: Sim
