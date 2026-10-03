# Epic context — aviso-saldo-baixo-push

> Gerado por epic-context agent. Leitura rápida — não substitui os artefatos originais.

## Objetivo

Enviar um push "Saldo baixo" ao passageiro sempre que o saldo do cartão ficar abaixo de um limiar configurável logo após uma validação debitada, reduzindo recusas na catraca por falta de saldo.

## Decisões de design

- Não há `design.md` neste change (scale 1, sem fase de design) — nenhuma decisão de design documentada para embutir nas stories. Cada story deve resolver detalhes de implementação (ex.: onde persistir o horário do último aviso por cartão, forma de checar o opt-out) a partir de `requirements.md` e das convenções já existentes em `src/notificacoes/`, sem tratar isto como decisão fechada.

## Contratos externos

- `src/notificacoes/templates/saldo-baixo.json` — template de payload do push "Saldo baixo" enviado ao passageiro (produzido pela TASK-03).

## ADRs

- Nenhum ADR está listado no `spec-manifest.yaml` nem referenciado em `design.md` (inexistente) para este change. Se alguma story precisar decidir como o push é efetivamente entregue, isso deve ser levantado como dúvida de design, não assumido a partir de contexto externo ao change.

## Rules

- Nenhuma rule de `.forge/rules/` é mencionada nos artefatos do change.

## Invariantes críticas

- No máximo um aviso de saldo baixo por cartão a cada 24 horas corridas (REQ-02).
- Passageiro que desativou notificações de saldo no app não recebe o aviso, mesmo que o saldo caia abaixo do limiar (REQ-03).
- O texto do push nunca exibe o número completo do cartão — apenas os 4 últimos dígitos (REQ-04).
- O limiar de saldo baixo é configurável por passageiro entre R$ 5,00 e R$ 50,00, com padrão de R$ 10,00 (REQ-01).
