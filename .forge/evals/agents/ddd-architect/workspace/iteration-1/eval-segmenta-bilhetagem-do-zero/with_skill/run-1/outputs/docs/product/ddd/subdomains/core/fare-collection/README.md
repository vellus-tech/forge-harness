# Fare Collection

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Decide e registra o ato de embarque do passageiro — a checagem de blocklist e saldo, o débito da tarifa vigente da linha, a aplicação da integração tarifária temporal e a sincronização em lote quando o validador opera offline.

## 3. Justificativa da Classificação
É o ponto de contato central da experiência do produto (OBJ-01: embarque em menos de 2 segundos) e concentra a regra de negócio mais crítica e específica da Tarifa Viva — decisão local, offline-first, em até 300ms, com integração tarifária temporal e isolamento do protocolo proprietário do firmware ValidaBus. Não existe solução de prateleira para este problema; falha aqui compromete a operação de toda a frota.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-01 | Fare Collection | Decidir e registrar embarques, inclusive offline |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| FareCharged | Embarque aprovado, tarifa debitada (integral ou com desconto de integração) |
| BoardingRejected | Embarque negado por bloqueio de cartão ou saldo insuficiente |
| BoardingBatchSynced | Lote de embarques offline sincronizado com o backend |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-01 | Embarque só é aprovado se o cartão não estiver bloqueado e houver saldo suficiente |
| RULE-02 | Decisão em até 300ms, inclusive offline |
| RULE-03 | Segunda viagem em linha diferente dentro de 60 minutos custa 50% da tarifa |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Fare Collection | Contexto 1:1 com o subdomínio |

## 8. Pontos a Validar
- VAL-01 — fonte autoritativa do saldo durante a decisão offline (ver `docs/product/ddd/ddd-segmentation.md §5`)
- VAL-05 — termo "validação" ambíguo com Recharge (ver glossário)
