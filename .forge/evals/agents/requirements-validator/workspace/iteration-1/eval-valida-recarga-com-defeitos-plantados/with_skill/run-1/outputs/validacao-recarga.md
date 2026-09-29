# Validação do requirements.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 8
- Total de achados HIGH: 3
- Total de achados MEDIUM: 1
- Total de achados LOW: 0

## Veredito

O documento não está pronto para alimentar o `design.md`. Há oito achados BLOCKER — numeração de requisitos quebrada, seção obrigatória ausente, versionamento inconsistente com o histórico, requisito sem origem, invasão massiva de design técnico (inclusive contradizendo um ADR aceito), critério de aceite subjetivo, RNF genérico e PBTs mal formulados. Nenhum destes é um "detalhe": cada um bloqueia por si só o avanço no pipeline, conforme os critérios de aprovação deste agente. Como o papel do `requirements-validator` é revisar e apontar, não reescrever o `requirements.md` (e seu conjunto de ferramentas autorizado é somente leitura — Read/Glob/Grep, sem Edit/Write), a correção direta solicitada pelo usuário não foi aplicada; o documento é devolvido ao `requirements-writer` para nova execução.

## Achados

### [BLOCKER-01] Numeração de requisitos funcionais quebrada

**Local:** Seção "Requisitos Funcionais" — Req 1, Req 2, Req 4, Req 5
**Problema:** Falta o Req 3. A numeração salta de 2 para 4, sem requisito removido ou renumeração documentada.
**Impacto:** Rastreabilidade quebrada; cross-refs futuros e o `design.md` podem referenciar um "Req 3" inexistente ou presumir remoção não registrada.
**Correção recomendada:** Renumerar os requisitos de forma contínua (1, 2, 3, 4) ou, se um requisito foi de fato removido, registrar isso explicitamente no Histórico de Versões com o motivo.

### [BLOCKER-02] Seção obrigatória "Fora do escopo do MVP" ausente

**Local:** Documento inteiro (seção esperada após "Glossário local")
**Problema:** A seção "Fora do escopo do MVP" não existe no `requirements.md`, apesar de estar na lista de seções obrigatórias e de já existir conteúdo equivalente no `README.md` do módulo ("Recarga por boleto e cartão de crédito").
**Impacto:** Escopo do MVP fica implícito; `design.md` e `tasks.md` correm risco de cobrir capacidades fora do MVP por falta de exclusão explícita na fonte de verdade.
**Correção recomendada:** Adicionar a seção "Fora do escopo do MVP" ao `requirements.md`, trazendo (e confirmando) o conteúdo já presente no README do módulo.

### [BLOCKER-03] Versão do cabeçalho sem entrada correspondente no Histórico de Versões

**Local:** Cabeçalho (Versão 1.1.0, 2026-09-18) vs. Histórico de Versões (última linha: 1.0.0, 2026-09-02)
**Problema:** O documento está em `Aprovado para desenvolvimento` e o cabeçalho indica versão 1.1.0, mas o Histórico de Versões não tem nenhuma linha para 1.1.0 explicando a alteração (adição do Req 5 — recarga agendada). Pela regra de versionamento (`.forge/rules/conventions/document-versioning.md`), documento aprovado exige bump com histórico correspondente a cada alteração.
**Impacto:** Não há rastro de por que e quando o requisito de recarga agendada entrou; quebra a auditabilidade do documento aprovado.
**Correção recomendada:** Adicionar linha ao Histórico de Versões para 1.1.0 / 2026-09-18, descrevendo "Adição do Req de recarga agendada recorrente (pedido do comercial)".

### [BLOCKER-04] Req 4 sem campo "Origem"

**Local:** Req 4 — Estornar recarga não creditada, tabela de metadados
**Problema:** A tabela do Req 4 tem apenas **Prioridade** e **Módulo**; falta a linha **Origem**, exigida em todo requisito.
**Impacto:** Requisito sem origem rastreável — não é possível verificar de onde veio a necessidade de estorno nem justificar prioridade "Should".
**Correção recomendada:** Adicionar **Origem** ao Req 4 (ex.: decisão operacional, PRD, ou ticket de suporte que motivou o requisito).

### [BLOCKER-05] Req 1.3 invade design técnico e contradiz ADR-0002

**Local:** Req 1, critério 1.3
**Problema:** O critério especifica nome de tabela (`tb_recarga_pix`), nome e tipo de coluna (`vl_recarga NUMERIC(10,2)`) e biblioteca de mensageria (`spring-kafka`) — decisões de design/implementação que não cabem em `requirements.md`. Além disso, `NUMERIC(10,2)` contradiz a ADR-0002 (aceita), que exige `Money` em centavos como `long`/`BIGINT`, proibindo `decimal`/`float`/`double` em valores monetários.
**Impacto:** `design.md` herdaria uma decisão de schema já tomada de forma incorreta e inconsistente com uma ADR vigente, arriscando divergência de conciliação (o mesmo problema que motivou a ADR-0002).
**Correção recomendada:** Reescrever o critério em nível de requisito, por exemplo: "A cobrança gerada deve ser persistida de forma auditável e um evento de domínio deve ser publicado de forma assíncrona quando a cobrança for criada, respeitando ADR-0002 (valores em centavos) e ADR-0003 (mensageria via outbox)." Detalhes de tabela/coluna/biblioteca ficam para o `design.md`.

### [BLOCKER-06] Req 2.3 é critério de aceite subjetivo e não atômico

**Local:** Req 2, critério 2.3
**Problema:** "A tela de recarga deve ser intuitiva e o crédito deve aparecer rápido" mistura duas condições (UX subjetiva + tempo de resposta) e usa linguagem não verificável ("intuitiva", "rápido").
**Impacto:** Critério não pode ser convertido em teste; abre espaço para interpretação divergente entre design e QA.
**Correção recomendada:** Remover a menção a "intuitiva" (é preocupação de design de interface, não de requirements) e transformar "rápido" em critério mensurável, ex.: "O saldo creditado deve ficar visível na Carteira em até N segundos após a confirmação do PSP."

### [BLOCKER-07] RNF-02 genérico e não mensurável

**Local:** Requisitos Não-Funcionais — RNF-02 (Performance)
**Problema:** "O sistema deve ser performático e escalável" é exatamente um dos exemplos de RNF a ser bloqueado pelo próprio checklist deste agente — sem métrica, limite ou percentual.
**Impacto:** Não é possível verificar conformidade nem definir SLO/SLA para o módulo.
**Correção recomendada:** Substituir por métrica objetiva, ex.: "O crédito na Carteira deve ocorrer em até 5 segundos após a confirmação do PSP em 95% dos casos (p95)."

### [BLOCKER-08] PBTs mal formulados

**Local:** Property-Based Testing — PBT-01 e PBT-02
**Problema:** PBT-01 não tem o campo **Mapeia para:** (obrigatório pelo template — PBT sem requisito associado explícito, embora o nome sugira Req 2). PBT-02 mapeia para Req 1.1, mas a propriedade descrita ("O sistema deve funcionar bem com valores de recarga") é vaga, não é uma invariante verificável e apenas ecoa o mesmo tipo de generalidade do RNF-02.
**Impacto:** PBTs não formulados como invariante não podem virar teste de propriedade real; perdem o propósito de PBT.
**Correção recomendada:** Em PBT-01, adicionar "**Mapeia para:** Req 2.1". Em PBT-02, reformular como invariante testável, ex.: "Para qualquer valor de recarga fora do intervalo [500, 50000] centavos, a geração da cobrança Pix deve ser rejeitada; para qualquer valor dentro do intervalo, a cobrança deve ser gerada com o mesmo valor solicitado."

## Achados HIGH

### [HIGH-01] Persona "Fiscal de catraca" não existe na seção Personas/Atores

**Local:** Req 4, critério 4.2
**Problema:** O critério cita "Fiscal de catraca" solicitando estorno em nome do Passageiro, mas essa persona não está listada em "Personas / Atores" (que só lista Passageiro, Operador de SAC e PSP) nem no glossário de domínio.
**Impacto:** Ambiguidade sobre quem de fato pode solicitar o estorno; risco de o `design.md` modelar uma permissão para um ator não definido.
**Correção recomendada:** Adicionar "Fiscal de catraca" à seção de Personas com uma descrição, ou corrigir o critério para usar "Operador de SAC", que já está listado e é coerente com o restante do Req 4.

### [HIGH-02] Uso da abreviação "VO" em vez de "objeto de valor"

**Local:** Req 2, critério 2.2
**Problema:** "O crédito usa o VO Money em centavos" usa a sigla "VO", violando a convenção de linguagem (`.forge/rules/conventions/language-policy.md` / `naming.md`), que exige "objeto de valor" por extenso.
**Impacto:** Inconsistência terminológica que se propaga para `design.md` se não corrigida na fonte.
**Correção recomendada:** Reescrever para "O crédito usa o objeto de valor Money em centavos."

### [HIGH-03] README do módulo desatualizado em relação ao requirements.md

**Local:** `docs/product/modules/recarga/README.md`
**Problema:** O README indica `requirements.md` em "Rascunho para revisão", versão 0.1.0, 2026-08-20, e lista só Passageiro e Operador de SAC como personas. O `requirements.md` real está em "Aprovado para desenvolvimento", versão 1.1.0, 2026-09-18, e inclui a persona PSP.
**Impacto:** Qualquer pessoa ou agente que consulte primeiro o README recebe um retrato defasado do estado real do módulo.
**Correção recomendada:** Atualizar a tabela de status do README (status, versão, data) e a lista de personas principais para refletir o `requirements.md` v1.1.0.

## Achados MEDIUM

### [MEDIUM-01] Cross-ref ausente entre PBT-02 e a faixa completa do Req 1

**Local:** PBT-02
**Problema:** PBT-02 mapeia apenas para "Req 1.1" (o critério de faixa de valor), mas, ao ser reformulado como invariante testável (ver BLOCKER-08), também tocará o comportamento de rejeição da cobrança, que hoje não tem critério de aceite próprio em Req 1.
**Impacto:** Menor — não bloqueia, mas indica lacuna a fechar quando o Req 1 for revisado.
**Correção recomendada:** Ao corrigir PBT-02, considerar adicionar um critério de aceite explícito em Req 1 para o caso de valor fora da faixa (hoje só o limite é citado, não o comportamento de rejeição).

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 2.000 linhas | OK (132 linhas) |
| Estrutura obrigatória | Falhou (falta "Fora do escopo do MVP") |
| Metadados e versionamento | Falhou (versão sem histórico correspondente) |
| Requisitos funcionais | Falhou (numeração quebrada, Req 4 sem origem, Req 1.3 invade design) |
| Requisitos não-funcionais | Falhou (RNF-02 genérico) |
| Critérios de aceite | Falhou (Req 2.3 subjetivo) |
| PBTs | Falhou (PBT-01 sem mapeamento, PBT-02 vago) |
| Glossário e linguagem | Falhou (uso de "VO", persona não definida) |
| Separação requirements/design | Falhou (Req 1.3) |
| README sincronizado | Falhou (desatualizado) |

## Recomendações para o requirements-writer

1. Corrigir a numeração dos Req (fechar o furo do Req 3) e adicionar a seção "Fora do escopo do MVP".
2. Adicionar entrada de 1.1.0 no Histórico de Versões e o campo Origem no Req 4.
3. Reescrever Req 1.3 (remover tabela/coluna/biblioteca, alinhar com ADR-0002/ADR-0003), Req 2.3 (tornar mensurável) e RNF-02 (métrica objetiva).
4. Corrigir PBT-01 (mapeamento) e PBT-02 (invariante testável); resolver a persona "Fiscal de catraca" (adicionar ou trocar por "Operador de SAC"); trocar "VO" por "objeto de valor"; sincronizar o README do módulo.

## Decisão para o Pipeline

- Pode seguir para `design.md`: Não
- Pode seguir para `tasks.md`: Não
- Requer nova execução do `requirements-writer`: Sim
