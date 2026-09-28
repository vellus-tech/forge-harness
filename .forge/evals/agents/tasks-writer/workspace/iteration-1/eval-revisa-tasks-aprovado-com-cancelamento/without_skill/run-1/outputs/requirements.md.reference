# Requirements — ROT — Estacionamento Rotativo Digital

- Versão: 1.2.0
- Data: 2026-09-22
- Status: Aprovado

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-09-03 | Aprovado | Versão inicial aprovada |
| 1.1.0 | 2026-09-10 | Aprovado | Inclusão do RNF 2 (mascaramento de placa em logs) |
| 1.2.0 | 2026-09-22 | Aprovado | Inclusão do Req 4 (cancelamento com estorno proporcional) e PBT-04 |

## Requisitos Funcionais

### Req 1 — Comprar ativação

Como motorista, quero comprar uma ativação informando placa, zona e minutos, para estacionar regularmente.

- 1.1 O sistema DEVE debitar da carteira `minutos × tarifa_por_minuto` da zona.
- 1.2 O sistema DEVE rejeitar com ROT-001 quando o saldo for insuficiente.
- 1.3 O sistema DEVE rejeitar com ROT-002 quando os minutos excederem o tempo máximo da zona.
- 1.4 Requisições repetidas com a mesma `Idempotency-Key` DEVEM retornar a mesma ativação sem novo débito.

### Req 2 — Estender ativação

Como motorista, quero estender uma ativação vigente, para não receber autuação.

- 2.1 A soma de minutos da ativação e extensões NÃO DEVE exceder o tempo máximo da zona (ROT-002).
- 2.2 Extensão de ativação expirada ou cancelada DEVE ser rejeitada com ROT-003.

### Req 3 — Consultar ativações por placa

Como fiscal, quero consultar as ativações vigentes de uma placa, para decidir sobre autuação.

- 3.1 A consulta DEVE retornar apenas ativações com estado `Ativa` no instante da consulta.
- 3.2 A consulta DEVE exigir o escopo OAuth `fiscalizacao:read`.

### Req 4 — Cancelar ativação com estorno proporcional

Como motorista, quero cancelar uma ativação vigente e receber de volta os minutos não usados, para não pagar pelo que não usei.

- 4.1 O estorno DEVE creditar na carteira `floor(minutos_restantes) × tarifa_por_minuto` da zona.
- 4.2 Cancelamento de ativação não vigente DEVE ser rejeitado com ROT-003.
- 4.3 Cancelamento DEVE publicar o evento `AtivacaoCancelada`.

## Requisitos Não Funcionais

- **RNF 1 — Latência:** p95 de `POST /v1/ativacoes` abaixo de 300 ms com 200 req/s.
- **RNF 2 — Privacidade:** logs e traces NUNCA DEVEM conter a placa completa; apenas os 3 últimos caracteres.

## Propriedades (PBT)

- **PBT-01 — Idempotência:** para qualquer sequência de N requisições com a mesma `Idempotency-Key`, existe exatamente uma ativação e exatamente um débito.
- **PBT-02 — Conservação de saldo:** para qualquer sequência de ativações e extensões aceitas, `saldo_inicial − saldo_final = Σ(minutos_debitados × tarifa)`.
- **PBT-03 — Máquina de estados:** a ativação só transita `Ativa → Expirada` ou `Ativa → Cancelada`; nenhum estado terminal volta a `Ativa`.
- **PBT-04 — Estorno limitado:** para qualquer ativação e instante de cancelamento, `0 ≤ estorno ≤ valor_total_pago` e `valor_debitado_liquido + estorno = valor_total_pago`.
