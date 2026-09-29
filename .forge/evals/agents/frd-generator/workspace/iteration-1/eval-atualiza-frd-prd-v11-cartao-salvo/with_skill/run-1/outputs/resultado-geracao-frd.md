# Resultado da Geração do FRD

## 1. Arquivos Criados ou Atualizados

| Arquivo | Ação |
|---|---|
| docs/product/frd-nfrd/frd.md | Atualizado (v1.0 → v1.1) |

## 2. Módulos Funcionais Identificados

| Código | Módulo | Quantidade de Requisitos |
|---|---|---|
| MOD-01 | Conta (acc) | 2 (inalterado) |
| MOD-02 | Recarga (rec) | 6 (4 preexistentes + 2 novos: FRD-rec-05, FRD-rec-06) |

## 3. Quantidade de Requisitos

| Tipo | Quantidade |
|---|---|
| Requisitos Funcionais | 8 (6 preexistentes + 2 novos) |
| Casos de Uso | 0 novos (fixture não detalha UC; mantido como estava) |
| Regras de Negócio | 4 (3 preexistentes + BR-04 novo) |
| Mensagens | 4 (2 preexistentes + MSG-003, MSG-004 novas) |
| Pontos a Validar | 3 (VAL-01, VAL-02 preexistentes + VAL-03 novo) |

## 4. Principais Pontos a Validar

- VAL-01 — Valor máximo por recarga (preexistente, PRD RN-04, pendente do jurídico).
- VAL-02 — Prazo para abrir contestação (preexistente, PRD §8).
- VAL-03 — Número de tentativas/retentativa e prazo de suspensão do agendamento após falha de cobrança automática recorrente (PRD F-07 não detalha; novo).

## 5. Observações

- Nenhum requisito, regra ou mensagem preexistente (FRD-acc-01, FRD-acc-02, FRD-rec-01..04, BR-01..03, MSG-001..002) foi renumerado, removido ou teve sua descrição alterada — verificado por grep linha a linha antes da entrega, para não quebrar os casos de teste de QA que referenciam esses códigos.
- F-07 do PRD v1.1 foi modelado como dois requisitos separados (FRD-rec-05 para configurar o agendamento, FRD-rec-06 para pausar/cancelar) porque o PRD já descreve dois comportamentos distintos e testáveis dentro da mesma funcionalidade.
- RN-05 (tokenização PCI DSS) virou BR-04, referenciada tanto por FRD-rec-05 quanto por FRD-rec-06.
- Matriz de rastreabilidade (§16) ganhou duas linhas: F-07 → FRD-rec-05/06, e RN-05 → BR-04 (regra de negócio explícita do PRD também rastreada).

## 6. ADRs Sugeridos (delegação a adr-writer)

| ID sugerido | Título proposto | Origem (RF/UC/BR/PRD) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-0004 | politica-de-tokenizacao-cartao-salvo-pci-dss | BR-04 (PRD RN-05) | Alta | RN-05 cria uma política transversal de compliance (PCI DSS) que o próprio PRD declara valer "para qualquer funcionalidade futura que cobre cartão salvo" — é precedente regulatório vinculante (gatilho §11.1.3 e §11.1.5 do agente frd-generator), não um detalhe interno de um módulo, e deve ser registrado como decisão arquitetural formal antes da implementação de FRD-rec-05/06. |
