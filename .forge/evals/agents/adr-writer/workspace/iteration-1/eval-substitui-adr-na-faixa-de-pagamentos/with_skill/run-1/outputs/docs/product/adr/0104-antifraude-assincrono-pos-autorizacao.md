# ADR-0104: Antifraude assíncrono pós-autorização com anulação antes da captura

- **Status:** Aceito
- **Data:** 2026-09-24
- **Autores:** @rafael-costa

## Contexto e Problema

O ADR-0102 estabeleceu a chamada síncrona ao provedor de antifraude, com timeout de 800 ms, antes de enviar a autorização ao adquirente. Em agosto, o p99 de autorização chegou a 1,9 s nos picos de tráfego, rompendo três vezes o SLO de 1,2 s definido na seção de Conformidade daquele ADR. A causa é estrutural: a pontuação de risco soma latência ao caminho crítico de autorização, e o timeout de 800 ms não é suficiente para absorver a variação do provedor sob carga. Este ADR substitui o ADR-0102 e registra a decisão de tirar a pontuação de fraude do caminho de autorização.

## Opções Consideradas

1. Manter a chamada síncrona com timeout de 800 ms (status quo do ADR-0102). Contra: mesmo com o timeout, o p99 de autorização ficou em 1,9 s nos picos de agosto, rompendo o SLO de 1,2 s três vezes no mês.
2. Pontuação assíncrona após a autorização, com anulação (void) da autorização antes da captura quando o score superar 0,85. Contra: uma autorização fraudulenta pode chegar a tocar o emissor antes da anulação, e a taxa de autorização já paga é perdida mesmo quando a anulação ocorre a tempo.
3. Engine de regras locais, sem chamada a provedor externo. Contra: precisão insuficiente — 38% de falsos positivos no piloto, inviabilizando o uso isolado.

## Decisão

Opção 2 — pontuação de fraude assíncrona logo após a autorização, com anulação da autorização antes da captura quando o score superar 0,85. A captura só ocorre em D+0 às 23:00, o que garante uma janela de horas entre autorização e captura para a pontuação assíncrona concluir e, se necessário, anular a transação a tempo. Isso resolve o rompimento de SLO da opção 1 sem herdar a baixa precisão da opção 3.

## Consequências

- Positivas: remove a pontuação de fraude do caminho crítico de autorização, eliminando a causa estrutural do rompimento de SLO observado em agosto; preserva a precisão do provedor de antifraude (rejeitada a alternativa de regras locais, com 38% de falsos positivos).
- Negativas/débitos: parte das autorizações fraudulentas chega a tocar o emissor antes da anulação — a Vellus/Axis paga a taxa de autorização ao adquirente mesmo quando a anulação ocorre a tempo de evitar a captura; mitigação: a janela entre autorização e captura (D+0 23:00) é suficiente para anular a grande maioria dos casos antes da captura, mas a taxa de autorização em si não é recuperável e deve ser tratada como custo operacional aceito por esta decisão.

## Conformidade

p99 de autorização abaixo de 1,2 s no dashboard de SLO (mesmo critério do ADR-0102, agora sem a chamada síncrona de antifraude no caminho); anulação registrada e auditável para todo score acima de 0,85 antes do horário de corte de captura (D+0 23:00).

## Links

- Supera: [ADR-0102](./0102-antifraude-sincrono-na-autorizacao.md) (Antifraude síncrono no caminho de autorização)
- Aprovado em revisão de arquitetura de 2026-09-24
